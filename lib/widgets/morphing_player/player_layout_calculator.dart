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

import 'package:flutter/widgets.dart';

import 'player_layout_spec.dart';

/// Pure layout math for the morphing player. Centralizes the formula
/// previously inlined in `_MorphingPlayerState.build()` / `_calculateExpandedLayout`.
class PlayerLayoutCalculator {
  const PlayerLayoutCalculator._();

  /// Target rects for the fully expanded player. Mirrors the legacy
  /// `_calculateExpandedLayout` exactly.
  ///
  /// [useFullWidth] is the legacy flag: true when content width is clamped
  /// to `maxArtSize` (mobile or compact). False for full desktop layout.
  static ExpandedPlayerSpec calculateExpandedLayout({
    required double playerWidth,
    required double screenHeight,
    required double topPadding,
    required double bottomPadding,
    required bool useFullWidth,
  }) {
    final infoHeight = ExpandedLayoutConstants.infoHeight;
    final seekbarHeight = ExpandedLayoutConstants.seekbarHeight;
    final controlsHeight = ExpandedLayoutConstants.controlsHeight;
    final actionsHeight = ExpandedLayoutConstants.actionsHeight;
    const gapCount = ExpandedLayoutConstants.gapCount;

    final bottomStart = screenHeight - bottomPadding;
    final actionsTop = bottomStart - actionsHeight;
    final actionsRect = Rect.fromLTWH(0, actionsTop, playerWidth, actionsHeight);

    const maxArtSize = 600.0;
    const sidePadding = 32.0;
    final availableWidth = playerWidth - (sidePadding * 2);

    const topReserved = 60.0;
    final topStart = topPadding + topReserved;

    final middleHeight = infoHeight + seekbarHeight + controlsHeight;
    const totalGapsForReserve = 8.0 * 5;
    final maxArtHeight = (actionsTop - topStart - middleHeight - totalGapsForReserve)
        .clamp(0.0, maxArtSize);

    final artSize = availableWidth.clamp(0.0, maxArtHeight);
    final contentWidth = useFullWidth
        ? availableWidth
        : availableWidth.clamp(0.0, maxArtSize);
    final contentLeft = (playerWidth - contentWidth) / 2;
    final artTop = topPadding + topReserved;
    final artRect = Rect.fromLTWH(
      (playerWidth - artSize) / 2,
      artTop,
      artSize,
      artSize,
    );

    final chainHeight = middleHeight;
    final chainTop = artRect.bottom + 8.0;
    final chainBottom = actionsRect.top - 8.0;
    final chainSpace = chainBottom - chainTop;
    final remainingSpace = chainSpace - chainHeight;
    final equalGap = (remainingSpace / gapCount).clamp(8.0, double.infinity);

    final infoTop = chainTop + equalGap;
    final infoRect = Rect.fromLTWH(
      contentLeft,
      infoTop,
      contentWidth,
      infoHeight,
    );
    final seekbarTop = infoRect.bottom + equalGap;
    final seekbarRect = Rect.fromLTWH(
      contentLeft,
      seekbarTop,
      contentWidth,
      seekbarHeight,
    );
    final controlsTop = seekbarRect.bottom + equalGap;
    final controlsRect = Rect.fromLTWH(
      0,
      controlsTop,
      playerWidth,
      controlsHeight,
    );

    return ExpandedPlayerSpec(
      art: artRect,
      info: infoRect,
      seekbar: seekbarRect,
      controls: controlsRect,
      actions: actionsRect,
    );
  }

