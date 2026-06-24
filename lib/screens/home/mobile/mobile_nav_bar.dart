// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class MobileNavBar extends StatelessWidget {
  final String location;
  final double bottomPadding;
  final double expansion;

  const MobileNavBar({
    super.key,
    required this.location,
    required this.bottomPadding,
    required this.expansion,
  });

  @override
  Widget build(BuildContext context) {
    const navBarHeight = 56.0;
    final mobileNavBarHeight = navBarHeight + bottomPadding;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Transform.translate(
        offset: Offset(0, expansion * mobileNavBarHeight),
        child: Opacity(
          opacity: (1 - expansion * 2).clamp(0.0, 1.0),
          child: expansion > 0.8
              ? const SizedBox.shrink()
              : ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: mobileNavBarHeight,
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(context, FontAwesomeIcons.solidHouse, 'Home', '/', 0),
                          _buildNavItem(context, FontAwesomeIcons.youtube, 'YouTube', '/youtube', 1),
                          _buildNavItem(context, FontAwesomeIcons.recordVinyl, 'Library', '/library', 2),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  int _getSelectedIndex(String loc) {
    if (loc == '/') return 0;
    if (loc.startsWith('/library')) return 2;
    if (loc.startsWith('/explorer')) return 2;
    if (loc.startsWith('/playlist')) return 2;
    return -1;
  }

  Widget _buildNavItem(BuildContext context, FaIconData icon, String label, String? route, int index) {
    final isSelected = _getSelectedIndex(location) == index;
    final unselectedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: route != null ? () => context.go(route) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: FaIcon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.surface
                    : unselectedColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.secondary : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
