import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Körperdaten, Tracker, Ziele, Übungen, Pläne und Trainings.
class SportRepository {
  SportRepository(this._db, ChangeRecorder recorder) : _writer = RecordWriter(_db, recorder);

  final LifeosDatabase _db;
  final RecordWriter _writer;

  /// ID der Körperdaten von [date]; auf jedem Gerät gleich.
  static String bodyIdFor(DateTime date) => Ids.deterministic('body', isoDate(date));

  /// Feste ID der einen Zielzeile.
  static const String goalsId = 'goals';

  // ---------------------------------------------------------- Körperdaten

  Stream<List<BodyEntry>> watchBody() {
    final query = _db.select(_db.bodyMeasurements)
      ..where((b) => b.deletedHlc.isNull())
      ..orderBy([(b) => OrderingTerm.asc(b.date)]);
    return query.watch().map((rows) => [for (final row in rows) _body(row)]);
  }

  /// Speichert die Werte von [date]. Nur geänderte Messungen werden
  /// protokolliert; `null` löscht einen Wert.
  Future<void> saveBody(DateTime date, Map<Measure, double?> values) {
    return _db.transaction(() async {
      final id = bodyIdFor(date);
      final row = await (_db.select(_db.bodyMeasurements)..where((b) => b.id.equals(id))).getSingleOrNull();
      final existing = row == null ? <Measure, double>{} : _body(row).values;
      final groups = <String, Map<String, Object?>>{
        for (final MapEntry(key: measure, value: value) in values.entries)
          if (row == null ? value != null : existing[measure] != value) measure.column: {measure.column: value},
      };
      if (groups.isEmpty) return;
      if (row == null) {
        await _writer.insert('body_measurements', _db.bodyMeasurements, id, {
          'date': {'date': isoDate(date)},
          ...groups,
        });
      } else {
        await _writer.update('body_measurements', _db.bodyMeasurements, id, groups);
      }
    });
  }

  // -------------------------------------------------------------- Tracker

