/// Source of the current time. Tests replace it with a fixed clock.
class Clock {
  const Clock();

  DateTime now() => DateTime.now();

  DateTime today() => dateOnly(now());
}

class FixedClock extends Clock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
