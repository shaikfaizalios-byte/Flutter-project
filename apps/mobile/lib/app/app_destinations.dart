import 'package:flutter/material.dart';

import '../core/localization/generated/app_localizations.dart';
import 'routes.dart';

/// A place in the app reachable from navigation: a tab, or a feature screen inside a tab.
class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}

/// The five tabs, in branch order (see router.dart).
List<AppDestination> tabDestinations(AppLocalizations l10n) => [
  AppDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: l10n.navHome,
    route: AppRoutes.home,
  ),
  AppDestination(
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    label: l10n.navStudy,
    route: AppRoutes.study,
  ),
  AppDestination(
    icon: Icons.quiz_outlined,
    selectedIcon: Icons.quiz,
    label: l10n.navPractice,
    route: AppRoutes.practice,
  ),
  AppDestination(
    icon: Icons.show_chart_outlined,
    selectedIcon: Icons.show_chart,
    label: l10n.navProgress,
    route: AppRoutes.progress,
  ),
  AppDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: l10n.navProfile,
    route: AppRoutes.profile,
  ),
];

/// Feature screens that otherwise sit one level inside a tab. Listed by name in the desktop
/// sidebar and on Home, so nothing has to be found behind an unlabelled icon.
List<AppDestination> featureShortcuts(AppLocalizations l10n) => [
  AppDestination(
    icon: Icons.picture_as_pdf_outlined,
    selectedIcon: Icons.picture_as_pdf,
    label: l10n.documentsTitle,
    route: AppRoutes.documents,
  ),
  AppDestination(
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: l10n.bankTitle,
    route: AppRoutes.questionBank,
  ),
  AppDestination(
    icon: Icons.repeat,
    selectedIcon: Icons.repeat_on,
    label: l10n.repeatsTitle,
    route: AppRoutes.repeats,
  ),
  AppDestination(
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    label: l10n.revisionTitle,
    route: AppRoutes.revision,
  ),
  AppDestination(
    icon: Icons.bookmark_outline,
    selectedIcon: Icons.bookmark,
    label: l10n.bookmarksTitle,
    route: AppRoutes.bookmarks,
  ),
  AppDestination(
    icon: Icons.flag_outlined,
    selectedIcon: Icons.flag,
    label: l10n.examsTitle,
    route: AppRoutes.myExams,
  ),
  AppDestination(
    icon: Icons.workspace_premium_outlined,
    selectedIcon: Icons.workspace_premium,
    label: l10n.plusTitle,
    route: AppRoutes.plus,
  ),
  AppDestination(
    icon: Icons.lightbulb_outline,
    selectedIcon: Icons.lightbulb,
    label: l10n.suggestionsTitle,
    route: AppRoutes.suggestions,
  ),
];
