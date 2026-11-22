import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time_format.dart';
import '../models/day_timetable.dart';

class AndenServerException implements Exception {
  AndenServerException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// The server's `error` field, for example `no_route` or `date_not_covered`.
  final String? code;

  @override
  String toString() => 'AndenServerException($statusCode, $code): $message';
}

/// Client for the own timetable server on the VPS (repo anden_server, docs/plan.md section 6).
///
/// Base URL and token come in at build time:
/// `--dart-define=ANDEN_URL=https://anden.gonzadelarge.com --dart-define=ANDEN_TOKEN=...`.
/// Without them [enabled] is false and the app asks FGV only, as before.
class AndenServerApi {
  AndenServerApi(this._client, {String? baseUrl, String? token, DateTime Function()? now})
      : _base = baseUrl ?? const String.fromEnvironment('ANDEN_URL'),
        _token = token ?? const String.fromEnvironment('ANDEN_TOKEN'),
        _now = now ?? DateTime.now;

  /// Short on purpose: FGV (25 s) and the cache come after the server.
  static const timeout = Duration(seconds: 5);

  final http.Client _client;
  final String _base;
  final String _token;
  final DateTime Function() _now;

  static String _isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  bool get enabled => _base.isNotEmpty && _token.isNotEmpty;

  /// [originId] and [destinationId] are [Station.id], like for FGV.
  Future<DayTimetable> fetchTimetable(int originId, int destinationId, DateTime date) async {
    if (!enabled) throw AndenServerException('Server not configured');
    final url = Uri.parse(_base).resolve('/v1/timetable').replace(queryParameters: {
      'from': '$originId',
      'to': '$destinationId',
      'date': _isoDate(date),
    });
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
      throw AndenServerException('Unexpected timetable body', statusCode: response.statusCode);
    }
  }
}
