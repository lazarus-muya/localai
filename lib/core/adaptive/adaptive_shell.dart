import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_palette.dart';
import 'breakpoints.dart';

class _NavDestination {
  const _NavDestination({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavGroup {
  const _NavGroup({this.label, required this.destinations});

  final String? label;
  final List<_NavDestination> destinations;
}

const _groups = [
  _NavGroup(
    label: 'Workspace',
    destinations: [
      _NavDestination(
        index: 0,
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: 'Chat',
      ),
      _NavDestination(
        index: 1,
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
        label: 'History',
      ),
    ],
  ),
  _NavGroup(
    label: 'Local Models',
    destinations: [
      _NavDestination(
        index: 2,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Models',
      ),
    ],
  ),
  _NavGroup(
    label: 'App',
    destinations: [
      _NavDestination(
        index: 3,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
      ),
    ],
  ),
];

final _destinations = [for (final g in _groups) ...g.destinations];

/// Hand-rolled adaptive navigation shell: a grouped sidebar (styled after
/// LM Studio's settings nav — small-caps section labels, pill-selected
/// rows) on wide (desktop/tablet) layouts, a bottom [NavigationBar] on
/// narrow (phone) layouts. No adaptive-scaffold package is used since the
/// common one (flutter_adaptive_scaffold) was discontinued upstream.
///
/// Branches are driven by [StatefulShellRoute.indexedStack], which keeps
/// each destination alive in an [IndexedStack] and switches between them
/// with a plain visibility swap instead of a push/pop page transition —
/// the same "instant tab switch" feel native bottom-nav and sidebar apps
/// use, rather than the Material zoom/scale animation a pushed route gets.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _Sidebar(selectedIndex: navigationShell.currentIndex, onSelect: _onSelect),
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
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: palette.sidebarBackground,
        border: Border(right: BorderSide(color: palette.sidebarBorder)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.bolt, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LocalAi',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final group in _groups)
                    _SidebarGroup(group: group, selectedIndex: selectedIndex, onSelect: onSelect),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroup extends StatelessWidget {
  const _SidebarGroup({required this.group, required this.selectedIndex, required this.onSelect});

  final _NavGroup group;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Text(
                group.label!.toUpperCase(),
                style: TextStyle(
                  color: palette.groupLabel,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          for (final d in group.destinations)
            _SidebarItem(
              destination: d,
              selected: selectedIndex == d.index,
              onTap: () => onSelect(d.index),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.destination, required this.selected, required this.onTap});

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 19,
                  color: selected ? palette.onAccent : palette.mutedText,
                ),
                const SizedBox(width: 10),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected ? palette.onAccent : palette.textPrimary,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
