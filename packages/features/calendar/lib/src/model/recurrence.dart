import 'package:lifeos_core/lifeos_core.dart';

/// Wie oft sich ein Termin wiederholt.
enum RecurrenceFreq {
  daily('daily', 'Täglich'),
  weekly('weekly', 'Wöchentlich'),
  monthly('monthly', 'Monatlich'),
  yearly('yearly', 'Jährlich');

  const RecurrenceFreq(this.key, this.label);

  final String key;
  final String label;

  static RecurrenceFreq? fromKey(String? key) {
    for (final freq in values) {
      if (freq.key == key) return freq;
    }
    return null;
  }
}

/// Wiederholungsregel eines Termins.
class Recurrence {
  const Recurrence({
    required this.freq,
    this.interval = 1,
    this.weekdays = const {},
    this.until,
  }) : assert(interval >= 1);

  final RecurrenceFreq freq;

  /// „Alle n“ Tage, Wochen, Monate oder Jahre.
  final int interval;

  /// Nur bei wöchentlich: 1 = Montag … 7 = Sonntag. Leer = Wochentag des
  /// ersten Termins.
  final Set<int> weekdays;

  /// Letzter Tag, an dem noch ein Termin beginnen darf (inklusive).
  final DateTime? until;

  Map<String, Object?> toJson() => {
        'freq': freq.key,
        'interval': interval,
        if (weekdays.isNotEmpty) 'weekdays': (weekdays.toList()..sort()),
        if (until != null) 'until': isoDate(until!),
      };

  /// Liest eine gespeicherte Regel. Unbekannte Werte ergeben `null`, damit
  /// ein kaputter Eintrag nie die ganze Ansicht verhindert.
  static Recurrence? fromJson(Object? json) {
    if (json is! Map) return null;
    final freq = RecurrenceFreq.fromKey(json['freq'] as String?);
    if (freq == null) return null;
    final interval = json['interval'];
    final weekdays = json['weekdays'];
    final until = json['until'];
    DateTime? untilDate;
    if (until is String) {
      try {
        untilDate = parseIsoDate(until);
      } on FormatException {
        untilDate = null;
      }
    }
    return Recurrence(
      freq: freq,
      interval: interval is int && interval >= 1 ? interval : 1,
      weekdays: weekdays is List
          ? {for (final day in weekdays) if (day is int && day >= 1 && day <= 7) day}
          : const {},
      until: untilDate,
    );
  }

  Recurrence copyWith({
    RecurrenceFreq? freq,
    int? interval,
    Set<int>? weekdays,
    DateTime? until,
    bool clearUntil = false,
  }) {
    return Recurrence(
      freq: freq ?? this.freq,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      until: clearUntil ? null : (until ?? this.until),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      other.freq == freq &&
      other.interval == interval &&
      other.until == until &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(freq, interval, until, Object.hashAllUnordered(weekdays));

  /// Kurzer deutscher Text, z. B. „Alle 2 Wochen bis 31.12.2026“.
  String describe() {
    final base = switch ((freq, interval)) {
      (RecurrenceFreq.daily, 1) => 'Täglich',
      (RecurrenceFreq.weekly, 1) => 'Wöchentlich',
      (RecurrenceFreq.monthly, 1) => 'Monatlich',
      (RecurrenceFreq.yearly, 1) => 'Jährlich',
      (RecurrenceFreq.daily, final n) => 'Alle $n Tage',
      (RecurrenceFreq.weekly, final n) => 'Alle $n Wochen',
      (RecurrenceFreq.monthly, final n) => 'Alle $n Monate',
      (RecurrenceFreq.yearly, final n) => 'Alle $n Jahre',
    };
    final end = until == null ? '' : ' bis ${until!.day}.${until!.month}.${until!.year}';
    return '$base$end';
  }
}
