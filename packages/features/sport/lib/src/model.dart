/// Eine Körpermessung mit Spaltenname, Anzeige und Einheit.
enum Measure {
  weight('weight', 'Gewicht', 'kg'),
  height('height', 'Größe', 'cm'),
  bodyFat('body_fat', 'Körperfett', '%'),
  belly('belly', 'Bauchumfang', 'cm'),
  chest('chest', 'Brustumfang', 'cm'),
  upperArm('upper_arm', 'Oberarmumfang', 'cm'),
  forearm('forearm', 'Unterarmumfang', 'cm'),
  hip('hip', 'Hüftumfang', 'cm'),
  waist('waist', 'Taillenumfang', 'cm'),
  thigh('thigh', 'Oberschenkelumfang', 'cm'),
  restingPulse('resting_pulse', 'Ruhepuls', 'bpm'),
  sleepHours('sleep_hours', 'Schlafdauer', 'h');

  const Measure(this.column, this.label, this.unit);

  /// SQL-Spalte und Feldgruppe.
  final String column;
  final String label;
  final String unit;
}

/// Körperdaten eines Tages.
class BodyEntry {
  const BodyEntry({required this.date, this.values = const {}});

  /// Lokale Mitternacht.
  final DateTime date;
  final Map<Measure, double> values;
}

/// Ein Eintrag im Ernährungs- und Wassertracker.
class NutritionLog {
  const NutritionLog({
    required this.id,
    required this.date,
    this.label = '',
    this.kcal = 0,
    this.protein = 0,
    this.fat = 0,
    this.waterMl = 0,
  });

  final String id;
  final DateTime date;
  final String label;
  final double kcal;
  final double protein;
  final double fat;
  final double waterMl;
}

/// Tagesziele; `null` = kein Ziel.
class IntakeGoals {
  const IntakeGoals({this.kcal, this.protein, this.fat, this.waterMl});

  final double? kcal;
  final double? protein;
  final double? fat;
  final double? waterMl;
}

/// Summe eines Tages.
class DayIntake {
  const DayIntake({this.kcal = 0, this.protein = 0, this.fat = 0, this.waterMl = 0});

  final double kcal;
  final double protein;
  final double fat;
  final double waterMl;
}

/// Bereich einer Übung.
enum ExerciseCategory {
  strength('strength', 'Kraft'),
  endurance('endurance', 'Ausdauer');

  const ExerciseCategory(this.key, this.label);

  final String key;
  final String label;

  static ExerciseCategory fromKey(String key) =>
      key == 'endurance' ? ExerciseCategory.endurance : ExerciseCategory.strength;
}

/// Eine Übung im Katalog.
class Exercise {
  const Exercise({required this.id, required this.name, this.category = ExerciseCategory.strength, this.description = ''});

  final String id;
  final String name;
  final ExerciseCategory category;
  final String description;
}

/// Art eines Trainingsplans.
enum PlanKind {
  strength('strength', 'Kraft'),
  endurance('endurance', 'Ausdauer'),
  mixed('mixed', 'Gemischt');

  const PlanKind(this.key, this.label);

  final String key;
  final String label;

  static PlanKind fromKey(String key) =>
      values.firstWhere((kind) => kind.key == key, orElse: () => PlanKind.strength);
}

/// Ein Schritt eines Plans: Übung mit Vorgabe- und Ruhezeit (Sekunden).
/// Vorgabezeit 0 = ohne Countdown, weiter per Knopf.
class PlanStep {
  const PlanStep({required this.exerciseId, this.seconds = 60, this.restSeconds = 30});

  final String exerciseId;
  final int seconds;
  final int restSeconds;

  Map<String, Object?> toJson() => {'exercise_id': exerciseId, 'seconds': seconds, 'rest_seconds': restSeconds};

  static PlanStep? fromJson(Object? json) {
    if (json is! Map || json['exercise_id'] is! String) return null;
    int number(Object? value) => value is num && value >= 0 ? value.toInt() : 0;
    return PlanStep(
      exerciseId: json['exercise_id'] as String,
      seconds: number(json['seconds']),
      restSeconds: number(json['rest_seconds']),
    );
  }
}

/// Ein Trainingsplan.
class TrainingPlan {
  const TrainingPlan({required this.id, required this.name, this.kind = PlanKind.strength, this.steps = const []});

  final String id;
  final String name;
  final PlanKind kind;
  final List<PlanStep> steps;

  /// Summe aus Vorgabe- und Ruhezeiten; die Ruhe nach der letzten Übung
  /// zählt nicht.
  Duration get totalDuration {
    var seconds = 0;
    for (var i = 0; i < steps.length; i++) {
      seconds += steps[i].seconds;
      if (i < steps.length - 1) seconds += steps[i].restSeconds;
    }
    return Duration(seconds: seconds);
  }
}

/// Messwert, der bei einer Übung notiert werden kann.
enum ResultMetric {
  weight('weight', 'Gewicht', 'kg'),
  reps('reps', 'Wiederholungen', '×'),
  distanceKm('distance_km', 'Distanz', 'km'),
  minutes('minutes', 'Zeit', 'min'),
  avgPulse('avg_pulse', 'Ø Puls', 'bpm'),
  maxPulse('max_pulse', 'Max. Puls', 'bpm');

  const ResultMetric(this.key, this.label, this.unit);

  final String key;
  final String label;
  final String unit;
}

/// Notierte Werte einer Übung in einem Training.
class ExerciseResult {
  const ExerciseResult({required this.exerciseId, this.values = const {}});

  final String exerciseId;
  final Map<ResultMetric, double> values;

  Map<String, Object?> toJson() => {
        'exercise_id': exerciseId,
        for (final MapEntry(:key, :value) in values.entries) key.key: value,
      };

  static ExerciseResult? fromJson(Object? json) {
    if (json is! Map || json['exercise_id'] is! String) return null;
    return ExerciseResult(
      exerciseId: json['exercise_id'] as String,
      values: {
        for (final metric in ResultMetric.values)
          if (json[metric.key] is num) metric: (json[metric.key] as num).toDouble(),
      },
    );
  }
}

/// Ein durchgeführtes Training.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.duration,
    this.planId,
    this.results = const [],
  });

  final String id;
  final String? planId;
  final DateTime startedAt;
  final Duration duration;
  final List<ExerciseResult> results;
}
