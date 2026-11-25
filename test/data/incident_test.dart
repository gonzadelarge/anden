import 'dart:convert';

import 'package:anden/data/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  // Real answer of /v2/incidents, 2026-11-25.
  List<Incident> parse() => ((jsonDecode(fixture('incidents.json')) as Map<String, dynamic>)['incidents'] as List)
      .map((i) => Incident.fromJson(i as Map<String, dynamic>))
      .toList();

  test('reads the real server answer', () {
    final list = parse();

    expect(list, hasLength(3));
    expect(list.first.priority, isTrue);
    expect(list.first.categoryLabel, 'Incidencia');
    expect(list.first.lines, [4]);
    expect(list.first.title, startsWith('Por reorganización del servicio'));
    expect(list.first.url, isEmpty);
    expect(list[1].categoryLabel, 'Servicio especial');
    expect(list[1].lines, [1, 2, 3, 6, 7, 9, 10]);
    expect(list[1].url, startsWith('https://www.metrovalencia.es/'));
  });

  test('survives a cache round trip', () {
    final original = parse()[1];
    final copy = Incident.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

    expect(copy.category, original.category);
    expect(copy.priority, original.priority);
    expect(copy.title, original.title);
    expect(copy.lines, original.lines);
    expect(copy.url, original.url);
  });

  test('an unknown category is written out', () {
    expect(
      const Incident(category: 'obras_en_via', priority: false, title: 'x', lines: []).categoryLabel,
      'Obras en via',
    );
    expect(const Incident(category: '', priority: false, title: 'x', lines: []).categoryLabel, 'Aviso');
  });
}
