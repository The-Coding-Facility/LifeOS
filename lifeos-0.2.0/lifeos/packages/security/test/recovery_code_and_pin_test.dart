import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_security/lifeos_security.dart';

void main() {
  group('RecoveryCode', () {
    test('erzeugt 6 Gruppen zu je 4 Zeichen ohne I, L, O, U', () {
      for (var i = 0; i < 50; i++) {
        final code = RecoveryCode.generate();
        expect(code, matches(RegExp(r'^([0-9A-HJKMNP-TV-Z]{4}-){5}[0-9A-HJKMNP-TV-Z]{4}$')));
      }
    });

    test('normalize verzeiht Schreibweise und Verwechslungen', () {
      expect(RecoveryCode.normalize('abcd efgh-jkmn pqrs tvwx yz01'), 'ABCDEFGHJKMNPQRSTVWXYZ01');
      expect(RecoveryCode.normalize('OOOO-IIII-LLLL-0000-1111-2222'), '000011111111000011112222');
      expect(RecoveryCode.normalize('zu kurz'), isNull);
      expect(RecoveryCode.normalize('UUUU-UUUU-UUUU-UUUU-UUUU-UUUU'), isNull);
    });
  });

  group('PinHasher', () {
    const hasher = PinHasher(memoryKb: 64, iterations: 1);

    test('prüft die richtige PIN, lehnt falsche ab', () async {
      final stored = await hasher.hash('246810');
      expect(await hasher.verify('246810', stored), isTrue);
      expect(await hasher.verify('246811', stored), isFalse);
    });

    test('gleiche PIN ergibt durch Salt verschiedene Hashes', () async {
      final a = await hasher.hash('246810');
      final b = await hasher.hash('246810');
      expect(a.hash, isNot(b.hash));
    });

    test('nur 6 bis 12 Ziffern sind gültig', () {
      expect(PinHasher.isValidPin('123456'), isTrue);
      expect(PinHasher.isValidPin('123456789012'), isTrue);
      expect(PinHasher.isValidPin('12345'), isFalse);
      expect(PinHasher.isValidPin('1234567890123'), isFalse);
      expect(PinHasher.isValidPin('12a456'), isFalse);
    });
  });
}
