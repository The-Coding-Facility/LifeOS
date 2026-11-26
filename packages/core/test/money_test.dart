import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  group('formatCents', () {
    test('mit Tausenderpunkt und Komma', () {
      expect(formatCents(123456), '1.234,56 €');
      expect(formatCents(100000000), '1.000.000,00 €');
      expect(formatCents(0), '0,00 €');
    });

    test('negativ und mit Vorzeichen', () {
      expect(formatCents(-5), '-0,05 €');
      expect(formatCents(-123456), '-1.234,56 €');
      expect(formatCents(500, withSign: true), '+5,00 €');
      expect(formatCents(-500, withSign: true), '-5,00 €');
      expect(formatCents(0, withSign: true), '0,00 €');
    });
  });

  group('parseCents', () {
    test('übliche Schreibweisen', () {
      expect(parseCents('12,5'), 1250);
      expect(parseCents('12.50'), 1250);
      expect(parseCents('1.234,56'), 123456);
      expect(parseCents('1,234.56'), 123456);
      expect(parseCents('1.234'), 123400);
      expect(parseCents('-3'), -300);
      expect(parseCents(' 7 € '), 700);
      expect(parseCents('0,05'), 5);
    });

    test('ungültige Eingaben', () {
      expect(parseCents(''), isNull);
      expect(parseCents('abc'), isNull);
      expect(parseCents('1,234'), isNull);
      expect(parseCents('1..2'), isNull);
      expect(parseCents('-'), isNull);
    });
  });
}
