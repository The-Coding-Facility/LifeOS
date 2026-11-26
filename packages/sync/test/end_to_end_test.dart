import 'package:lifeos_sync/lifeos_sync.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Zwei echte Sync-Dienste über HTTP auf diesem Rechner (127.0.0.1).
void main() {
  late TestDevice pcDevice;
  late TestDevice phoneDevice;
  late SyncService pc;
  late SyncService phone;

  setUp(() async {
    pcDevice = await TestDevice.create();
    phoneDevice = await TestDevice.create();
    pc = await SyncService.create(
      db: pcDevice.db,
      recorder: pcDevice.recorder,
      platform: 'windows',
      defaultName: 'PC',
    );
    phone = await SyncService.create(
      db: phoneDevice.db,
      recorder: phoneDevice.recorder,
      platform: 'android',
      defaultName: 'Handy',
    );
    await pc.start(port: 0);
    await phone.start(port: 0);
  });

  tearDown(() async {
    await pc.dispose();
    await phone.dispose();
    await pcDevice.close();
    await phoneDevice.close();
  });

  test('Koppeln mit Code, dann Daten in beide Richtungen', () async {
    final pcTask = await pcDevice.createTask('Vom PC');

    final offer = await pc.startPairing();
    final paired = await phone.joinWith(address: '127.0.0.1:${pc.port}', code: offer.code);
    expect(paired.deviceId, pc.identity.id);

    await phone.syncNow();
    expect((await phoneDevice.task(pcTask))!.title, 'Vom PC');

    final phoneTask = await phoneDevice.createTask('Vom Handy');
    await phone.syncNow();
    expect((await pcDevice.task(phoneTask))!.title, 'Vom Handy');
    expect(phone.state.phase, SyncPhase.synced);
    expect(phone.state.pending, 0);
  });

  test('falscher Code wird abgelehnt', () async {
    await pc.startPairing();
    await expectLater(
      phone.joinWith(address: '127.0.0.1:${pc.port}', code: '0000-0000-0000-0000'),
      throwsA(isA<SyncHttpException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('ohne offene Kopplung gibt es keinen Zugang', () async {
    await expectLater(
      phone.joinWith(address: '127.0.0.1:${pc.port}', code: PairingCode.generate()),
      throwsA(isA<SyncHttpException>().having((e) => e.statusCode, 'statusCode', 410)),
    );
  });

  test('Verschlüsselung erkennt falsche Schlüssel und veränderte Daten', () async {
    final key = SyncCrypto.randomKey();
    final sealed = await SyncCrypto.seal(key, [1, 2, 3], 'req|/push|a');
    expect(await SyncCrypto.open(key, sealed, 'req|/push|a'), [1, 2, 3]);
    await expectLater(SyncCrypto.open(SyncCrypto.randomKey(), sealed, 'req|/push|a'), throwsA(anything));
    await expectLater(SyncCrypto.open(key, sealed, 'req|/push|b'), throwsA(anything));
  });
}
