import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  test('newId liefert zeitlich sortierbare UUIDv7', () async {
    final first = Ids.newId();
    await Future<void>.delayed(const Duration(milliseconds: 3));
    final second = Ids.newId();
    expect(first[14], '7');
    expect(first.compareTo(second) < 0, isTrue);
  });

  test('deterministic ist auf jedem Aufruf gleich und trennt Eingaben', () {
    final essen = Ids.deterministic('tag:finance', 'essen');
    expect(Ids.deterministic('tag:finance', 'essen'), essen);
    expect(Ids.deterministic('tag:finance', 'sport'), isNot(essen));
    expect(Ids.deterministic('tag:calendar', 'essen'), isNot(essen));
    expect(essen[14], '5');
  });

  test('normalizeName vereinheitlicht Groß- und Leerschreibung', () {
    expect(Ids.normalizeName('  Voll   Milch '), 'voll milch');
  });
}
