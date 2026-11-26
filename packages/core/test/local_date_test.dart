import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  test('isoDate schreibt nur das Datum', () {
    expect(isoDate(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    expect(isoDate(DateTime(987, 12, 31)), '0987-12-31');
  });

  test('parseIsoDate liefert lokale Mitternacht', () {
    expect(parseIsoDate('2026-03-05'), DateTime(2026, 3, 5));
    expect(() => parseIsoDate('05.03.2026'), throwsFormatException);
  });

  test('dateOnly schneidet die Uhrzeit ab', () {
    expect(dateOnly(DateTime(2026, 11, 26, 22, 40)), DateTime(2026, 11, 26));
  });
}
