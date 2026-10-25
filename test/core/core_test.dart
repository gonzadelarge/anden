import 'package:anden/core/text_normalize.dart';
import 'package:anden/core/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('search', () {
    test('ignores accents and case', () {
      expect(matchesSearch('Colón', 'colon'), isTrue);
      expect(matchesSearch('Àngel Guimerà', 'ANGEL'), isTrue);
      expect(matchesSearch('Col·legi El Vedat', 'collegi'), isTrue);
    });

    test('matches every word in any order', () {
      expect(matchesSearch('Alboraia Peris Aragó', 'arago alb'), isTrue);
      expect(matchesSearch('Alboraia Peris Aragó', 'arago xx'), isFalse);
    });
  });

  group('time format', () {
    final now = DateTime(2026, 10, 27, 8, 0, 30);

    test('until', () {
      expect(formatUntil(DateTime(2026, 10, 27, 8, 1), now), 'ahora');
      expect(formatUntil(DateTime(2026, 10, 27, 8, 5), now), 'en 4 min');
      expect(formatUntil(DateTime(2026, 10, 27, 9, 0, 30), now), 'en 1 h');
      expect(formatUntil(DateTime(2026, 10, 27, 9, 6), now), 'en 1 h 5 min');
    });

    test('API date and cache key', () {
      expect(formatApiDate(DateTime(2026, 3, 7)), '07/03/2026');
      expect(formatDateKey(DateTime(2026, 3, 7)), '20260307');
      expect(parseDateKey('20260307'), DateTime(2026, 3, 7));
    });

    test('long day name', () {
      expect(formatDayLong(DateTime(2026, 10, 25)), 'domingo, 25 oct');
    });
  });
}
