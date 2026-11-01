import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time_format.dart';
import '../models/day_timetable.dart';
import '../models/incident.dart';
import '../models/line.dart';
import '../models/live_train.dart';
import '../models/station.dart';

class FgvApiException implements Exception {
  FgvApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'FgvApiException($statusCode): $message';
}

/// Client for the undocumented API behind the official app.
/// See docs/fgv-api.md.
class FgvApi {
  FgvApi(this._client, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final Uri baseUrl = Uri.parse('https://www.fgv.es/fgv/app/es/api/v1/V/');
  static const timeout = Duration(seconds: 25);
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Anden/0.1 (Android; private use)',
  };

  final http.Client _client;
  final DateTime Function() _now;

  Future<List<Station>> fetchStations() async {
    final body = await _send(() => _client.get(baseUrl.resolve('estaciones'), headers: _headers));
    return (body as List)
        .cast<Map<String, dynamic>>()
        .where((s) => s['sede'] == 'V' && s['deleted_at'] == null)
        .map(Station.fromApi)
        .toList();
  }

  Future<List<Line>> fetchLines() async {
    final body = await _send(() => _client.get(baseUrl.resolve('lineas'), headers: _headers));
    return (body as List)
        .cast<Map<String, dynamic>>()
        .where((l) => l['sede'] == 'V' && l['deleted_at'] == null)
        .map(Line.fromApi)
        .toList();
  }

  Future<List<Incident>> fetchIncidents() async {
    final body = await _send(() => _client.get(baseUrl.resolve('incidencias'), headers: _headers));
    if (body is! Map<String, dynamic>) {
      throw FgvApiException('Unexpected incidents body');
    }
    return Incident.listFromApi(body);
  }

  /// [originId] and [destinationId] are [Station.id], not [Station.fgvId].
  Future<DayTimetable> fetchTimetable(int originId, int destinationId, DateTime date) async {
    final body = await _postTimetable(originId, destinationId, date);
    if (body is! Map<String, dynamic>) {
      throw FgvApiException('Unexpected timetable body');
    }
    final timetable = DayTimetable.fromApi(
      body,
      originId: originId,
      destinationId: destinationId,
      date: date,
      fetchedAt: _now(),
    );
    final connection = timetable.connection;
    if (connection == null) return timetable;
    return timetable.withRideMinutes(await _rideMinutes(originId, connection.stationId, date));
  }

  /// The API gives only the total of a trip with a change, wait included, so
  /// the first leg is asked for as a trip of its own.
  Future<int?> _rideMinutes(int originId, int changeStationId, DateTime date) async {
    try {
      final body = await _postTimetable(originId, changeStationId, date);
      final results = (body as Map<String, dynamic>)['resultado'] as List;
      return ((results.first as Map<String, dynamic>)['duracion_minutos'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _postTimetable(int originId, int destinationId, DateTime date) => _send(() => _client.post(
        baseUrl.resolve('horarios-online2'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'estacion_origen_id': originId,
          'estacion_destino_id': destinationId,
          'fecha': formatApiDate(date),
        }),
      ));

  /// [fgvId] is [Station.fgvId], not [Station.id].
  Future<List<LiveTrain>> fetchLiveTrains(int fgvId) async {
    final body = await _send(() => _client.get(baseUrl.resolve('horarios-prevision-3/$fgvId'), headers: _headers));
    try {
      return LiveTrain.listFromApi(body as Map<String, dynamic>, _now());
    } on TypeError {
      throw FgvApiException('Unexpected real-time body');
    }
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } catch (e) {
      throw FgvApiException('Network error: $e');
    }
    // The server sends no charset, so decode as UTF-8 by hand.
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw FgvApiException(text, statusCode: response.statusCode);
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      throw FgvApiException('Invalid JSON', statusCode: response.statusCode);
    }
  }
}
