import 'package:flutter/material.dart';

/// Ein Eintrag der Hauptnavigation.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Hauptgerüst der App.
///
/// Breite Fenster (Windows, Tablet quer): Seitenleiste links mit allen
/// Bereichen. Schmale Fenster (Handy): Tab-Leiste unten mit den ersten
/// [compactMax] Bereichen und „Mehr“ für den Rest.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.compactMax = 4,
  });

  /// So viele Bereiche zeigt die Tab-Leiste direkt.
  final int compactMax;

  /// Ab dieser Breite erscheint die Seitenleiste.
  static const double railBreakpoint = 840;

  /// Ab dieser Breite zeigt die Seitenleiste ausgeschriebene Namen.
  static const double extendedBreakpoint = 1200;

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= railBreakpoint) {
          final extended = constraints.maxWidth >= extendedBreakpoint;
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: extended,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'LifeOS',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    destinations: [
                      for (final destination in destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: _CompactBar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
            compactMax: compactMax,
          ),
        );
      },
    );
  }
}

class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.compactMax,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int compactMax;

  bool get _needsMore => destinations.length > compactMax + 1;

  @override
  Widget build(BuildContext context) {
    final direct = _needsMore ? destinations.take(compactMax).toList() : destinations;
    final moreIndex = direct.length;
    final barIndex = selectedIndex < direct.length ? selectedIndex : moreIndex;
    return NavigationBar(
      selectedIndex: barIndex,
      onDestinationSelected: (index) {
        if (index < direct.length) {
          onSelected(index);
        } else {
          _showMore(context);
        }
      },
      destinations: [
        for (final destination in direct)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
        if (_needsMore)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Mehr',
          ),
      ],
    );
  }

  Future<void> _showMore(BuildContext context) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var index = compactMax; index < destinations.length; index++)
              ListTile(
                leading: Icon(
                  index == selectedIndex
                      ? destinations[index].selectedIcon
                      : destinations[index].icon,
                ),
                title: Text(destinations[index].label),
                selected: index == selectedIndex,
                onTap: () => Navigator.of(context).pop(index),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onSelected(chosen);
  }
}
