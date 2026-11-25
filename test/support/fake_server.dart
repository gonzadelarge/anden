import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// A fake own server that answers `/v2/` from the fixtures in test/fixtures/
/// (real answers of 2026-11-25). Timetables are sent for whatever pair and date are asked.
class FakeServer {
  FakeServer({this.timetableFile = 'timetable_amistat_colon.json'});

  static const url = 'https://anden.example.com';
  static const token = 'secret';

  String timetableFile;

  /// When set, `/v2/timetable` answers 404 with this `error` code.
  String? timetableError;

  /// Any request fails as if offline.
  bool down = false;

  final requests = <http.Request>[];

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    if (down) throw const SocketException('offline');
    final path = request.url.path;
    if (path == '/v2/stations') return _json(fixture('stations.json'));
    if (path == '/v2/incidents') return _json(fixture('incidents.json'));
    if (path == '/v2/timetable') {
      final error = timetableError;
      if (error != null) return http.Response('{"error":"$error","message":"x"}', 404);
      final q = request.url.queryParameters;
      final body = jsonDecode(fixture(timetableFile)) as Map<String, dynamic>
        ..['originId'] = int.parse(q['from']!)
        ..['destinationId'] = int.parse(q['to']!)
        ..['date'] = q['date'];
      return _json(jsonEncode(body));
    }
    return http.Response('{"error":"not_found"}', 404);
  });

  static http.Response _json(String body) => http.Response.bytes(utf8.encode(body), 200);
}
