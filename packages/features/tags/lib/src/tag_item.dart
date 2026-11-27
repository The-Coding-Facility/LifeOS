/// Bereich, zu dem ein Tag gehört. Kalender- und Finanz-Tags sind getrennt.
enum TagScope {
  calendar('calendar'),
  finance('finance'),
  recipes('recipes');

  const TagScope(this.key);

  final String key;
}

/// Ein Tag, wie die Oberfläche ihn sieht.
class TagItem {
  const TagItem({
    required this.id,
    required this.scope,
    required this.name,
    this.colorIndex = 0,
    this.monthlyLimitCents,
  });

  final String id;
  final TagScope scope;
  final String name;

  /// Index in der Tag-Palette des Design-Systems.
  final int colorIndex;

  /// Monatsbudget in Cent (nur Finanzen), `null` = kein Budget.
  final int? monthlyLimitCents;

  bool get hasBudget => monthlyLimitCents != null;
}
