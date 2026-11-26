import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

void main() {
  late LifeosDatabase dbA;
  late LifeosDatabase dbB;
  late TagRepository tagsA;
  late TagRepository tagsB;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUp(() async {
    dbA = LifeosDatabase(NativeDatabase.memory());
    dbB = LifeosDatabase(NativeDatabase.memory());
    final recorderA = await ChangeRecorder.open(dbA);
    final recorderB = await ChangeRecorder.open(dbB);
    tagsA = TagRepository(dbA, recorderA);
    tagsB = TagRepository(dbB, recorderB);
    engineA = SyncEngine(dbA, recorderA);
    engineB = SyncEngine(dbB, recorderB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  Future<void> exchange() async {
    await engineB.applyEntries(await engineA.entriesMissingFrom(await engineB.versionVector()));
    await engineA.applyEntries(await engineB.entriesMissingFrom(await engineA.versionVector()));
  }

  test('gleicher Name ergibt dieselbe ID, unabhängig von Schreibweise', () async {
    final first = await tagsA.create(TagScope.finance, 'Essen');
    final again = await tagsA.create(TagScope.finance, '  essen ');
    expect(again, first);
    expect(await tagsA.watch(TagScope.finance).first, hasLength(1));
    expect(await tagsA.create(TagScope.calendar, 'Essen'), isNot(first));
  });

  test('zwei Geräte legen offline denselben Tag an und haben danach einen', () async {
    await tagsA.create(TagScope.calendar, 'Sport');
    await tagsB.create(TagScope.calendar, 'sport');
    await exchange();
    expect(await tagsA.watch(TagScope.calendar).first, hasLength(1));
    expect(await tagsB.watch(TagScope.calendar).first, hasLength(1));
  });

  test('gelöschter Tag wird wiederbelebt, auch auf dem anderen Gerät', () async {
    final id = await tagsA.create(TagScope.finance, 'Kino', monthlyLimitCents: 2000);
    await exchange();
    await tagsA.delete(id);
    await exchange();
    expect(await tagsB.watch(TagScope.finance).first, isEmpty);

    expect(await tagsA.create(TagScope.finance, 'Kino'), id);
    await exchange();
    final onB = await tagsB.watch(TagScope.finance).first;
    expect(onB.single.name, 'Kino');
    expect(onB.single.monthlyLimitCents, isNull);
  });

  test('Budget setzen und entfernen', () async {
    final id = await tagsA.create(TagScope.finance, 'Essen');
    await tagsA.update(id, monthlyLimitCents: 30000);
    expect((await tagsA.watch(TagScope.finance).first).single.monthlyLimitCents, 30000);
    await tagsA.update(id, clearLimit: true);
    expect((await tagsA.watch(TagScope.finance).first).single.hasBudget, isFalse);
  });

  test('leerer Name wird abgelehnt', () {
    expect(() => tagsA.create(TagScope.finance, '  '), throwsArgumentError);
  });
}
