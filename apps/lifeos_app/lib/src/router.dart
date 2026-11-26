import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_security/lifeos_security.dart';
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
  static const tasks = '/aufgaben';
  static const notes = '/notizen';
  static const settings = '/einstellungen';
  static const devices = '/einstellungen/geraete';

  static String note(String id) => '$notes/$id';
}

const _destinations = [
  ShellDestination(
    label: 'Übersicht',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  ShellDestination(
    label: 'Aufgaben',
    icon: Icons.check_box_outlined,
    selectedIcon: Icons.check_box,
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
                path: Routes.tasks,
                builder: (context, state) => const TasksPage(),
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

String? _redirect(LockState state, String location) {
  const authRoutes = {Routes.setup, Routes.lock, Routes.recover};
  return switch (state) {
    LockState.loading => null,
    LockState.needsSetup => location == Routes.setup ? null : Routes.setup,
    LockState.locked =>
      location == Routes.lock || location == Routes.recover ? null : Routes.lock,
    LockState.unlocked => authRoutes.contains(location) ? Routes.dashboard : null,
  };
}
