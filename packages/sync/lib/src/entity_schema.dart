import 'package:drift/drift.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

/// Beschreibt, wie empfangene Änderungen in eine Fachtabelle geschrieben
/// werden. Nur hier genannte Spalten werden je geschrieben, damit ein
/// fremdes Gerät keine beliebigen Spalten setzen kann.
class EntitySchema {
  const EntitySchema({
    required this.table,
    required this.tableOf,
    required this.groups,
    this.insertDefaults = const {},
  });

  /// SQL-Name der Tabelle, gleich dem `entity` im Änderungsprotokoll.
  final String table;

  /// Die Drift-Tabelle, damit Ansichten nach dem Sync aktualisiert werden.
  final TableInfo<Table, Object?> Function(LifeosDatabase db) tableOf;

  /// Feldgruppe → SQL-Spalten.
  final Map<String, List<String>> groups;

  /// Pflichtwerte für eine neu angelegte Zeile, bevor die Gruppen
  /// geschrieben werden.
  final Map<String, Object?> insertDefaults;
}

/// Alle Fachtabellen, die synchronisiert werden.
final Map<String, EntitySchema> defaultEntitySchemas = {
  'tasks': EntitySchema(
    table: 'tasks',
    tableOf: (db) => db.tasks,
    insertDefaults: const {'title': ''},
    groups: const {
      'title': ['title'],
      'details': ['details'],
      'done': ['done', 'done_at'],
      'due': ['due_date'],
      'project': ['project_id'],
    },
  ),
  'notes': EntitySchema(
    table: 'notes',
    tableOf: (db) => db.notes,
    groups: const {
      'title': ['title'],
      'body': ['body'],
      'project': ['project_id'],
      'pinned': ['pinned'],
      'learning_area': ['learning_area_id'],
    },
  ),
  'tags': EntitySchema(
    table: 'tags',
    tableOf: (db) => db.tags,
    insertDefaults: const {'scope': '', 'name': ''},
    groups: const {
      'scope': ['scope'],
      'name': ['name'],
      'color': ['color_index'],
      'limit': ['monthly_limit_cents'],
    },
  ),
  'calendar_events': EntitySchema(
    table: 'calendar_events',
    tableOf: (db) => db.calendarEvents,
    insertDefaults: const {'title': '', 'start_at': 0, 'end_at': 0},
    groups: const {
      'title': ['title'],
      'details': ['description', 'location'],
      'time': ['all_day', 'start_at', 'end_at'],
      'recurrence': ['recurrence', 'exdates'],
      'tags': ['tag_ids'],
      'reminder': ['reminder_minutes', 'reminder_devices'],
      'project': ['project_id'],
      'training_plan': ['training_plan_id'],
    },
  ),
  'finance_entries': EntitySchema(
    table: 'finance_entries',
    tableOf: (db) => db.financeEntries,
    insertDefaults: const {'kind': 'expense', 'amount_cents': 0, 'date': '1970-01-01'},
    groups: const {
      'amount': ['kind', 'amount_cents'],
      'title': ['title'],
      'date': ['date'],
      'tags': ['tag_ids'],
      'link': ['saving_goal_id', 'recurring_id'],
    },
  ),
  'finance_recurring': EntitySchema(
    table: 'finance_recurring',
    tableOf: (db) => db.financeRecurring,
    insertDefaults: const {
      'kind': 'expense',
      'amount_cents': 0,
      'freq': 'monthly',
      'start_date': '1970-01-01',
    },
    groups: const {
      'amount': ['kind', 'amount_cents'],
      'title': ['title'],
      'tags': ['tag_ids'],
      'schedule': ['freq', 'interval_count', 'start_date', 'end_date'],
    },
  ),
  'daily_reports': EntitySchema(
    table: 'daily_reports',
    tableOf: (db) => db.dailyReports,
    insertDefaults: const {'date': '1970-01-01'},
    groups: const {
      'date': ['date'],
      'successes': ['successes'],
      'learned': ['learned'],
      'checks': ['calendar_done', 'kcal_goal_met', 'water_goal_met'],
      'sleep': ['slept_at', 'woke_at'],
      'activities': ['activities'],
    },
  ),
  'habits': EntitySchema(
    table: 'habits',
    tableOf: (db) => db.habits,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'color': ['color_index'],
      'schedule': ['weekdays'],
      'archived': ['archived'],
    },
  ),
  'habit_checks': EntitySchema(
    table: 'habit_checks',
    tableOf: (db) => db.habitChecks,
    insertDefaults: const {'habit_id': '', 'date': '1970-01-01'},
    groups: const {
      'key': ['habit_id', 'date'],
      'done': ['done'],
    },
  ),
  'projects': EntitySchema(
    table: 'projects',
    tableOf: (db) => db.projects,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'description': ['description'],
      'deadline': ['deadline'],
      'color': ['color_index'],
      'status': ['status'],
    },
  ),
  'ingredients': EntitySchema(
    table: 'ingredients',
    tableOf: (db) => db.ingredients,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'unit': ['unit'],
      'nutrition': ['kcal', 'protein', 'fat'],
    },
  ),
  'recipes': EntitySchema(
    table: 'recipes',
    tableOf: (db) => db.recipes,
    insertDefaults: const {'title': ''},
    groups: const {
      'title': ['title'],
      'details': ['minutes', 'servings'],
      'tags': ['tag_ids'],
      'ingredients': ['ingredients'],
      'preparation': ['preparation'],
    },
  ),
  'shopping_items': EntitySchema(
    table: 'shopping_items',
    tableOf: (db) => db.shoppingItems,
    insertDefaults: const {'name': ''},
    groups: const {
      'item': ['name', 'amount', 'unit', 'ingredient_id'],
      'source': ['recipe_id'],
      'checked': ['checked'],
    },
  ),
  'learning_areas': EntitySchema(
    table: 'learning_areas',
    tableOf: (db) => db.learningAreas,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'description': ['description'],
      'color': ['color_index'],
      'project': ['project_id'],
    },
  ),
  'glossary_entries': EntitySchema(
    table: 'glossary_entries',
    tableOf: (db) => db.glossaryEntries,
    insertDefaults: const {'area_id': '', 'term': ''},
    groups: const {
      'area': ['area_id'],
      'term': ['term'],
      'explanation': ['explanation'],
    },
  ),
  'flashcards': EntitySchema(
    table: 'flashcards',
    tableOf: (db) => db.flashcards,
    insertDefaults: const {'area_id': '', 'question': ''},
    groups: const {
      'area': ['area_id'],
      'question': ['question'],
      'answer': ['answer', 'kind', 'choices'],
    },
  ),
  'learning_resources': EntitySchema(
    table: 'learning_resources',
    tableOf: (db) => db.learningResources,
    insertDefaults: const {'area_id': '', 'title': ''},
    groups: const {
      'area': ['area_id'],
      'title': ['title'],
      'link': ['link'],
      'note': ['note'],
    },
  ),
  'study_sessions': EntitySchema(
    table: 'study_sessions',
    tableOf: (db) => db.studySessions,
    insertDefaults: const {'area_id': '', 'mode': 'learn', 'started_at': 0},
    groups: const {
      'data': [
        'area_id',
        'mode',
        'started_at',
        'duration_seconds',
        'total',
        'correct',
        'pass_percent',
        'answers',
      ],
    },
  ),
  'body_measurements': EntitySchema(
    table: 'body_measurements',
    tableOf: (db) => db.bodyMeasurements,
    insertDefaults: const {'date': '1970-01-01'},
    groups: const {
      'date': ['date'],
      'weight': ['weight'],
      'height': ['height'],
      'body_fat': ['body_fat'],
      'belly': ['belly'],
      'chest': ['chest'],
      'upper_arm': ['upper_arm'],
      'forearm': ['forearm'],
      'hip': ['hip'],
      'waist': ['waist'],
      'thigh': ['thigh'],
      'resting_pulse': ['resting_pulse'],
      'sleep_hours': ['sleep_hours'],
    },
  ),
  'nutrition_logs': EntitySchema(
    table: 'nutrition_logs',
    tableOf: (db) => db.nutritionLogs,
    insertDefaults: const {'date': '1970-01-01'},
    groups: const {
      'entry': ['date', 'label', 'kcal', 'protein', 'fat', 'water_ml'],
    },
  ),
  'sport_goals': EntitySchema(
    table: 'sport_goals',
    tableOf: (db) => db.sportGoals,
    groups: const {
      'kcal': ['kcal'],
      'protein': ['protein'],
      'fat': ['fat'],
      'water': ['water_ml'],
    },
  ),
  'exercises': EntitySchema(
    table: 'exercises',
    tableOf: (db) => db.exercises,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'category': ['category'],
      'description': ['description'],
    },
  ),
  'training_plans': EntitySchema(
    table: 'training_plans',
    tableOf: (db) => db.trainingPlans,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'kind': ['kind'],
      'steps': ['steps'],
    },
  ),
  'workout_sessions': EntitySchema(
    table: 'workout_sessions',
    tableOf: (db) => db.workoutSessions,
    insertDefaults: const {'started_at': 0},
    groups: const {
      'data': ['plan_id', 'started_at', 'duration_seconds', 'results'],
    },
  ),
  'saving_goals': EntitySchema(
    table: 'saving_goals',
    tableOf: (db) => db.savingGoals,
    insertDefaults: const {'name': '', 'target_cents': 0},
    groups: const {
      'name': ['name'],
      'target': ['target_cents', 'target_date'],
    },
  ),
};
