// Ecilaes - Cross-platform music player
// Copyright (C) 2024  Anton Borri
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

import 'package:flutter/material.dart';

/// Constants for the expanded player's vertical chain.
class ExpandedLayoutConstants {
  const ExpandedLayoutConstants._();

  static const double infoHeight = 70.0;
  static const double seekbarHeight = 70.0;
  static const double controlsHeight = 80.0;
  static const double actionsHeight = 88.0;

  /// 4 gaps between the 5 vertical sections (art, info, seekbar, controls, actions).
  static const int gapCount = 4;
}

/// Dimensions and styles for the mini bar.
///
/// `PlayerBarSpec.compact` is used whenever `isCompact` is true, regardless of
/// platform — compact layout is now identical on desktop and mobile.
@immutable
class PlayerBarSpec {
  final double barHeight;
  final double miniArtSize;
  final double miniArtTop;

  /// Outer left/right margin from screen edge (used for `collapsedWidth` /
  /// `collapsedLeft`). Historically 18 (compact) / 24 (full).
  final double outerMargin;

  /// Inner left padding for the album art in the mini bar. Historically 15
  /// (compact mobile) / 16 (compact desktop) / 186 (full). Compact on desktop
  /// now uses the same value as compact on mobile.
  final double artLeft;

  /// Horizontal gap between the album art and the song-info text in the mini
  /// bar.
  final double artSpacing;

  /// Width of the left-side playback-controls block in the full layout.
  final double leftControlsWidth;

  /// Right buffer reserved for the playback controls in the mini bar.
  final double rightControlsBuffer;

  // Controls row vertical offset inside the 80-px bar.
  final double controlsTop;

  // Actions row.
  final double actionsRight;
  final double actionsTop;
  final double actionsHeight;
  final double actionsIconSize;
  final double actionsSpacing;
  final double actionsBadgeOpacityStart; // value threshold for badge fade-in

  // Text styles.
  final TextStyle titleMini;
  final TextStyle titleExpanded;
  final TextStyle artistMini;
  final TextStyle artistExpanded;
  final TextStyle lyricsTitle;
  final TextStyle lyricsArtist;

  const PlayerBarSpec({
    required this.barHeight,
    required this.miniArtSize,
    required this.miniArtTop,
    required this.outerMargin,
    required this.artLeft,
    required this.artSpacing,
    required this.leftControlsWidth,
    required this.rightControlsBuffer,
    required this.controlsTop,
    required this.actionsRight,
    required this.actionsTop,
    required this.actionsHeight,
    required this.actionsIconSize,
    required this.actionsSpacing,
    required this.actionsBadgeOpacityStart,
    required this.titleMini,
    required this.titleExpanded,
    required this.artistMini,
    required this.artistExpanded,
    required this.lyricsTitle,
    required this.lyricsArtist,
  });

  /// Compact layout. Used for `screenWidth < 600` or `availableBarWidth < 700`.
  /// Identical across desktop and mobile.
  static const compact = PlayerBarSpec(
    barHeight: 80.0,
    miniArtSize: 50.0,
    miniArtTop: 13.0, // (80 - 50) / 2
    outerMargin: 18.0, // was _compactMargin
    artLeft: 15.0, // was _compactPadding (mobile default)
    artSpacing: 16.0, // gap to text in mini bar
    leftControlsWidth: 0.0, // unused in compact
    rightControlsBuffer: 130.0,
    controlsTop: 0.0, // was _startTop - 1 on mobile; collapsed to 0 for compact
    actionsRight: 16.0,
    actionsTop: 15.0,
    actionsHeight: 48.0,
    actionsIconSize: 24.0,
    actionsSpacing: 12.0,
    actionsBadgeOpacityStart: 0.5,
    titleMini: TextStyle(
      color: Color(0xFF000000), // overridden in build from theme
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 1.2,
    ),
    titleExpanded: TextStyle(
      color: Color(0xFF000000),
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    artistMini: TextStyle(color: Color(0xFF000000), fontSize: 12, height: 1.2),
    artistExpanded: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.4,
    ),
    lyricsTitle: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.bold,
      fontSize: 20,
      height: 1.3,
    ),
    lyricsArtist: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.3,
    ),
  );

  /// Full (desktop) layout.
  static const full = PlayerBarSpec(
    barHeight: 80.0,
    miniArtSize: 50.0,
    miniArtTop: 13.0,
    outerMargin: 24.0, // was _fullMargin
    artLeft:
        186.0, // was _fullPadding + _leftControlsWidth + _artSpacing = 16 + 180 + (-10)
    artSpacing: -10.0, // was _artSpacing
    leftControlsWidth: 180.0,
    rightControlsBuffer: 300.0,
    controlsTop: -1.0, // was _startTop - 1 on desktop
    actionsRight: 16.0,
    actionsTop: 15.0,
    actionsHeight: 48.0,
    actionsIconSize: 24.0,
    actionsSpacing: 12.0,
    actionsBadgeOpacityStart: 0.5,
    titleMini: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 1.2,
    ),
    titleExpanded: TextStyle(
      color: Color(0xFF000000),
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    artistMini: TextStyle(color: Color(0xFF000000), fontSize: 12, height: 1.2),
    artistExpanded: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.4,
    ),
    lyricsTitle: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.bold,
      fontSize: 20,
      height: 1.3,
    ),
    lyricsArtist: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.3,
    ),
  );
}

/// Target rects for the expanded player — the morph destinations.
@immutable
class ExpandedPlayerSpec {
  final Rect art;
  final Rect info;
  final Rect seekbar;
  final Rect controls;
  final Rect actions;

  const ExpandedPlayerSpec({
    required this.art,
    required this.info,
    required this.seekbar,
    required this.controls,
    required this.actions,
  });
}

/// Per-frame layout values for the mini (collapsed) bar.
@immutable
class BarLayout {
  /// Width of the mini bar (clamped to 0..900).
  final double collapsedWidth;

  /// Left offset of the mini bar within the screen.
  final double collapsedLeft;

  final double artLeft;
  final double artTop; // == PlayerBarSpec.miniArtTop
  final double artSize; // == PlayerBarSpec.miniArtSize

  final double textLeft;
  final double textTop;
  final double textHeight;
  final double textWidth;

  final double controlsLeft;
  final double controlsTop;
  final double controlsWidth;
  final double controlsHeight;

  final double actionsLeft;
  final double actionsTop;
  final double actionsWidth;
  final double actionsHeight;

  const BarLayout({
    required this.collapsedWidth,
    required this.collapsedLeft,
    required this.artLeft,
    required this.artTop,
    required this.artSize,
    required this.textLeft,
    required this.textTop,
    required this.textHeight,
    required this.textWidth,
    required this.controlsLeft,
    required this.controlsTop,
    required this.controlsWidth,
    required this.controlsHeight,
    required this.actionsLeft,
    required this.actionsTop,
    required this.actionsWidth,
    required this.actionsHeight,
  });
}

/// Layout values for the lyrics-header target (when the player morphs into a
/// lyrics view).
@immutable
class LyricsLayout {
  final Rect artRect;
  final Rect infoRect;
  const LyricsLayout({required this.artRect, required this.infoRect});
}
