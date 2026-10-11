import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/generated/app_localizations.dart';
import 'theme/app_spacing.dart';

/// Top-level navigation: bottom bar on phones, navigation rail on wide screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab returns to that tab's first page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.menu_book_outlined, Icons.menu_book, l10n.navStudy),
      (Icons.quiz_outlined, Icons.quiz, l10n.navPractice),
      (Icons.show_chart_outlined, Icons.show_chart, l10n.navProgress),
      (Icons.person_outline, Icons.person, l10n.navProfile),
    ];

    final wide = MediaQuery.sizeOf(context).width >= AppSpacing.railBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selectedIcon, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selectedIcon),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onSelect,
        destinations: [
          for (final (icon, selectedIcon, label) in destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selectedIcon), label: label),
        ],
      ),
    );
  }
}
