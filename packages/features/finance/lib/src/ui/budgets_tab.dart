import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../finance_math.dart';
import '../model.dart';
import '../providers.dart';
import 'common.dart';
import 'entry_editor_page.dart';
import 'overview_tab.dart';

/// Reiter „Budgets“: alle Finanz-Tags mit Monatsbudget und Ausgaben.
class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key, required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(financeEntriesProvider).value ?? const <FinanceEntry>[];
    final tags = ref.watch(tagsProvider(TagScope.finance)).value ?? const <TagItem>[];

    void open(TagItem tag) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => BudgetDetailPage(tagId: tag.id, today: today)),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tags ordnen Buchungen zu. Mit einem Monatsbudget siehst du, wie viel noch übrig ist.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => showNewTagDialog(context, ref, TagScope.finance),
            icon: const Icon(Icons.add),
            label: const Text('Neuer Tag'),
          ),
        ),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const EmptyState(icon: Icons.sell_outlined, message: 'Noch keine Tags, z. B. „Essen“ oder „Freizeit“.'),
        for (final tag in tags)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: tag.hasBudget
                  ? BudgetRow(status: budgetFor(tag, entries, today), onTap: () => open(tag))
                  : ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 6, backgroundColor: tagColor(tag.colorIndex)),
                      title: Text(tag.name),
                      subtitle: Text(
                        'Diesen Monat ${formatCents(spentInMonth(entries, tag.id, today))} · kein Budget',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(tag),
                    ),
            ),
          ),
      ],
    );
  }
}

/// Ein Tag im Detail: Budget festlegen, Verlauf, alle Buchungen mit dem Tag.
class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({super.key, required this.tagId, required this.today});

  final String tagId;
  final DateTime today;

  Future<void> _editLimit(BuildContext context, WidgetRef ref, TagItem tag) async {
    final cents = await askAmount(context, title: 'Monatsbudget für ${tag.name}', confirmLabel: 'Speichern');
    if (cents == null) return;
    await ref.read(tagRepositoryProvider).update(tag.id, monthlyLimitCents: cents);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TagItem tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tag „${tag.name}“ löschen?'),
        content: const Text('Die Buchungen bleiben erhalten, nur der Tag verschwindet.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tagRepositoryProvider).delete(tag.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tags = ref.watch(tagsProvider(TagScope.finance)).value ?? const <TagItem>[];
    final tag = tags.where((t) => t.id == tagId).firstOrNull;
    if (tag == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Dieser Tag existiert nicht mehr.')));
    }
    final entries = ref.watch(financeEntriesProvider).value ?? const <FinanceEntry>[];
    final withTag = [for (final entry in entries) if (entry.tagIds.contains(tag.id)) entry];

    return Scaffold(
      appBar: AppBar(
        title: Text(tag.name),
        actions: [
          IconButton(
            tooltip: 'Tag löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, tag),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tag.hasBudget) BudgetRow(status: budgetFor(tag, entries, today)),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _editLimit(context, ref, tag),
                child: Text(tag.hasBudget ? 'Budget ändern' : 'Monatsbudget festlegen'),
              ),
              if (tag.hasBudget)
                TextButton(
                  onPressed: () => ref.read(tagRepositoryProvider).update(tag.id, clearLimit: true),
                  child: const Text('Budget entfernen'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Ausgaben der letzten 6 Monate',
            icon: Icons.bar_chart,
            child: BarChartView(
              formatValue: formatEuroShort,
              groups: [
                for (var i = 5; i >= 0; i--)
                  () {
                    final month = DateTime(today.year, today.month - i);
                    return BarGroup(
                      label: germanMonthsShort[month.month - 1],
                      values: [BarValue(spentInMonth(entries, tag.id, month), tagColor(tag.colorIndex))],
                    );
                  }(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Verlauf', style: theme.textTheme.titleMedium),
          if (withTag.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keine Buchungen mit diesem Tag.'),
            ),
          for (final entry in withTag)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.title.isEmpty ? entry.kind.label : entry.title),
              subtitle: Text(formatDate(entry.date)),
              trailing: SignedAmount(entry: entry),
              onTap: () => openEntryEditor(context, entry: entry),
            ),
        ],
      ),
    );
  }
}
