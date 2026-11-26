import 'package:lifeos_sync/lifeos_sync.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late TestDevice pc;
  late TestDevice phone;
  var pcClock = 1000;
  var phoneClock = 1000;

  setUp(() async {
    pcClock = 1000;
    phoneClock = 1000;
    pc = await TestDevice.create(wallClock: () => pcClock);
    phone = await TestDevice.create(wallClock: () => phoneClock);
  });

  tearDown(() async {
    await pc.close();
    await phone.close();
  });

  test('neue Aufgabe kommt auf dem anderen Gerät an', () async {
    final id = await pc.createTask('Steuererklärung');
    expect(await phone.pullFrom(pc), 1);
    final copy = await phone.task(id);
    expect(copy, isNotNull);
    expect(copy!.title, 'Steuererklärung');
    expect(copy.done, isFalse);
  });

  test('erneutes Einspielen ändert nichts (idempotent)', () async {
    await pc.createTask('A');
    await phone.pullFrom(pc);
    expect(await phone.pullFrom(pc), 0);
    final entries = await pc.engine.entriesMissingFrom({});
    expect(await phone.engine.applyEntries(entries), 0);
  });

  test('nacheinander geänderte Felder ergeben keinen Konflikt', () async {
    final id = await pc.createTask('Alt');
    await phone.pullFrom(pc);
    phoneClock = 2000;
    await phone.renameTask(id, 'Neu');
    await pc.pullFrom(phone);
    expect((await pc.task(id))!.title, 'Neu');
    expect(await pc.engine.openConflictCount(), 0);
  });

  test('verschiedene Feldgruppen werden zusammengeführt', () async {
    final id = await pc.createTask('Sport');
    await phone.pullFrom(pc);
    pcClock = 2000;
    await pc.renameTask(id, 'Laufen');
    phoneClock = 2100;
    await phone.setDone(id, true);

    await pc.pullFrom(phone);
    await phone.pullFrom(pc);

    for (final device in [pc, phone]) {
      final task = (await device.task(id))!;
      expect(task.title, 'Laufen');
      expect(task.done, isTrue);
      expect(await device.engine.openConflictCount(), 0);
    }
  });

  test('gleichzeitige Änderung: spätere gewinnt, andere wird als Konflikt gemerkt', () async {
    final id = await pc.createTask('Termin');
    await phone.pullFrom(pc);
    pcClock = 2000;
    await pc.renameTask(id, 'Termin 14 Uhr');
    phoneClock = 3000;
    await phone.renameTask(id, 'Termin 15 Uhr');

    await pc.pullFrom(phone);
    await phone.pullFrom(pc);

    expect((await pc.task(id))!.title, 'Termin 15 Uhr');
    expect((await phone.task(id))!.title, 'Termin 15 Uhr');
    expect(await pc.engine.openConflictCount(), 1);
    expect(await phone.engine.openConflictCount(), 1);
  });

  test('Löschen gewinnt gegen gleichzeitige Bearbeitung', () async {
    final id = await pc.createTask('Weg');
    await phone.pullFrom(pc);
    pcClock = 2000;
    await pc.deleteTask(id);
    phoneClock = 3000;
    await phone.renameTask(id, 'Doch behalten');

    await pc.pullFrom(phone);
    await phone.pullFrom(pc);

    expect((await pc.task(id))!.deletedHlc, isNotNull);
    expect((await phone.task(id))!.deletedHlc, isNotNull);
  });

  test('Änderungen eines dritten Geräts werden weitergereicht', () async {
    final tablet = await TestDevice.create();
    addTearDown(tablet.close);
    final id = await phone.createTask('Vom Handy');
    await pc.pullFrom(phone);
    await tablet.pullFrom(pc);
    expect((await tablet.task(id))!.title, 'Vom Handy');
    expect(await tablet.pullFrom(phone), 0);
  });

  test('Lücken im Protokoll werden abgelehnt', () async {
    await pc.createTask('Eins');
    await pc.createTask('Zwei');
    final entries = await pc.engine.entriesMissingFrom({});
    expect(
      () => phone.engine.applyEntries([entries.last]),
      throwsA(isA<SyncGapException>()),
    );
  });

  test('lokale Uhr läuft nach Empfang hinter fremden Zeitstempeln her', () async {
    pcClock = 50000;
    final id = await pc.createTask('Zukunft');
    await phone.pullFrom(pc);
    phoneClock = 1000;
    await phone.renameTask(id, 'Später geändert');
    await pc.pullFrom(phone);
    expect((await pc.task(id))!.title, 'Später geändert');
  });
}
