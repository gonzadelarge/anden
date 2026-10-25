import 'clock.dart';

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String two(int n) => n.toString().padLeft(2, '0');

/// "08:05"
String formatTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// "domingo, 25 oct"
String formatDayLong(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "27/10/2026", the format the FGV API expects.
String formatApiDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// "20261027", used in cache keys.
String formatDateKey(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';

DateTime parseDateKey(String key) =>
    DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(4, 6)), int.parse(key.substring(6, 8)));

/// "ahora", "en 4 min", "en 1 h 5 min"
String formatUntil(DateTime departure, DateTime now) {
  final seconds = departure.difference(now).inSeconds;
  if (seconds < 60) return 'ahora';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return 'en $minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? 'en $hours h' : 'en $hours h $rest min';
}

/// True when [t] falls on a later calendar day than [now].
bool isAfterToday(DateTime t, DateTime now) => dateOnly(t).isAfter(dateOnly(now));

const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// "sáb"
String formatWeekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];
