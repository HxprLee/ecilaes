import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../signals/settings_signal.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blur = settingsSignal.enableGlobalBlur.value;
    return ClipRRect(
      child: BackdropFilter(
        filter: blur
            ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          height: 80, // Standard height + padding
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(
              settingsSignal.enableGlobalBlur.value ? 0.85 : 1.0,
            ),
            border: const Border(
              top: BorderSide(
                color: Color.fromARGB(30, 255, 255, 255),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: FontAwesomeIcons.house,
                label: 'Home',
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: FontAwesomeIcons.youtube,
                label: 'YouTube',
              ),
              _buildNavItem(
                context,
                index: 2,
                icon: FontAwesomeIcons.recordVinyl,
                label: 'Library',
              ),
              _buildNavItem(
                context,
                index: 3,
                icon: FontAwesomeIcons.gear,
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    final iconColor = isSelected
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.secondary;
    final labelColor = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: FaIcon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
