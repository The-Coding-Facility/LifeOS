import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../finance_math.dart';
import '../model.dart';
import '../providers.dart';
import 'common.dart';

/// Reiter „Übersicht“: Kontostand, Verlauf, Monatsbalken, Budgets.
class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({super.key, required this.today, required this.onOpenBudgets});

  final DateTime today;
  final VoidCallback onOpenBudgets;

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> {
  var _days = 30;

  Future<void> _addStartBalance() async {
    final cents = await askAmount(context, title: 'Wie viel Geld hast du gerade?', confirmLabel: 'Eintragen');
    if (cents == null) return;
    await ref.read(financeRepositoryProvider).addEntry(
          EntryDraft(kind: EntryKind.income, amountCents: cents, date: widget.today, title: 'Startguthaben'),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(financeEntriesProvider);
    final tags = ref.watch(tagsProvider(TagScope.finance)).value ?? const <TagItem>[];

    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (all) {
        if (all.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: 'Noch keine Buchungen. Trag zuerst ein, wie viel Geld du gerade hast.',
              ),
              Center(
                child: FilledButton.icon(
                  onPressed: _addStartBalance,
                  icon: const Icon(Icons.savings_outlined),
                  label: const Text('Startguthaben eintragen'),
                ),
              ),
            ],
          );
        }

        final today = widget.today;
        final current = balance(all, upTo: today);
        final month = monthTotals(all, today: today, months: 1).single;
        final series = balanceSeries(all, today: today, days: _days);
        final months = monthTotals(all, today: today);
        final budgets = [
          for (final tag in tags)
            if (tag.hasBudget) budgetFor(tag, all, today),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kontostand', style: theme.textTheme.labelLarge),
                    Text(
                      formatCents(current),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: current < 0 ? theme.colorScheme.error : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${germanMonths[today.month - 1]}: '
                      '${formatCents(month.incomeCents)} Einnahmen · ${formatCents(month.expenseCents)} Ausgaben',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Verlauf',
              icon: Icons.show_chart,
              action: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 30, label: Text('30 Tage')),
                  ButtonSegment(value: 365, label: Text('365 Tage')),
                ],
                selected: {_days},
                onSelectionChanged: (selection) => setState(() => _days = selection.first),
              ),
              child: LineChartView(
                values: series,
                formatValue: formatEuroShort,
                startLabel: _days == 30 ? 'vor 30 Tagen' : 'vor einem Jahr',
                endLabel: 'heute',
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Einnahmen und Ausgaben je Monat',
              icon: Icons.bar_chart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BarChartView(
                    formatValue: formatEuroShort,
                    groups: [
                      for (final m in months)
                        BarGroup(
                          label: germanMonthsShort[m.month.month - 1],
                          values: [
                            BarValue(m.incomeCents, incomeColor(context)),
                            BarValue(m.expenseCents, expenseColor(context)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      _Legend(color: incomeColor(context), label: 'Einnahmen'),
                      _Legend(color: expenseColor(context), label: 'Ausgaben'),
                    ],
                  ),
                ],
              ),
            ),
            if (budgets.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: 'Budgets im ${germanMonths[today.month - 1]}',
                icon: Icons.pie_chart_outline,
                action: TextButton(onPressed: widget.onOpenBudgets, child: const Text('Alle')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final status in budgets) BudgetRow(status: status)],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Eine Zeile mit Name, Balken, Rest und Vergleich zum Vormonat.
class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.status, this.onTap});

  final BudgetStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = status.remainingCents;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: tagColor(status.tag.colorIndex)),
                const SizedBox(width: 8),
                Expanded(child: Text(status.tag.name, style: theme.textTheme.titleSmall)),
                Text(
                  remaining >= 0 ? 'noch ${formatCents(remaining)}' : '${formatCents(-remaining)} drüber',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: remaining < 0 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            BudgetBar(value: status.spentCents, limit: status.limitCents, color: tagColor(status.tag.colorIndex)),
            const SizedBox(height: 4),
            Text(
              '${formatCents(status.spentCents)} von ${formatCents(status.limitCents)} · ${describeDelta(status.deltaCents)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
