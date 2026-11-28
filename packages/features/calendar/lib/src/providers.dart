import 'package:flutter/widgets.dart';
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

/// Ein Projekt, dem ein Termin zugeordnet werden kann.
class ProjectChoice {
  const ProjectChoice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Aktive Projekte für die Auswahl im Terminformular. Die App liefert sie,
/// damit der Kalender das Projektmodul nicht kennen muss. Ohne Überschreiben
/// gibt es keine Auswahl.
final projectChoicesProvider = StreamProvider<List<ProjectChoice>>(
  (ref) => Stream.value(const <ProjectChoice>[]),
);

/// Ein Trainingsplan, der einem Termin zugeordnet werden kann.
class TrainingPlanChoice {
  const TrainingPlanChoice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Trainingspläne für die Auswahl im Terminformular. Die App liefert sie aus
/// dem Sportmodul; ohne Überschreiben gibt es keine Auswahl.
final trainingPlanChoicesProvider = StreamProvider<List<TrainingPlanChoice>>(
  (ref) => Stream.value(const <TrainingPlanChoice>[]),
);

/// Startet das Abspielen eines Trainingsplans.
typedef StartTraining = void Function(BuildContext context, String planId);

/// Von der App gesetzt; `null` = kein Start aus dem Termin möglich.
final startTrainingProvider = Provider<StartTraining?>((ref) => null);