  /// Per-frame layout values for the mini (collapsed) bar.
  static BarLayout computeBarLayout({
    required double screenWidth,
    required double leftOffset,
    required bool isCompact,
    required PlayerBarSpec spec,
  }) {
    final availableWidth = screenWidth - leftOffset;
    final collapsedWidth = (availableWidth - (spec.outerMargin * 2)).clamp(
      0.0,
      900.0,
    );
    final collapsedLeft = isCompact
        ? leftOffset + spec.outerMargin
        : leftOffset + (availableWidth - collapsedWidth) / 2;

    final artLeft = spec.artLeft;
    final artTop = spec.miniArtTop;
    final artSize = spec.miniArtSize;

    final textLeft = artLeft + artSize + spec.artSpacing;
    final textTop = 13.0;
    final textHeight = 50.0;
    final textWidth = (collapsedWidth - textLeft - spec.rightControlsBuffer)
        .clamp(10.0, 1200.0);

    // Controls
    double controlsLeft;
    double controlsWidth;
    if (isCompact) {
      const miniButtonsCount = 3; // previous, play_pause, next
      controlsWidth =
          (miniButtonsCount * 48.0 + (miniButtonsCount - 1) * 2.0).clamp(
                48.0,
                200.0,
              );
      controlsLeft = collapsedWidth - controlsWidth;
    } else {
      controlsLeft = 0;
      controlsWidth = spec.leftControlsWidth;
    }

    return BarLayout(
      collapsedWidth: collapsedWidth,
      collapsedLeft: collapsedLeft,
      artLeft: artLeft,
      artTop: artTop,
      artSize: artSize,
      textLeft: textLeft,
      textTop: textTop,
      textHeight: textHeight,
      textWidth: textWidth,
      controlsLeft: controlsLeft,
      controlsTop: spec.controlsTop,
      controlsWidth: controlsWidth,
      controlsHeight: spec.barHeight,
      actionsLeft: 0, // overwritten below; placeholder
      actionsTop: spec.actionsTop,
      actionsWidth: 0, // overwritten below
      actionsHeight: spec.actionsHeight,
    );
  }

  /// Computes the actions row geometry separately because the width depends
  /// on the configured action list (a signal). Returns a new `BarLayout` with
  /// the actions fields filled in.
  static BarLayout withActions({
    required BarLayout base,
    required double collapsedWidth,
    required bool isCompact,
    required int actionsCount,
    required PlayerBarSpec spec,
  }) {
    final maxActionsWidth = isCompact ? (collapsedWidth * 0.45) : 600.0;
    final actionsWidth = (actionsCount * 48.0 + (actionsCount - 1) * 12.0)
        .clamp(0.0, maxActionsWidth);
    final actionsLeft = collapsedWidth - spec.actionsRight - actionsWidth;
    return BarLayout(
      collapsedWidth: base.collapsedWidth,
      collapsedLeft: base.collapsedLeft,
      artLeft: base.artLeft,
      artTop: base.artTop,
      artSize: base.artSize,
      textLeft: base.textLeft,
      textTop: base.textTop,
      textHeight: base.textHeight,
      textWidth: base.textWidth,
      controlsLeft: base.controlsLeft,
      controlsTop: base.controlsTop,
      controlsWidth: base.controlsWidth,
      controlsHeight: base.controlsHeight,
      actionsLeft: actionsLeft,
      actionsTop: spec.actionsTop,
      actionsWidth: actionsWidth,
      actionsHeight: spec.actionsHeight,
    );
  }

  /// Lyrics-header target rect. Mirrors the inline `targetLyricsArt*` /
  /// `targetLyricsInfoRect` math in the legacy build.
  static LyricsLayout computeLyricsLayout({
    required ExpandedPlayerSpec expandedSpec,
  }) {
    final targetLyricsArtLeft = expandedSpec.info.left;
    final targetLyricsArtTop = expandedSpec.art.top;
    const targetLyricsArtSize = 56.0;
    final targetLyricsInfoLeft =
        targetLyricsArtLeft + targetLyricsArtSize + 16.0;
    final targetLyricsInfoRect = Rect.fromLTWH(
      targetLyricsInfoLeft,
      targetLyricsArtTop,
      expandedSpec.info.right - targetLyricsInfoLeft,
      targetLyricsArtSize,
    );
    final artRect = Rect.fromLTWH(
      targetLyricsArtLeft,
      targetLyricsArtTop,
      targetLyricsArtSize,
      targetLyricsArtSize,
    );
    return LyricsLayout(
      artRect: artRect,
      infoRect: targetLyricsInfoRect,
    );
  }
}
