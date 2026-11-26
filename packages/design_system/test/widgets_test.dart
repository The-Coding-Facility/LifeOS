import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(theme: buildLifeosTheme(Brightness.light), home: child);
  }

  testWidgets('SyncStatusChip zeigt den Zustand als Text', (tester) async {
    await tester.pumpWidget(host(const Scaffold(
      body: Column(children: [
        SyncStatusChip(status: SyncStatus.localOnly),
        SyncStatusChip(status: SyncStatus.offline, pendingChanges: 3),
      ]),
    )));
    expect(find.text('Nur lokal'), findsOneWidget);
    expect(find.text('Offline-Modus · 3 ausstehend'), findsOneWidget);
  });

  const destinations = [
    ShellDestination(label: 'Übersicht', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
    ShellDestination(label: 'Aufgaben', icon: Icons.check_box_outlined, selectedIcon: Icons.check_box),
  ];

  testWidgets('AdaptiveShell nutzt auf schmalen Fenstern die Tab-Leiste', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(AdaptiveShell(
      destinations: destinations,
      selectedIndex: 0,
      onSelected: (_) {},
      body: const SizedBox(),
    )));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('AdaptiveShell nutzt auf breiten Fenstern die Seitenleiste', (tester) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(AdaptiveShell(
      destinations: destinations,
      selectedIndex: 1,
      onSelected: (_) {},
      body: const SizedBox(),
    )));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
