import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_security/lifeos_security.dart';

void main() {
  late LifeosDatabase db;
  late AppLockController lock;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 11, 26, 8);
    db = LifeosDatabase(NativeDatabase.memory());
    lock = AppLockController(
      store: SecurityStore(LocalMetaStore(db)),
      // Schnelle Parameter nur für Tests.
      hasher: const PinHasher(memoryKb: 64, iterations: 1),
      now: () => now,
    );
    await lock.init();
  });

  tearDown(() async {
    lock.dispose();
    await db.close();
  });

  Future<void> setUpUnlocked(String pin) async {
    await lock.setupPin(pin);
    lock.confirmRecoveryCodeSaved();
  }

  test('Ersteinrichtung: erst nach bestätigtem Code entsperrt', () async {
    expect(lock.state, AppLockState.needsSetup);
    final code = await lock.setupPin('123456');
    expect(lock.pendingRecoveryCode, code);
    expect(lock.state, AppLockState.needsSetup);
    lock.confirmRecoveryCodeSaved();
    expect(lock.state, AppLockState.unlocked);
    expect(lock.pendingRecoveryCode, isNull);
  });

  test('ungültige PIN wird abgelehnt', () {
    expect(() => lock.setupPin('12345'), throwsArgumentError);
    expect(() => lock.setupPin('12345a'), throwsArgumentError);
  });

  test('sperrt nach 10 Minuten ohne Eingabe', () async {
    await setUpUnlocked('123456');
    now = now.add(const Duration(minutes: 9));
    lock.checkInactivity();
    expect(lock.state, AppLockState.unlocked);

    lock.registerActivity();
    now = now.add(const Duration(minutes: 9));
    lock.checkInactivity();
    expect(lock.state, AppLockState.unlocked);

    now = now.add(const Duration(minutes: 1));
    lock.onForeground();
    expect(lock.state, AppLockState.locked);
  });

  test('richtige PIN entsperrt, falsche nicht', () async {
    await setUpUnlocked('123456');
    lock.lockNow();
    expect(await lock.unlock('654321'), isA<UnlockWrongPin>());
    expect(lock.state, AppLockState.locked);
    expect(await lock.unlock('123456'), isA<UnlockSuccess>());
    expect(lock.state, AppLockState.unlocked);
  });

  test('ab dem 5. Fehlversuch gibt es eine Wartezeit', () async {
    await setUpUnlocked('123456');
    lock.lockNow();
    for (var attempt = 1; attempt <= 4; attempt++) {
      final result = await lock.unlock('000000') as UnlockWrongPin;
      expect(result.retryAfter, isNull);
    }
    final fifth = await lock.unlock('000000') as UnlockWrongPin;
    expect(fifth.retryAfter, now.add(const Duration(seconds: 30)));

    expect(await lock.unlock('123456'), isA<UnlockBlocked>());

    now = now.add(const Duration(seconds: 31));
    expect(await lock.unlock('123456'), isA<UnlockSuccess>());
  });

  test('Wartezeit verdoppelt sich bis höchstens 1 Stunde', () {
    expect(AppLockController.lockoutFor(4), Duration.zero);
    expect(AppLockController.lockoutFor(5), const Duration(seconds: 30));
    expect(AppLockController.lockoutFor(6), const Duration(seconds: 60));
    expect(AppLockController.lockoutFor(40), const Duration(hours: 1));
  });

  test('Reset mit Wiederherstellungscode setzt neue PIN und neuen Code', () async {
    final firstCode = await lock.setupPin('123456');
    lock.confirmRecoveryCodeSaved();
    lock.lockNow();

    expect(await lock.resetWithRecoveryCode('AAAA-AAAA-AAAA-AAAA-AAAA-AAAA', '777777'), isNull);

    final sloppyInput = '  ${firstCode.toLowerCase().replaceAll('-', ' ')} ';
    final secondCode = await lock.resetWithRecoveryCode(sloppyInput, '777777');
    expect(secondCode, isNotNull);
    expect(secondCode, isNot(firstCode));
    expect(lock.state, AppLockState.locked);

    lock.confirmRecoveryCodeSaved();
    expect(lock.state, AppLockState.unlocked);

    lock.lockNow();
    expect(await lock.unlock('123456'), isA<UnlockWrongPin>());
    expect(await lock.unlock('777777'), isA<UnlockSuccess>());
    expect(await lock.resetWithRecoveryCode(firstCode, '888888'), isNull);
  });

  test('nach Neustart ist die App gesperrt', () async {
    await setUpUnlocked('123456');
    final restarted = AppLockController(
      store: SecurityStore(LocalMetaStore(db)),
      hasher: const PinHasher(memoryKb: 64, iterations: 1),
      now: () => now,
    );
    await restarted.init();
    expect(restarted.state, AppLockState.locked);
    restarted.dispose();
  });
}
