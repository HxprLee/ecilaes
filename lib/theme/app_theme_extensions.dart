import 'package:flutter/material.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color songCardBackground;
  final Color playerBarBackground;
  final Color sidebarBackground;
  final Color headerBarBackground;

  const AppThemeExtension({
    required this.songCardBackground,
    required this.playerBarBackground,
    required this.sidebarBackground,
    required this.headerBarBackground,
  });

  @override
  AppThemeExtension copyWith({
    Color? songCardBackground,
    Color? playerBarBackground,
    Color? sidebarBackground,
    Color? headerBarBackground,
  }) {
    return AppThemeExtension(
      songCardBackground: songCardBackground ?? this.songCardBackground,
      playerBarBackground: playerBarBackground ?? this.playerBarBackground,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      headerBarBackground: headerBarBackground ?? this.headerBarBackground,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      songCardBackground: Color.lerp(
        songCardBackground,
        other.songCardBackground,
        t,
      )!,
      playerBarBackground: Color.lerp(
        playerBarBackground,
        other.playerBarBackground,
        t,
      )!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      headerBarBackground: Color.lerp(
        headerBarBackground,
        other.headerBarBackground,
        t,
      )!,
    );
  }

  // Pre-configured instances
  static const lightExtension = AppThemeExtension(
    songCardBackground: Color(0xFFF0F0F0), // A light grey for cards
    playerBarBackground: Color(0xFFE0E0E0), // Slightly darker for player bar
    sidebarBackground: Color(0xFFF5F5F5), // Very light grey for sidebar
    headerBarBackground: Color(0xFFFAFAFA), // Almost white for header
  );

  static const darkExtension = AppThemeExtension(
    songCardBackground: Color(0xFF1E222B), // The original dark hex colors
    playerBarBackground: Color(0xFF11171C), // Deep black-blue playbar
    sidebarBackground: Color(0xFF1A1F24), // Sidebar specific background
    headerBarBackground: Color(0xFF1A1F24), // Header specific background
  );
}
