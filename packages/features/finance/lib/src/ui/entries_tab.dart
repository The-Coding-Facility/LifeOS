import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model.dart';
import '../providers.dart';
import 'common.dart';
import 'entry_editor_page.dart';

/// Reiter „Buchungen“: Daueraufträge und alle Buchungen nach Tag.
class EntriesTab extends ConsumerStatefulWidget {
  const EntriesTab({super.key});

  @override
  ConsumerState<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends ConsumerState<EntriesTab> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(financeEntriesProvider).value ?? const <FinanceEntry>[];
    final rules = ref.watch(recurringRulesProvider).value ?? const <RecurringRule>[];
    final tags = {
      for (final tag in ref.watch(tagsProvider(TagScope.finance)).value ?? const <TagItem>[]) tag.id: tag,
    };

    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? entries
        : [
            for (final entry in entries)
              if (entry.title.toLowerCase().contains(query) ||
                  entry.tagIds.any((id) => tags[id]?.name.toLowerCase().contains(query) ?? false))
                entry,
          ];

    final rows = <Widget>[];
    String? lastDay;
    for (final entry in visible) {
      final day = isoDate(entry.date);
      if (day != lastDay) {
        lastDay = day;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(formatDateLong(entry.date), style: theme.textTheme.labelLarge),
        ));
      }
      final tagNames = [for (final id in entry.tagIds) if (tags[id] != null) tags[id]!.name];
      rows.add(ListTile(
        title: Text(entry.title.isEmpty ? entry.kind.label : entry.title),
        subtitle: tagNames.isEmpty && entry.recurringId == null
            ? null
            : Text([if (entry.recurringId != null) 'Dauerauftrag', ...tagNames].join(' · ')),
        trailing: SignedAmount(entry: entry),
        onTap: () => openEntryEditor(context, entry: entry),
      ));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Suchen nach Titel oder Tag',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        if (rules.isNotEmpty)
          ExpansionTile(
            leading: const Icon(Icons.repeat),
            title: Text('Daueraufträge (${rules.length})'),
            children: [
              for (final rule in rules)
                ListTile(
                  title: Text(rule.title.isEmpty ? rule.kind.label : rule.title),
                  subtitle: Text(rule.describe()),
                  trailing: Text(
                    formatCents(rule.kind == EntryKind.income ? rule.amountCents : -rule.amountCents, withSign: true),
                  ),
                  onTap: () => openEntryEditor(context, rule: rule),
                ),
            ],
          ),
        if (visible.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            message: query.isEmpty ? 'Noch keine Buchungen.' : 'Nichts gefunden.',
          ),
        ...rows,
      ],
    );
  }
}
