import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../finance_math.dart';
import '../model.dart';
import '../providers.dart';
import 'entry_editor_page.dart';

/// Reiter „Jahr“: alle Ausgaben eines Jahres, nach Monat gruppiert.
class YearTab extends ConsumerStatefulWidget {
  const YearTab({super.key, required this.today});

  final DateTime today;

  @override
  ConsumerState<YearTab> createState() => _YearTabState();
}

class _YearTabState extends ConsumerState<YearTab> {
  late int _year = widget.today.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(financeEntriesProvider).value ?? const <FinanceEntry>[];
    final groups = yearExpenses(entries, _year);
    final total = groups.fold<int>(0, (sum, group) => sum + group.totalCents);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Voriges Jahr',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _year--),
            ),
            Text('$_year', style: theme.textTheme.titleLarge),
            IconButton(
              tooltip: 'Nächstes Jahr',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _year++),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Ausgaben gesamt', style: theme.textTheme.labelMedium),
                Text(formatCents(total), style: theme.textTheme.titleMedium),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Keine Ausgaben in $_year.', textAlign: TextAlign.center),
          ),
        for (final group in groups)
          Card(
            child: ExpansionTile(
              title: Text(germanMonths[group.month.month - 1]),
              subtitle: Text('${group.entries.length} Ausgaben'),
              trailing: Text(formatCents(group.totalCents), style: theme.textTheme.titleSmall),
              children: [
                for (final entry in group.entries)
                  ListTile(
                    dense: true,
                    title: Text(entry.title.isEmpty ? entry.kind.label : entry.title),
                    subtitle: Text(formatDate(entry.date)),
                    trailing: Text(formatCents(entry.amountCents)),
                    onTap: () => openEntryEditor(context, entry: entry),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
