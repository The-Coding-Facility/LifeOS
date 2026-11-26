import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

void main() {
  late LifeosDatabase dbA;
  late LifeosDatabase dbB;
  late FinanceRepository repoA;
  late FinanceRepository repoB;
  late SyncEngine engineA;
  late SyncEngine engineB;
  final today = DateTime(2026, 5, 20);

  setUp(() async {
    dbA = LifeosDatabase(NativeDatabase.memory());
    dbB = LifeosDatabase(NativeDatabase.memory());
    final recorderA = await ChangeRecorder.open(dbA);
    final recorderB = await ChangeRecorder.open(dbB);
    repoA = FinanceRepository(dbA, recorderA, clock: () => today);
    repoB = FinanceRepository(dbB, recorderB, clock: () => today);
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

  final rent = RecurringDraft(
    kind: EntryKind.expense,
    amountCents: 80000,
    title: 'Miete',
    freq: RecurringFreq.monthly,
    startDate: DateTime(2026, 1, 1),
  );

  test('Buchung anlegen, ändern, löschen', () async {
    final id = await repoA.addEntry(
      EntryDraft(kind: EntryKind.expense, amountCents: 500, date: today, title: 'Möhren', tagIds: const ['essen']),
    );
    await repoA.updateEntry(
      id,
      EntryDraft(kind: EntryKind.expense, amountCents: 650, date: today, title: 'Möhren', tagIds: const ['essen']),
    );
    final entries = await repoA.watchEntries().first;
    expect(entries.single.amountCents, 650);
    expect(entries.single.tagIds, ['essen']);
    await repoA.deleteEntry(id);
    expect(await repoA.watchEntries().first, isEmpty);
  });

  test('Betrag 0 wird abgelehnt', () {
    expect(
      () => repoA.addEntry(EntryDraft(kind: EntryKind.expense, amountCents: 0, date: today)),
      throwsArgumentError,
    );
  });

  test('Dauerauftrag bucht Fälliges genau einmal', () async {
    await repoA.addRecurring(rent);
    expect((await repoA.watchEntries().first).length, 5, reason: 'Januar bis Mai');
    expect(await repoA.generateDueRecurring(), 0);
    expect(await repoA.generateDueRecurring(today: DateTime(2026, 6, 1)), 1);
  });

  test('gelöschte erzeugte Buchung kommt nicht zurück', () async {
    await repoA.addRecurring(rent);
    final april = (await repoA.watchEntries().first).firstWhere((e) => e.date == DateTime(2026, 4, 1));
    await repoA.deleteEntry(april.id);
    expect(await repoA.generateDueRecurring(), 0);
    expect((await repoA.watchEntries().first).length, 4);
  });

  test('zwei Geräte erzeugen dieselben Buchungen ohne Doppelte', () async {
    await repoA.addRecurring(rent);
    await exchange();
    expect(await repoB.generateDueRecurring(today: DateTime(2026, 6, 1)), 1);
    expect(await repoA.generateDueRecurring(today: DateTime(2026, 6, 1)), 1);
    await exchange();
    final onA = await repoA.watchEntries().first;
    final onB = await repoB.watchEntries().first;
    expect(onA.length, 6);
    expect(onB.length, 6);
    expect({for (final e in onA) e.id}, {for (final e in onB) e.id});
  });

  test('Sparziel: Einzahlen senkt den Kontostand, Löschen gibt es zurück', () async {
    await repoA.addEntry(EntryDraft(kind: EntryKind.income, amountCents: 100000, date: today, title: 'Startguthaben'));
    final goal = await repoA.addGoal('Urlaub', 150000, targetDate: DateTime(2026, 8, 1));
    await repoA.deposit(goal, 30000, goalName: 'Urlaub');
    var entries = await repoA.watchEntries().first;
    expect(balance(entries), 70000);
    expect(savedFor(goal, entries), 30000);

    await repoA.deleteGoal(goal);
    entries = await repoA.watchEntries().first;
    expect(balance(entries), 100000);
    expect(await repoA.watchGoals().first, isEmpty);
  });
}
