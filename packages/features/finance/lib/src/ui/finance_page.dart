import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../providers.dart';
import 'budgets_tab.dart';
import 'entries_tab.dart';
import 'entry_editor_page.dart';
import 'goals_tab.dart';
import 'overview_tab.dart';
import 'year_tab.dart';

/// Finanzen mit den Reitern Übersicht, Buchungen, Budgets, Sparziele, Jahr.
class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key, this.clock, this.bookDueRecurring = true});

  /// Für Tests; sonst die Systemzeit.
  final DateTime Function()? clock;

  /// Beim Öffnen fällige Daueraufträge buchen (in Tests abschaltbar).
  final bool bookDueRecurring;

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  DateTime get _today => dateOnly((widget.clock ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    if (widget.bookDueRecurring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(financeRepositoryProvider).generateDueRecurring();
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzen'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Übersicht'),
            Tab(text: 'Buchungen'),
            Tab(text: 'Budgets'),
            Tab(text: 'Sparziele'),
            Tab(text: 'Jahr'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEntryEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Buchung'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          OverviewTab(today: today, onOpenBudgets: () => _tabs.animateTo(2)),
          const EntriesTab(),
          BudgetsTab(today: today),
          const GoalsTab(),
          YearTab(today: today),
        ],
      ),
    );
  }
}
