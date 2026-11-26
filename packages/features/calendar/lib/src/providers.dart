import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_repository.dart';
import 'model/event.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => throw UnimplementedError('eventRepositoryProvider muss in main() überschrieben werden.'),
);

/// Alle Termine, live aus der Datenbank.
final eventsProvider = StreamProvider<List<CalendarEvent>>(
  (ref) => ref.watch(eventRepositoryProvider).watchAll(),
);

/// Ein Gerät, das bei Erinnerungen ausgewählt werden kann.
class DeviceChoice {
  const DeviceChoice({required this.id, required this.name, this.isThisDevice = false});

  final String id;
  final String name;
  final bool isThisDevice;
}

/// Dieses Gerät und alle gekoppelten Geräte. Die App liefert die Liste,
/// weil nur sie den Sync kennt.
final deviceChoicesProvider = StreamProvider<List<DeviceChoice>>(
  (ref) => throw UnimplementedError('deviceChoicesProvider muss in main() überschrieben werden.'),
);
