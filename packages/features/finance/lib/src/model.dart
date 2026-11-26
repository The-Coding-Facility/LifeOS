/// Art einer Buchung. Der Betrag ist immer positiv; das Vorzeichen für den
/// Kontostand folgt aus der Art.
enum EntryKind {
  income('income', 'Einnahme'),
  expense('expense', 'Ausgabe'),
  saving('saving', 'Auf Sparziel gelegt'),
  withdrawal('withdrawal', 'Aus Sparziel genommen');

  const EntryKind(this.key, this.label);

  final String key;
  final String label;

  static EntryKind fromKey(String key) =>
      values.firstWhere((kind) => kind.key == key, orElse: () => EntryKind.expense);
}

/// Eine Buchung.
class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.date,
    this.title = '',
    this.tagIds = const [],
    this.savingGoalId,
    this.recurringId,
  });

  final String id;
  final EntryKind kind;
  final int amountCents;
  final String title;

  /// Buchungstag, lokale Mitternacht.
  final DateTime date;
  final List<String> tagIds;
  final String? savingGoalId;
  final String? recurringId;
}

/// Rhythmus eines Dauerauftrags.
enum RecurringFreq {
  weekly('weekly', 'Wöchentlich'),
  monthly('monthly', 'Monatlich'),
  yearly('yearly', 'Jährlich');

  const RecurringFreq(this.key, this.label);

  final String key;
  final String label;

  static RecurringFreq fromKey(String key) =>
      values.firstWhere((freq) => freq.key == key, orElse: () => RecurringFreq.monthly);
}

/// Ein Dauerauftrag, aus dem die App fällige Buchungen erzeugt.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.freq,
    required this.startDate,
    this.title = '',
    this.tagIds = const [],
    this.interval = 1,
    this.endDate,
  });

  final String id;
  final EntryKind kind;
  final int amountCents;
  final String title;
  final List<String> tagIds;
  final RecurringFreq freq;
  final int interval;

  /// Erster Buchungstag (lokale Mitternacht).
  final DateTime startDate;

  /// Letzter möglicher Buchungstag (inklusive), `null` = unbegrenzt.
  final DateTime? endDate;

  String describe() {
    final base = switch ((freq, interval)) {
      (RecurringFreq.weekly, 1) => 'Wöchentlich',
      (RecurringFreq.monthly, 1) => 'Monatlich am ${startDate.day}.',
      (RecurringFreq.yearly, 1) => 'Jährlich am ${startDate.day}.${startDate.month}.',
      (RecurringFreq.weekly, final n) => 'Alle $n Wochen',
      (RecurringFreq.monthly, final n) => 'Alle $n Monate am ${startDate.day}.',
      (RecurringFreq.yearly, final n) => 'Alle $n Jahre',
    };
    final end = endDate;
    return end == null ? base : '$base bis ${end.day}.${end.month}.${end.year}';
  }
}

/// Ein Sparziel.
class SavingGoal {
  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetCents,
    this.targetDate,
  });

  final String id;
  final String name;
  final int targetCents;
  final DateTime? targetDate;
}

/// Formularwerte einer Buchung.
class EntryDraft {
  const EntryDraft({
    required this.kind,
    required this.amountCents,
    required this.date,
    this.title = '',
    this.tagIds = const [],
    this.savingGoalId,
  });

  final EntryKind kind;
  final int amountCents;
  final DateTime date;
  final String title;
  final List<String> tagIds;
  final String? savingGoalId;
}

/// Formularwerte eines Dauerauftrags.
class RecurringDraft {
  const RecurringDraft({
    required this.kind,
    required this.amountCents,
    required this.freq,
    required this.startDate,
    this.title = '',
    this.tagIds = const [],
    this.interval = 1,
    this.endDate,
  });

  final EntryKind kind;
  final int amountCents;
  final String title;
  final List<String> tagIds;
  final RecurringFreq freq;
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
}
