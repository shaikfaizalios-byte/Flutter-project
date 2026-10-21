import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/generated/app_localizations.dart';
import '../features/exams/presentation/exam_switcher.dart';
import 'app_destinations.dart';
import 'routes.dart';
import 'theme/app_spacing.dart';

/// Top-level navigation, by window size: a bottom bar on phones and a labelled rail with larger
/// icons on tablets. On desktop the tabs live in the [AppSidebar] of [DesktopFrame].
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
    final tabs = tabDestinations(l10n);
    final form = FormFactor.ofWidth(MediaQuery.sizeOf(context).width);
    final iconSize = form.navIconSize;

    switch (form) {
      case FormFactor.desktop:
        // The sidebar sits around the whole app (DesktopFrame), so feature screens keep it.
        return navigationShell;
      case FormFactor.tablet:
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onSelect,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.85,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: BrandMark(),
                ),
                destinations: [
                  for (final d in tabs)
                    NavigationRailDestination(
                      icon: Icon(d.icon, size: iconSize),
                      selectedIcon: Icon(d.selectedIcon, size: iconSize),
                      label: Text(d.label),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        );
      case FormFactor.phone:
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelect,
              destinations: [
                for (final d in tabs)
                  NavigationDestination(
                    icon: Icon(d.icon, size: iconSize),
                    selectedIcon: Icon(d.selectedIcon, size: iconSize),
                    label: d.label,
                  ),
              ],
            ),
          ),
        );
    }
  }
}

/// PrepLoop's mark: the study loop as an infinity sign on the brand colour.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(Icons.all_inclusive, color: colors.onPrimary, size: size * 0.6),
      ),
    );
  }
}

/// Desktop sidebar: the product's name, the five tabs, then every feature screen by name.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.tabs,
    required this.features,
    required this.selectedTab,
    required this.location,
    required this.onSelectTab,
    required this.onSelectFeature,
    this.header,
  });

  /// Shown under the product name (the exam switcher).
  final Widget? header;

  final List<AppDestination> tabs;
  final List<AppDestination> features;
  final int selectedTab;
  final String location;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<AppDestination> onSelectFeature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final iconSize = FormFactor.desktop.navIconSize;
    // A feature screen is "current" when the path is inside it; its tab then stays unmarked.
    final currentFeature = features
        .where((f) => location == f.route || location.startsWith('${f.route}/'))
        .firstOrNull;

    return SizedBox(
      width: AppSpacing.sidebarWidth,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    const BrandMark(size: 36),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Flexible(
                      child: Text(
                        l10n.appTitle,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              if (header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                    AppSpacing.md,
                  ),
                  child: header,
                ),
              for (final (i, d) in tabs.indexed)
                _SidebarItem(
                  destination: d,
                  iconSize: iconSize,
                  selected: currentFeature == null && i == selectedTab,
                  onTap: () => onSelectTab(i),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 4,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.navFeaturesTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              for (final d in features)
                _SidebarItem(
                  destination: d,
                  iconSize: iconSize,
                  selected: d == currentFeature,
                  onTap: () => onSelectFeature(d),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.iconSize,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final double iconSize;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            hoverColor: colors.onSurface.withValues(alpha: 0.05),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.sm + 4),
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: iconSize,
                    color: selected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      destination.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? colors.onSecondaryContainer : colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop web: the sidebar stays beside every signed-in screen, including feature screens
/// that open above the tabs. Hidden on sign-in, onboarding, legal pages and practice sessions
/// (a running test keeps the whole window).
class DesktopFrame extends StatefulWidget {
  const DesktopFrame({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<DesktopFrame> createState() => _DesktopFrameState();
}

class _DesktopFrameState extends State<DesktopFrame> {
  static const _hiddenOn = [
    AppRoutes.signIn,
    AppRoutes.forgotPassword,
    AppRoutes.onboarding,
    '/legal/',
    '/practice/sessions/',
  ];

  String _location = '';

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    _location = _current();
  }

  @override
  void didUpdateWidget(DesktopFrame old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_onRoute);
      widget.router.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  String _current() => widget.router.routerDelegate.currentConfiguration.uri.path;

  // The router can announce a change while the tree is building (redirects): rebuild after it.
  void _onRoute() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
    } else {
      _sync();
    }
  }

  void _sync() {
    if (!mounted) return;
    final location = _current();
    if (location != _location) setState(() => _location = location);
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final desktop = FormFactor.ofWidth(MediaQuery.sizeOf(context).width) == FormFactor.desktop;
    final show = desktop && location.isNotEmpty && !_hiddenOn.any(location.startsWith);
    final l10n = AppLocalizations.of(context);
    final tabs = tabDestinations(l10n);
    bool inside(String route) => location == route || location.startsWith('$route/');
    // The app (child) keeps one place in the tree whether or not the sidebar shows, so the
    // router's state survives resizing the window.
    return Row(
      children: [
        if (show) ...[
          AppSidebar(
            tabs: tabs,
            features: featureShortcuts(l10n),
            selectedTab: tabs.indexWhere((t) => inside(t.route)),
            location: location,
            onSelectTab: (i) => widget.router.go(tabs[i].route),
            onSelectFeature: (d) {
              if (location != d.route) widget.router.push(d.route);
            },
            header: ExamSwitcher(
              expanded: true,
              sheetContext: () => widget.router.routerDelegate.navigatorKey.currentContext,
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          key: const ValueKey('app'),
          // Beside the sidebar each page is one centred column, so its title and its content
          // share a left edge (pages cap their content at maxContentWidth).
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: show ? AppSpacing.maxContentWidth : double.infinity,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
