import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

/// ID dieses Geräts. Wird in `main()` überschrieben.
final deviceIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('deviceIdProvider muss in main() überschrieben werden.'),
);

/// Sync-Dienst. Wird in `main()` überschrieben.
final syncServiceProvider = Provider<SyncService>(
  (ref) => throw UnimplementedError('syncServiceProvider muss in main() überschrieben werden.'),
);

/// Aktueller Sync-Zustand, beginnend mit dem letzten bekannten Stand.
final syncStateProvider = StreamProvider<SyncState>((ref) async* {
  final service = ref.watch(syncServiceProvider);
  yield service.state;
  yield* service.states;
});

/// Gekoppelte Geräte, live aus der Datenbank.
final pairedDevicesProvider = StreamProvider<List<PairedDevice>>(
  (ref) => ref.watch(syncServiceProvider).watchDevices(),
);