  Stream<List<NutritionLog>> watchNutrition({required DateTime from}) {
    final query = _db.select(_db.nutritionLogs)
      ..where((n) => n.deletedHlc.isNull() & n.date.isBiggerOrEqualValue(isoDate(from)))
      ..orderBy([(n) => OrderingTerm.asc(n.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _log(row)]);
  }

  Future<String> addNutrition(
    DateTime date, {
    String label = '',
    double kcal = 0,
    double protein = 0,
    double fat = 0,
    double waterMl = 0,
  }) {
    return _db.transaction(() async {
      final id = Ids.newId();
      await _writer.insert('nutrition_logs', _db.nutritionLogs, id, {
        'entry': {
          'date': isoDate(date),
          'label': label.trim(),
          'kcal': kcal,
          'protein': protein,
          'fat': fat,
          'water_ml': waterMl,
        },
      });
      return id;
    });
  }

  Future<void> deleteNutrition(String id) =>
      _db.transaction(() => _writer.delete('nutrition_logs', _db.nutritionLogs, id));

  // ---------------------------------------------------------------- Ziele

  Stream<IntakeGoals> watchGoals() {
    final query = _db.select(_db.sportGoals)..where((g) => g.id.equals(goalsId) & g.deletedHlc.isNull());
    return query.watchSingleOrNull().map(
          (row) => row == null
              ? const IntakeGoals()
              : IntakeGoals(kcal: row.kcal, protein: row.protein, fat: row.fat, waterMl: row.waterMl),
        );
  }

  Future<void> setGoals(IntakeGoals goals) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.sportGoals)..where((g) => g.id.equals(goalsId))).getSingleOrNull();
      const groupColumns = {
        'kcal': ['kcal'],
        'protein': ['protein'],
        'fat': ['fat'],
        'water': ['water_ml'],
      };
      final wanted = {'kcal': goals.kcal, 'protein': goals.protein, 'fat': goals.fat, 'water_ml': goals.waterMl};
      if (row == null) {
        await _writer.insert('sport_goals', _db.sportGoals, goalsId, RecordWriter.allGroups(groupColumns, wanted));
      } else {
        await _writer.update(
          'sport_goals',
          _db.sportGoals,
          goalsId,
          RecordWriter.changedGroups(groupColumns, wanted, {
            'kcal': row.kcal,
            'protein': row.protein,
            'fat': row.fat,
            'water_ml': row.waterMl,
          }),
        );
      }
    });
  }

  // -------------------------------------------------------------- Übungen

  static const _exerciseGroups = {
    'name': ['name'],
    'category': ['category'],
    'description': ['description'],
  };

  Stream<List<Exercise>> watchExercises() {
    final query = _db.select(_db.exercises)..where((e) => e.deletedHlc.isNull());
    return query.watch().map((rows) {
      final items = [for (final row in rows) _exercise(row)];
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  Future<String> addExercise({required String name, required ExerciseCategory category, String description = ''}) {
    final columns = {'name': _require(name, 'Eine Übung braucht einen Namen.'), 'category': category.key, 'description': description.trim()};
    return _db.transaction(() async {
      final id = Ids.newId();
      await _writer.insert('exercises', _db.exercises, id, RecordWriter.allGroups(_exerciseGroups, columns));
      return id;
    });
  }

  Future<void> updateExercise(Exercise exercise, {required String name, required ExerciseCategory category, String description = ''}) {
    return _db.transaction(
      () => _writer.update(
        'exercises',
        _db.exercises,
        exercise.id,
        RecordWriter.changedGroups(
          _exerciseGroups,
          {'name': _require(name, 'Eine Übung braucht einen Namen.'), 'category': category.key, 'description': description.trim()},
          {'name': exercise.name, 'category': exercise.category.key, 'description': exercise.description},
        ),
      ),
    );
  }

  Future<void> deleteExercise(String id) => _db.transaction(() => _writer.delete('exercises', _db.exercises, id));

  // ----------------------------------------------------------------- Pläne

  static const _planGroups = {
    'name': ['name'],
    'kind': ['kind'],
    'steps': ['steps'],
  };

  Stream<List<TrainingPlan>> watchPlans() {
    final query = _db.select(_db.trainingPlans)..where((p) => p.deletedHlc.isNull());
    return query.watch().map((rows) {
      final plans = [for (final row in rows) _plan(row)];
      plans.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return plans;
    });
  }

  Future<String> addPlan({required String name, required PlanKind kind, List<PlanStep> steps = const []}) {
    return _db.transaction(() async {
      final id = Ids.newId();
      await _writer.insert('training_plans', _db.trainingPlans, id, RecordWriter.allGroups(_planGroups, _planColumns(name, kind, steps)));
      return id;
    });
  }

  Future<void> updatePlan(TrainingPlan plan, {required String name, required PlanKind kind, required List<PlanStep> steps}) {
    return _db.transaction(
      () => _writer.update(
        'training_plans',
        _db.trainingPlans,
        plan.id,
        RecordWriter.changedGroups(_planGroups, _planColumns(name, kind, steps), _planColumns(plan.name, plan.kind, plan.steps)),
      ),
    );
  }

  Future<void> deletePlan(String id) => _db.transaction(() => _writer.delete('training_plans', _db.trainingPlans, id));

  // -------------------------------------------------------------- Trainings

  Stream<List<WorkoutSession>> watchWorkouts() {
    final query = _db.select(_db.workoutSessions)
      ..where((w) => w.deletedHlc.isNull())
      ..orderBy([(w) => OrderingTerm.desc(w.startedAt)]);
    return query.watch().map((rows) => [for (final row in rows) _workout(row)]);
  }

  Future<String> saveWorkout({
    String? planId,
    required DateTime startedAt,
    required Duration duration,
    List<ExerciseResult> results = const [],
  }) {
    return _db.transaction(() async {
      final id = Ids.newId();
      await _writer.insert('workout_sessions', _db.workoutSessions, id, {
        'data': {
          'plan_id': planId,
          'started_at': startedAt.toUtc().millisecondsSinceEpoch,
          'duration_seconds': duration.inSeconds,
          'results': jsonEncode([for (final result in results) result.toJson()]),
        },
      });
      return id;
    });
  }

  Future<void> deleteWorkout(String id) =>
      _db.transaction(() => _writer.delete('workout_sessions', _db.workoutSessions, id));

  // ---------------------------------------------------------------- Intern

  static Map<String, Object?> _planColumns(String name, PlanKind kind, List<PlanStep> steps) => {
        'name': _require(name, 'Ein Plan braucht einen Namen.'),
        'kind': kind.key,
        'steps': jsonEncode([for (final step in steps) step.toJson()]),
      };

  static String _require(String text, String message) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError(message);
    return trimmed;
  }

  static DateTime _date(String text) {
    try {
      return parseIsoDate(text);
    } on FormatException {
      return DateTime(1970);
    }
  }

  static List<Object?> _list(String json) {
    try {
      final value = jsonDecode(json);
      return value is List ? value : const [];
    } on FormatException {
      return const [];
    }
  }

  static BodyEntry _body(BodyMeasurementRow row) {
    final raw = <Measure, double?>{
      Measure.weight: row.weight,
      Measure.height: row.height,
      Measure.bodyFat: row.bodyFat,
      Measure.belly: row.belly,
      Measure.chest: row.chest,
      Measure.upperArm: row.upperArm,
      Measure.forearm: row.forearm,
      Measure.hip: row.hip,
      Measure.waist: row.waist,
      Measure.thigh: row.thigh,
      Measure.restingPulse: row.restingPulse,
      Measure.sleepHours: row.sleepHours,
    };
    return BodyEntry(
      date: _date(row.date),
      values: {
        for (final MapEntry(:key, :value) in raw.entries)
          if (value != null) key: value,
      },
    );
  }

  static NutritionLog _log(NutritionLogRow row) => NutritionLog(
        id: row.id,
        date: _date(row.date),
        label: row.label,
        kcal: row.kcal,
        protein: row.protein,
        fat: row.fat,
        waterMl: row.waterMl,
      );

  static Exercise _exercise(ExerciseRow row) => Exercise(
        id: row.id,
        name: row.name,
        category: ExerciseCategory.fromKey(row.category),
        description: row.description,
      );

  static TrainingPlan _plan(TrainingPlanRow row) => TrainingPlan(
        id: row.id,
        name: row.name,
        kind: PlanKind.fromKey(row.kind),
        steps: [
          for (final item in _list(row.steps))
            if (PlanStep.fromJson(item) case final step?) step,
        ],
      );

  static WorkoutSession _workout(WorkoutSessionRow row) => WorkoutSession(
        id: row.id,
        planId: row.planId,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row.startedAt, isUtc: true).toLocal(),
        duration: Duration(seconds: row.durationSeconds),
        results: [
          for (final item in _list(row.results))
            if (ExerciseResult.fromJson(item) case final result?) result,
        ],
      );
}
