import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_projects/lifeos_projects.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'router.dart';
import 'sync_status_indicator.dart';

/// Startseite mit Kacheln der Module.
///
/// Später wird daraus der frei konfigurierbare Baukasten (Architektur
/// Abschnitt 2). Bis dahin sind die Kacheln fest.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _weekdays = [
    'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag',
  ];
  static const _months = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  static String _today() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day}. ${_months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      CalendarDashboardTile(onOpen: () => context.go(Routes.calendar)),
      DailyReportTile(onOpen: () => context.go(Routes.dailyReport)),
      HabitsTile(onOpen: () => context.go(Routes.habits)),
      TasksDashboardTile(onOpenAll: () => context.go(Routes.tasks)),
      ProjectsTile(
        onOpenAll: () => context.go(Routes.projects),
        onOpenProject: (id) => context.go(Routes.project(id)),
      ),
      FinanceDashboardTile(onOpen: () => context.go(Routes.finance)),
      ShoppingListTile(onOpen: () => context.go(Routes.shoppingList)),
      PinnedNotesTile(onOpenNote: (id) => context.go(Routes.note(id))),
      NotesDashboardTile(
        onOpenAll: () => context.go(Routes.notes),
        onOpenNote: (id) => context.go(Routes.note(id)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Übersicht'),
        actions: const [
          SyncStatusIndicator(),
          SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 2 : 1;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_today(), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              if (columns == 1)
                for (final tile in tiles) ...[tile, const SizedBox(height: 16)]
              else
                for (var row = 0; row < tiles.length; row += 2) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tiles[row]),
                      const SizedBox(width: 16),
                      Expanded(child: row + 1 < tiles.length ? tiles[row + 1] : const SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
            ],
          );
        },
      ),
    );
  }
}
