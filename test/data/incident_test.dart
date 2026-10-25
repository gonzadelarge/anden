import 'dart:convert';
import 'dart:io';

import 'package:anden/data/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Real response of GET incidencias, 25/10/2026.
  Map<String, dynamic> fixture() =>
      jsonDecode(File('test/fixtures/incidencias.json').readAsStringSync()) as Map<String, dynamic>;

  test('joins incidents with their Spanish text', () {
    final list = Incident.listFromApi(fixture());

    expect(list.map((i) => i.lineId), [45, 47, 45]);
    expect(list.first.text, 'Por descarrilo, circulación interrumpida entre Empalme y Dr. Lluch');
    expect(list.first.title, isEmpty);
  });

  test('picks another language when asked', () {
    final list = Incident.listFromApi(fixture(), locale: 'CA');
    expect(list.first.text, startsWith('Per descarrilament'));
  });

  test('skips deleted incidents and incidents without text', () {
    final json = fixture();
    (json['incidencias'] as List).first['deleted_at'] = '2026-10-25T10:00:00.000000Z';
    json['incidencias_translations'] =
        (json['incidencias_translations'] as List).where((t) => t['incidencia_id'] != 11674856).toList();

    expect(Incident.listFromApi(json).map((i) => i.id), [11674857]);
  });

  test('an empty body gives no incidents', () {
    expect(Incident.listFromApi({'incidencias': [], 'incidencias_translations': []}), isEmpty);
  });
}
