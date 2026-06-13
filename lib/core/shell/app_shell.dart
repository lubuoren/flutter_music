import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/player_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isWide) _SideNavigation(navigationShell: navigationShell),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: navigationShell),
                  if (isWide) const PlayerBar(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PlayerBar(),
                _MobileBottomNavigation(navigationShell: navigationShell),
              ],
            ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(label: '首页', icon: Icons.home_rounded, path: '/'),
      _NavItem(label: '探索', icon: Icons.explore_rounded, path: '/explore'),
      _NavItem(
        label: '音乐库',
        icon: Icons.library_music_rounded,
        path: '/library',
      ),
      _NavItem(
        label: '本地音乐',
        icon: Icons.audio_file_rounded,
        path: '/localMusic',
      ),
      _NavItem(label: '设置', icon: Icons.settings_rounded, path: '/settings'),
    ];

    return NavigationRail(
      extended: true,
      destinations: items
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            ),
          )
          .toList(),
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) {
        navigationShell.goBranch(index);
      },
    );
  }
}

class _MobileBottomNavigation extends StatelessWidget {
  const _MobileBottomNavigation({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: '首页'),
        NavigationDestination(icon: Icon(Icons.explore_rounded), label: '探索'),
        NavigationDestination(
          icon: Icon(Icons.library_music_rounded),
          label: '音乐库',
        ),
        NavigationDestination(
          icon: Icon(Icons.audio_file_rounded),
          label: '本地',
        ),
        NavigationDestination(icon: Icon(Icons.settings_rounded), label: '设置'),
      ],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) {
        navigationShell.goBranch(index);
      },
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.path});

  final String label;
  final IconData icon;
  final String path;
}
