import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';
import 'package:lifeos_learning/lifeos_learning.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_projects/lifeos_projects.dart';
import 'package:lifeos_security/lifeos_security.dart';
import 'package:lifeos_sport/lifeos_sport.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'dashboard_page.dart';
import 'devices/devices_page.dart';
import 'settings_page.dart';

/// Routen der App. Die App-Sperre entscheidet per Weiterleitung, ob
/// Einrichtung, Sperrbildschirm oder Inhalt gezeigt wird.
abstract final class Routes {
  static const setup = '/einrichtung';
  static const lock = '/gesperrt';
  static const recover = '/pin-zuruecksetzen';
  static const dashboard = '/';
  static const calendar = '/kalender';
  static const tasks = '/aufgaben';
  static const finance = '/finanzen';
  static const dailyReport = '/daily-report';
  static const habits = '/habits';
  static const projects = '/projekte';
  static const learning = '/lernen';
  static const sport = '/sport';
  static const kitchen = '/kueche';
  static const shoppingList = '/kueche/einkauf';
  static const notes = '/notizen';
  static const settings = '/einstellungen';
  static const devices = '/einstellungen/geraete';

  static String note(String id) => '$notes/$id';
  static String project(String id) => '$projects/$id';
  static String projectNote(String projectId, String noteId) => '$projects/$projectId/notiz/$noteId';
}

const _destinations = [
  ShellDestination(
    label: 'Übersicht',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  ShellDestination(
    label: 'Kalender',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
  ShellDestination(
    label: 'Aufgaben',
    icon: Icons.check_box_outlined,
    selectedIcon: Icons.check_box,
  ),
  ShellDestination(
    label: 'Finanzen',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  ShellDestination(
    label: 'Daily Report',
    icon: Icons.edit_note,
    selectedIcon: Icons.edit_note,
  ),
  ShellDestination(
    label: 'Habits',
    icon: Icons.repeat,
    selectedIcon: Icons.repeat_on,
  ),
  ShellDestination(
    label: 'Projekte',
    icon: Icons.work_outline,
    selectedIcon: Icons.work,
  ),
  ShellDestination(
    label: 'Lernen',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  ShellDestination(
    label: 'Sport',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
  ),
  ShellDestination(
    label: 'Küche',
    icon: Icons.restaurant_menu,
    selectedIcon: Icons.restaurant,
  ),
  ShellDestination(
    label: 'Notizen',
    icon: Icons.sticky_note_2_outlined,
    selectedIcon: Icons.sticky_note_2,
  ),
  ShellDestination(
    label: 'Einstellungen',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

GoRouter buildRouter(AppLockController lock) {
  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: lock,
    redirect: (context, state) => _redirect(lock.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.setup,
        builder: (context, state) => const PinSetupPage(),
      ),
      GoRoute(
        path: Routes.lock,
        builder: (context, state) =>
            LockPage(onForgotPin: () => context.go(Routes.recover)),
      ),
      GoRoute(
        path: Routes.recover,
        builder: (context, state) =>
            RecoveryPage(onCancel: () => context.go(Routes.lock)),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AdaptiveShell(
          destinations: _destinations,
          selectedIndex: navigationShell.currentIndex,
          onSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          body: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const CalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (context, state) => const TasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.finance,
                builder: (context, state) => const FinancePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dailyReport,
                builder: (context, state) => const DailyReportPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.habits,
                builder: (context, state) => const HabitsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.projects,
                builder: (context, state) => ProjectsPage(
                  onOpenProject: (id) => context.go(Routes.project(id)),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ProjectDetailPage(
                        projectId: id,
                        onOpenNote: (noteId) => context.go(Routes.projectNote(id, noteId)),
                        onClose: () => context.go(Routes.projects),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'notiz/:noteId',
                        builder: (context, state) => NoteEditorPage(
                          noteId: state.pathParameters['noteId']!,
                          onClose: () => context.go(Routes.project(state.pathParameters['id']!)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.learning,
                builder: (context, state) => const LearningPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.sport,
                builder: (context, state) => const SportPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.kitchen,
                builder: (context, state) => const KitchenPage(),
                routes: [
                  GoRoute(
                    path: 'einkauf',
                    builder: (context, state) => const KitchenPage(initialTab: 1),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notes,
                builder: (context, state) => NotesPage(
                  onOpenNote: (id) => context.go(Routes.note(id)),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => NoteEditorPage(
                      noteId: state.pathParameters['id']!,
                      onClose: () => context.go(Routes.notes),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'geraete',
                    builder: (context, state) => const DevicesPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String? _redirect(AppLockState state, String location) {
  const authRoutes = {Routes.setup, Routes.lock, Routes.recover};
  return switch (state) {
    AppLockState.loading => null,
    AppLockState.needsSetup => location == Routes.setup ? null : Routes.setup,
    AppLockState.locked =>
      location == Routes.lock || location == Routes.recover ? null : Routes.lock,
    AppLockState.unlocked => authRoutes.contains(location) ? Routes.dashboard : null,
  };
}
