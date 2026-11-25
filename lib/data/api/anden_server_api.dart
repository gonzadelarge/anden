import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time_format.dart';
import '../models/day_timetable.dart';
import '../models/incident.dart';
import '../models/station.dart';

class AndenServerException implements Exception {
  AndenServerException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// The server's `error` field, for example `no_route` or `date_not_covered`.
  final String? code;

  /// The server has no timetable for this pair or date. Asking again does not help.
  bool get isNoTimetable => code == noRoute || code == dateNotCovered;

  static const noRoute = 'no_route';
  static const dateNotCovered = 'date_not_covered';

  @override
  String toString() => 'AndenServerException($statusCode, $code): $message';
}

/// Answer of `/v2/incidents`.
class IncidentsAnswer {
  const IncidentsAnswer({required this.ok, required this.items, this.readAt});

  /// False when the server's last read of metrovalencia.es failed.
  final bool ok;
  final List<Incident> items;

  /// Time of the server's last good read. Null before the first one.
  final DateTime? readAt;
}

/// Client for the own server on the VPS (repo anden_server, docs/plan-v2.md section 4).
/// It is the app's only data source.
///
/// Base URL and token come in at build time:
/// `--dart-define-from-file=config/anden_server.json` (`ANDEN_URL`, `ANDEN_TOKEN`).
/// Without them every call throws and the app has no data.
class AndenServerApi {
  AndenServerApi(this._client, {String? baseUrl, String? token, DateTime Function()? now})
      : _base = baseUrl ?? const String.fromEnvironment('ANDEN_URL'),
        _token = token ?? const String.fromEnvironment('ANDEN_TOKEN'),
        _now = now ?? DateTime.now;

  static const timeout = Duration(seconds: 10);

  final http.Client _client;
  final String _base;
  final String _token;
  final DateTime Function() _now;

  static String _isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  bool get enabled => _base.isNotEmpty && _token.isNotEmpty;

  /// All stations and the GTFS feed date they come from.
  Future<({List<Station> stations, String? feedDate})> fetchStations() async {
    final body = await _get('/v2/stations');
    try {
      final json = body as Map<String, dynamic>;
      return (
        stations: (json['stations'] as List).map((s) => Station.fromJson(s as Map<String, dynamic>)).toList(),
        feedDate: json['feedDate'] as String?,
      );
    } on TypeError {
      throw AndenServerException('Unexpected stations body');
    }
  }

  /// [originId] and [destinationId] are [Station.id] (GTFS ids).
  Future<DayTimetable> fetchTimetable(int originId, int destinationId, DateTime date) async {
    final body = await _get('/v2/timetable', {
      'from': '$originId',
      'to': '$destinationId',
      'date': _isoDate(date),
    });
    try {
      final json = body as Map<String, dynamic>;
      if (json['originId'] != originId || json['destinationId'] != destinationId || json['date'] != _isoDate(date)) {
        throw AndenServerException('Answer for another pair or date');
      }
      // Same fields as the cache entry, but the date is ISO and fetchedAt is missing.
      return DayTimetable.fromJson({
        ...json,
        'date': formatDateKey(date),
        'fetchedAt': _now().toIso8601String(),
      });
    } on TypeError {
      throw AndenServerException('Unexpected timetable body');
    } on FormatException {
      throw AndenServerException('Unexpected timetable body');
    }
  }

  Future<IncidentsAnswer> fetchIncidents() async {
    final body = await _get('/v2/incidents');
    try {
      final json = body as Map<String, dynamic>;
      final readAt = (json['fetchedAt'] as String?) ?? '';
      return IncidentsAnswer(
        ok: json['ok'] == true,
        items: ((json['incidents'] as List?) ?? const [])
            .map((i) => Incident.fromJson(i as Map<String, dynamic>))
            .toList(),
        readAt: readAt.isEmpty ? null : DateTime.tryParse(readAt)?.toLocal(),
      );
    } on TypeError {
      throw AndenServerException('Unexpected incidents body');
    }
  }

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    if (!enabled) throw AndenServerException('Server not configured');
    final url = Uri.parse(_base).resolve(path).replace(queryParameters: query);
    final http.Response response;
    try {
      response = await _client.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(timeout);
    } catch (e) {
      throw AndenServerException('Network error: $e');
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw AndenServerException('Invalid JSON', statusCode: response.statusCode);
    }
    if (response.statusCode != 200) {
      final code = body is Map<String, dynamic> ? body['error'] as String? : null;
      throw AndenServerException('HTTP ${response.statusCode}', statusCode: response.statusCode, code: code);
    }
    return body;
  }
}
