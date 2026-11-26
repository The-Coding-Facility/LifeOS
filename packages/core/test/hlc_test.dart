import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  group('Hlc', () {
    test('pack und parse ergeben denselben Wert', () {
      const hlc = Hlc(1764160000000, 42, '0193f0a2-7c4e-7a10-8000-000000000001');
      expect(Hlc.parse(hlc.pack()), hlc);
    });

    test('Textform sortiert wie compareTo', () {
      final values = [
        const Hlc(5, 0, 'b'),
        const Hlc(5, 0, 'a'),
        const Hlc(4, Hlc.maxCounter, 'z'),
        const Hlc(5, 10, 'a'),
        const Hlc(1000, 0, 'a'),
      ];
      final byCompare = [...values]..sort();
      final byText = [...values]..sort((x, y) => x.pack().compareTo(y.pack()));
      expect(byText, byCompare);
    });

    test('parse lehnt kaputte Werte ab', () {
      expect(() => Hlc.parse('kaputt'), throwsFormatException);
      expect(() => Hlc.parse('000000000000005-0000-'), throwsFormatException);
    });
  });

  group('HlcClock', () {
    test('now() steigt streng, auch wenn die Uhr steht oder zurückspringt', () {
      var wall = 1000;
      final clock = HlcClock(nodeId: 'a', wallClock: () => wall);
      final first = clock.now();
      final second = clock.now();
      wall = 900;
      final third = clock.now();
      expect(first < second, isTrue);
      expect(second < third, isTrue);
    });

    test('receive() liegt nach lokalem und entferntem Zeitstempel', () {
      final clock = HlcClock(nodeId: 'a', wallClock: () => 1000);
      const remote = Hlc(5000, 3, 'b');
      final result = clock.receive(remote);
      expect(result > remote, isTrue);
      expect(clock.now() > result, isTrue);
    });

    test('receive() wirft bei mehr als 24 h Vorsprung', () {
      final clock = HlcClock(nodeId: 'a', wallClock: () => 0);
      final remote = Hlc(const Duration(hours: 25).inMilliseconds, 0, 'b');
      expect(() => clock.receive(remote), throwsA(isA<ClockDriftException>()));
    });

    test('Zählerüberlauf rückt die Millisekunde vor', () {
      final clock = HlcClock(
        nodeId: 'a',
        wallClock: () => 10,
        last: const Hlc(10, Hlc.maxCounter, 'a'),
      );
      final next = clock.now();
      expect(next.millis, 11);
      expect(next.counter, 0);
    });

    test('übernommener letzter Stand bekommt die eigene Geräte-ID', () {
      final clock = HlcClock(nodeId: 'neu', last: const Hlc(50, 1, 'alt'));
      expect(clock.last.nodeId, 'neu');
    });
  });
}
