import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../finance_math.dart';
import '../providers.dart';

/// Dashboard-Kachel: Kontostand, Ausgaben des Monats, knappe Budgets.
class FinanceDashboardTile extends ConsumerWidget {
  const FinanceDashboardTile({super.key, required this.onOpen, this.clock});

  final VoidCallback onOpen;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = dateOnly((clock ?? DateTime.now)());
    final entries = ref.watch(financeEntriesProvider);
    final tags = ref.watch(tagsProvider(TagScope.finance)).value ?? const <TagItem>[];

    return SectionCard(
      title: 'Finanzen',
      icon: Icons.account_balance_wallet_outlined,
      action: TextButton(onPressed: onOpen, child: const Text('Öffnen')),
      child: entries.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text('Fehler: $error'),
        data: (all) {
          if (all.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Noch keine Buchungen.'),
            );
          }
          final month = monthTotals(all, today: today, months: 1).single;
          final tight = [
            for (final tag in tags)
              if (tag.hasBudget) budgetFor(tag, all, today),
          ].where((status) => status.ratio >= 0.8).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(formatCents(balance(all, upTo: today)), style: theme.textTheme.headlineSmall),
              Text('Ausgaben im ${germanMonths[today.month - 1]}: ${formatCents(month.expenseCents)}',
                  style: theme.textTheme.bodySmall),
              for (final status in tight) ...[
                const SizedBox(height: 8),
                Text(
                  status.remainingCents >= 0
                      ? '${status.tag.name}: noch ${formatCents(status.remainingCents)}'
                      : '${status.tag.name}: ${formatCents(-status.remainingCents)} über dem Budget',
                ),
                const SizedBox(height: 4),
                BudgetBar(value: status.spentCents, limit: status.limitCents, color: tagColor(status.tag.colorIndex)),
              ],
            ],
          );
        },
      ),
    );
  }
}
