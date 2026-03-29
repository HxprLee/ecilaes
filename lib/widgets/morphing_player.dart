import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../services/album_art_cache.dart';
import '../signals/audio_signal.dart';
import './playlist_dialogs.dart';
import './song_info_dialog.dart';
import '../signals/settings_signal.dart';
import '../services/YoutubeDatasource.dart';
import '../theme/app_theme_extensions.dart';
import 'package:marquee/marquee.dart';
import 'song_actions_sheet.dart';
import 'player/queue_view.dart';
import '../services/youtube_service.dart';
import 'mobile_lyrics_view.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

class MorphingPlayer extends StatefulWidget {
  final double bottomOffset;
  final double leftOffset;

  const MorphingPlayer({super.key, this.bottomOffset = 0, this.leftOffset = 0});

  @override
  State<MorphingPlayer> createState() => _MorphingPlayerState();
}

class _MorphingPlayerState extends State<MorphingPlayer>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _visibilityController;
  late AnimationController _lyricsController;
  File? _currentAlbumArt;
  String? _currentSongPath;
  String? _codecBitrate;
  bool _isSeeking = false;

  // Layout Configuration
  // Using getters to allow dynamic updates if needed, though mostly constant
  double get _barHeight => 80.0;
  double get _miniArtSize => 50.0;

  // Compact Layout Specs
  double get _compactMargin => 18.0;
  double get _compactPadding => 15.0;

  // Full Layout Specs
  double get _fullMargin => 24.0;
  double get _fullPadding => 16.0; // Reduced from 20.0
  double get _leftControlsWidth => 180.0; // Reduced slightly for tighter look
  double get _artSpacing => -10.0; // Comfortable spacing

  double get _startTop => 0.0; // Centered for full bar height (80px)

  double _dragStartValue = 0.0;
  double _dragDownOffset = 0.0;
  late AnimationController _dragResetController;

  // Cached Layout
  dynamic _cachedLayout;
  Size? _lastLayoutSize;
  EdgeInsets? _lastPadding;
  bool? _lastIsCompact;
  double? _lastLyricsValue;

  static final _bitrateCache = <String, String>{};

  Timer? _immersionTimer;
  bool _showControls = true;
  final List<void Function()> _effectDisposals = [];

  void _resetImmersionTimer() {
    _immersionTimer?.cancel();
    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }

    final lyrics = audioSignal.currentLyrics.value;
    final hasSyncedLyrics =
        lyrics != null && RegExp(r'\[\d{2}:\d{2}').hasMatch(lyrics);

    // Desktop layout (wide screens) doesn't auto-hide controls
    final isDesktopLayout = MediaQuery.of(context).size.width >= 900;

    if (audioSignal.showLyrics.value &&
        audioSignal.isPlaying.value &&
        hasSyncedLyrics &&
        !isDesktopLayout) {
      _immersionTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _handleSongChange(Song? song) async {
    if (song == null) {
      if (mounted) {
        setState(() {
          _currentSongPath = null;
          _currentAlbumArt = null;
          _codecBitrate = null;
        });
      }
      return;
    }

    if (song.path == _currentSongPath) return;
    _currentSongPath = song.path;

    // Load Art
    final art = await AlbumArtCache().getArt(song.path);

    // Load Metadata (async)
    String metadata;
    if (song.path.startsWith('yt:')) {
      final mime = youtubeService.lastStreamMimeType ?? 'audio/mp4';
      final codecLabel = mime.contains('mp4')
          ? 'M4A'
          : mime.contains('webm')
          ? 'WEBM'
          : mime.split('/').last.toUpperCase();
      final kbps = youtubeService.lastStreamBitrateKbps ?? '—';
      metadata = 'YT $codecLabel | ${kbps}Kbps';
    } else {
      final ext = song.path.split('.').last.toUpperCase();
      String? bitrate;
      if (_bitrateCache.containsKey(song.path)) {
        bitrate = _bitrateCache[song.path];
      } else {
        try {
          final file = File(song.path);
          if (file.existsSync()) {
            // Run in isolate or just ensure it's handled away from build
            final meta = readMetadata(file, getImage: false);
            if (meta.bitrate != null) {
              bitrate = '${(meta.bitrate! / 1000).round()}';
              _bitrateCache[song.path] = bitrate;
            }
          }
        } catch (_) {}
      }
      bitrate ??= song.bitrate?.toString() ?? '---';
      metadata = '$ext | ${bitrate}Kbps';
    }

    if (mounted && song.path == _currentSongPath) {
      setState(() {
        _currentAlbumArt = art;
        _codecBitrate = metadata;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 650),
        )..addListener(() {
          // Update signal for global UI coordination (like hiding navbar)
          audioSignal.playerExpansion.value = _controller.value;

          // Automatically hide keyboard when expanding
          if (_controller.value > 0.05 &&
              FocusManager.instance.primaryFocus != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }

          // Automatically disable lyrics when minimized
          if (_controller.value < 1.0 && audioSignal.showLyrics.value) {
            audioSignal.showLyrics.value = false;
          }
        });

    // Listen to song changes via effect to trigger metadata/art loading
    _effectDisposals.add(effect(() {
      _handleSongChange(audioSignal.currentSong.value);
    }));

    _visibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _lyricsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _effectDisposals.add(effect(() {
      if (audioSignal.showLyrics.value) {
        _lyricsController.forward();
      } else {
        _lyricsController.reverse();
      }
    }));

    _dragResetController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          setState(() {
            _dragDownOffset = lerpDouble(
              _dragDownOffset,
              0.0,
              _dragResetController.value,
            )!;
          });
        });

    // Initial state check
    if (audioSignal.currentSong.value != null) {
      _visibilityController.value = 1.0;
    }

    // specific listener for song changes to drive visibility
    _effectDisposals.add(effect(() {
      final song = audioSignal.currentSong.value;
      // On desktop, we always want the player to be visible
      final isDesktop =
          !kIsWeb &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

      if (song != null || isDesktop) {
        _visibilityController.forward();
      } else {
        _visibilityController.reverse();
      }
    }));

    // Listener for back button minimization from shell
    _effectDisposals.add(effect(() {
      final _ = audioSignal.minimizePlayerTrigger.value;
      if (_controller.value > 0) {
        _controller.animateTo(0.0, curve: Curves.fastLinearToSlowEaseIn);
      }
    }));

    // Listener for Immersion Mode
    _effectDisposals.add(effect(() {
      final showLyrics = audioSignal.showLyrics.value;
      final isPlaying = audioSignal.isPlaying.value;

      if (showLyrics && isPlaying) {
        _resetImmersionTimer();
      } else {
        // Force show and cancel timer when lyrics are dismissed OR playback is paused
        _immersionTimer?.cancel();
        if (mounted && !_showControls) {
          setState(() {
            _showControls = true;
          });
        }
      }
    }));
  }

  @override
  void dispose() {
    for (final dispose in _effectDisposals) {
      dispose();
    }
    _effectDisposals.clear();

    _controller.dispose();
    _visibilityController.dispose();
    _dragResetController.dispose();
    _lyricsController.dispose();
    _immersionTimer?.cancel();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStartValue = _controller.value;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_controller.value == 0 && settingsSignal.swipeDownToStop.value) {
      final delta = details.primaryDelta!;
      if (delta > 0 || _dragDownOffset > 0) {
        setState(() {
          _dragDownOffset += delta;
          if (_dragDownOffset < 0) _dragDownOffset = 0;
        });
        if (_dragDownOffset > 0) return;
      }
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final delta = details.primaryDelta!;

    // Case 1: Player is expanded and we are swiping down to close the player
    if (_controller.value == 1.0 && delta > 0) {
      _controller.value -= delta / screenHeight;
      return;
    }

    // Default: Handle main player expansion/collapse
    _controller.value -= delta / screenHeight;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragDownOffset > 0) {
      final velocity = details.primaryVelocity ?? 0;
      if (_dragDownOffset > 80 || velocity > 500) {
        // Synchronize visibility controller with current drag position
        // so the animation starts from the current visual position.
        final syncValue = (1.0 - (_dragDownOffset / (_barHeight + 20.0))).clamp(
          0.0,
          1.0,
        );
        _visibilityController.value = syncValue;

        audioSignal.stop();
        _dragDownOffset = 0;
      } else {
        _dragResetController.forward(from: 0);
      }
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final value = _controller.value;

    // 1. Swipe down to stop (early exit for this specific gesture)
    if (velocity > 500 && value == 0 && settingsSignal.swipeDownToStop.value) {
      audioSignal.stop();
      return;
    }

    // 2. Flinging (High Velocity)
    if (velocity < -500) {
      // Fling Up -> Open
      _controller.animateTo(1.0, curve: Curves.fastLinearToSlowEaseIn);
      return;
    }
    if (velocity > 500) {
      // Fling Down -> Close
      _controller.animateTo(0.0, curve: Curves.fastLinearToSlowEaseIn);
      return;
    }

    // 2. Dragging (Low Velocity)
    // Determine direction based on start value
    final isDraggingUp = value > _dragStartValue;

    if (isDraggingUp) {
      // Opening: Threshold 0.2
      if (value > 0.2) {
        _controller.animateTo(1.0, curve: Curves.fastLinearToSlowEaseIn);
      } else {
        _controller.animateTo(0.0, curve: Curves.fastLinearToSlowEaseIn);
      }
    } else {
      // Closing: Threshold 0.8
      if (value < 0.8) {
        _controller.animateTo(0.0, curve: Curves.fastLinearToSlowEaseIn);
      } else {
        _controller.animateTo(1.0, curve: Curves.fastLinearToSlowEaseIn);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${minutes}:${twoDigits(seconds)}';
  }

  // Helper to calculate expanded layout efficiently
  ({Rect art, Rect info, Rect seekbar, Rect controls, Rect actions})
  _calculateExpandedLayout(
    double screenWidth,
    double screenHeight,
    double topPadding,
    double bottomPadding,
    bool useFullWidth,
  ) {
    // 1. Define Element Heights
    const infoHeight = 70.0;
    const seekbarHeight = 70.0;
    const controlsHeight = 80.0;
    const actionsHeight = 100.0;

    // 2. Calculate Actions Position (Bottom Anchored)
    final bottomStart = screenHeight - bottomPadding - 24.0;
    final actionsTop = bottomStart - actionsHeight;
    final actionsRect = Rect.fromLTWH(
      0,
      actionsTop,
      screenWidth,
      actionsHeight,
    );

    // 3. Calculate Album Art Position (Top Anchored & Scaled)
    const maxArtSize = 600.0;
    const sidePadding = 32.0;
    final availableWidth = screenWidth - (sidePadding * 2);

    // Calculate max height available for art
    // We need to reserve space for:
    // - Top padding + margin (60)
    // - Middle elements (info + seekbar + controls)
    // - Actions (already calculated)
    // - Minimum gaps (say 8.0 * 4)
    // - Bottom padding + margin (24)

    final middleElementsHeight = infoHeight + seekbarHeight + controlsHeight;
    final minTotalGap =
        8.0 *
        4; // 4 gaps: Top-Art, Art-Info, Info-Seekbar, Seekbar-Controls, Controls-Actions

    // Available space above actions
    final spaceAboveActions = actionsTop;
    final topReserved = 60.0 + topPadding;

    final maxArtHeight =
        spaceAboveActions - topReserved - middleElementsHeight - minTotalGap;

    // Ensure maxArtHeight is at least 0 to avoid clamp errors
    final effectiveMaxArtHeight = maxArtHeight < 0 ? 0.0 : maxArtHeight;

    final artSize = availableWidth
        .clamp(0.0, effectiveMaxArtHeight)
        .clamp(0.0, maxArtSize);

    // 4. Calculate Content Width (Locked to max possible art size on Desktop)
    // This ensures seekbar/names don't shrink when art shrinks vertically
    final maxPossibleArtSize = availableWidth.clamp(0.0, maxArtSize);
    final contentWidth = useFullWidth ? availableWidth : maxPossibleArtSize;
    final contentLeft = (screenWidth - contentWidth) / 2;

    // Center Art in its allocated top area
    final artTop = topReserved;
    final artLeft = (screenWidth - artSize) / 2;
    final artRect = Rect.fromLTWH(artLeft, artTop, artSize, artSize);

    // 5. Distribute Middle Elements
    // Distribute evenly: Art -> Info -> Seekbar -> Controls -> Actions
    final middleStart = artRect.bottom;
    final middleEnd = actionsRect.top;
    final availableMiddleSpace = middleEnd - middleStart;

    final totalGapSpace = availableMiddleSpace - middleElementsHeight;

    // Distribute slack evenly across 4 gaps
    // Remove upper and lower clamps to allow even spacing on all screens
    final gap = (totalGapSpace / 4.0).clamp(0.0, double.infinity);

    // If we clamped the gap (min 0), we might need to center the whole block again
    final totalConsumedHeight = middleElementsHeight + (gap * 4);
    final unusedSpace = availableMiddleSpace - totalConsumedHeight;
    final topOffset = middleStart + (unusedSpace / 2);

    final infoTop = topOffset + gap;
    final seekbarTop = infoTop + infoHeight + gap;
    final controlsTop = seekbarTop + seekbarHeight + gap;

    final infoRect = Rect.fromLTWH(
      contentLeft,
      infoTop,
      contentWidth,
      infoHeight,
    );
    final seekbarRect = Rect.fromLTWH(
      contentLeft,
      seekbarTop,
      contentWidth,
      seekbarHeight,
    );
    final controlsRect = Rect.fromLTWH(
      0,
      controlsTop,
      screenWidth,
      controlsHeight,
    );

    return (
      art: artRect,
      info: infoRect,
      seekbar: seekbarRect,
      controls: controlsRect,
      actions: actionsRect,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isActualMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final isMobile = isActualMobile; // Use platform check for layout style

    return Watch((context) {
      final currentSong = audioSignal.currentSong.value;
      final isPlaying = audioSignal.isPlaying.value;
      final duration = audioSignal.duration.value;

      // Calculate availability-based compactness
      final availableBarWidth = screenWidth - widget.leftOffset;
      // Switch to compact layout if space is < 800px or screen is < 600px
      final isCompact = availableBarWidth < 700 || screenWidth < 600;

      // Calculate where the scrollable content should start
      // final fullArtSize = isMobile ? screenWidth - 64.0 : 560.0;
      // final contentTopStart = 100.0 + fullArtSize + 24.0 + 58.0;

      // Dynamic Layout Values based on Config
      final margin = isMobile ? _compactMargin : _fullMargin;
      final startArtLeft = isCompact
          ? (isMobile ? _compactPadding : _fullPadding)
          : _fullPadding + _leftControlsWidth + _artSpacing;

      return AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _visibilityController,
          _lyricsController,
        ]),
        builder: (context, child) {
          final value = _controller.value;

          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final currentTopPadding = lerpDouble(0, topPadding, value)!;

          final rawLyricsValue = const Cubic(
            0.76,
            0,
            0.24,
            1,
          ).transform(_lyricsController.value);
          // Layout mode: Desktop if width >= 900, otherwise Mobile
          final isDesktopLayoutMode = screenWidth >= 900;

          // On desktop side-by-side, don't morph the art/text — keep them in place
          final lyricsValue = isDesktopLayoutMode ? 0.0 : rawLyricsValue;

          // --- Layout Interpolation ---
          // Clamping and Centering Logic for Desktop
          const paneGap_Value = 48.0;
          final maxPaneWidth_Value = ((screenWidth - paneGap_Value - 64.0) / 2).clamp(
            0.0,
            600.0,
          );

          // Calculate the target width for the player part
          final playerWidth = isDesktopLayoutMode
              ? lerpDouble(screenWidth, maxPaneWidth_Value, rawLyricsValue)!
              : screenWidth;

          // Memoize Layout Calculation
          final isCompactLayout = isCompact || isMobile;
          if (_cachedLayout == null ||
              _lastLayoutSize?.width != playerWidth ||
              _lastLayoutSize?.height != screenHeight ||
              _lastPadding != MediaQuery.of(context).padding ||
              _lastIsCompact != isCompactLayout ||
              _lastLyricsValue != rawLyricsValue) {
            
            final rawLayout = _calculateExpandedLayout(
              playerWidth,
              screenHeight,
              topPadding, // Use final values for expansion target
              bottomPadding,
              isCompactLayout,
            );

            // Calculate how much to shift the player to the left to center the group
            final groupWidth = maxPaneWidth_Value * 2 + paneGap_Value;
            final groupLeft = (screenWidth - groupWidth) / 2;
            final playerShift_Value = isDesktopLayoutMode
                ? lerpDouble(0, groupLeft, rawLyricsValue)!
                : 0.0;

            _cachedLayout = (
              art: rawLayout.art.shift(Offset(playerShift_Value, 0)),
              info: rawLayout.info.shift(Offset(playerShift_Value, 0)),
              seekbar: rawLayout.seekbar.shift(Offset(playerShift_Value, 0)),
              controls: rawLayout.controls.shift(Offset(playerShift_Value, 0)),
              actions: rawLayout.actions.shift(Offset(playerShift_Value, 0)),
              shift: playerShift_Value,
              groupLeft: groupLeft,
              maxPaneWidth: maxPaneWidth_Value,
              paneGap: paneGap_Value,
            );

            _lastLayoutSize = Size(playerWidth, screenHeight);
            _lastPadding = MediaQuery.of(context).padding;
            _lastIsCompact = isCompactLayout;
            _lastLyricsValue = rawLyricsValue;
          }

          final expandedLayout = _cachedLayout;
          final groupLeft = expandedLayout.groupLeft;
          final maxPaneWidth = expandedLayout.maxPaneWidth;
          final paneGap = expandedLayout.paneGap;

          final currentHeight = lerpDouble(_barHeight, screenHeight, value)!;
          final currentBottom = lerpDouble(
            widget.bottomOffset + margin,
            0,
            value,
          )!;

          // Calculate collapsed state values
          final availableWidth = screenWidth - widget.leftOffset;
          final collapsedWidth = (availableWidth - (margin * 2)).clamp(
            0.0,
            900.0,
          );
          final collapsedLeft = isCompact
              ? widget.leftOffset + margin
              : widget.leftOffset + (availableWidth - collapsedWidth) / 2;

          final currentWidth = lerpDouble(collapsedWidth, screenWidth, value)!;

          final currentLeft = lerpDouble(collapsedLeft, 0, value)!;

          // Opacities
          final fullOpacity = ((value - 0.2) * 5).clamp(0.0, 1.0);

          // Art Layout
          final startArtTop = 13.3; // Perfectly centered in 80px bar: (80-50)/2
          final baseArtTop = lerpDouble(
            startArtTop,
            expandedLayout.art.top,
            value,
          )!;
          final baseArtLeft = lerpDouble(
            startArtLeft,
            expandedLayout.art.left,
            value,
          )!;
          final baseArtSize = lerpDouble(
            _miniArtSize,
            expandedLayout.art.width,
            value,
          )!;

          final targetLyricsArtLeft = expandedLayout.info.left;
          final targetLyricsArtTop = expandedLayout.art.top;
          final targetLyricsArtSize = 56.0;

          final artTop = lerpDouble(
            baseArtTop,
            targetLyricsArtTop,
            lyricsValue,
          )!;
          final artLeft = lerpDouble(
            baseArtLeft,
            targetLyricsArtLeft,
            lyricsValue,
          )!;
          final artSize = lerpDouble(
            baseArtSize,
            targetLyricsArtSize,
            lyricsValue,
          )!;

          final targetLyricsInfoLeft =
              targetLyricsArtLeft + targetLyricsArtSize + 16.0;
          final targetLyricsInfoRect = Rect.fromLTWH(
            targetLyricsInfoLeft,
            targetLyricsArtTop,
            expandedLayout.info.right - targetLyricsInfoLeft,
            targetLyricsArtSize,
          );

          // --- Visibility Interpolation ---
          final visibilityCurve = Curves.easeInOut;
          final visibilityValue = visibilityCurve.transform(
            _visibilityController.value,
          );
          final visibilityOffset =
              (1.0 - visibilityValue) * (currentHeight + 20.0);
          final effectiveBottom =
              currentBottom - visibilityOffset - _dragDownOffset;

          return Positioned(
            left: currentLeft,
            width: currentWidth,
            bottom: effectiveBottom,
            height: currentHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _handleDragStart,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              onTap: value == 0
                  ? () => _controller.animateTo(
                      1.0,
                      curve: Curves.fastLinearToSlowEaseIn,
                    )
                  : () {
                      if (audioSignal.showLyrics.value) {
                        _resetImmersionTimer();
                      }
                    },
              child: Material(
                type: MaterialType.transparency,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    lerpDouble(50, 0, value)!,
                  ),
                  child: BackdropFilter(
                    filter: settingsSignal.enableGlobalBlur.value
                        ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                        : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Theme.of(context)
                              .extension<AppThemeExtension>()!
                              .playerBarBackground
                              .withValues(
                                alpha: settingsSignal.enableGlobalBlur.value
                                    ? 0.92
                                    : 1.0,
                              ),
                          Theme.of(context).colorScheme.surface,
                          value,
                        ),
                        borderRadius: BorderRadius.circular(
                          lerpDouble(50, 0, value)!,
                        ),
                        border: Border.all(
                          color: Color.lerp(
                            Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.15),
                            Colors.transparent,
                            value,
                          )!,
                          width: lerpDouble(2, 0, value)!,
                        ),
                        boxShadow: [
                          if (value > 0)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 2. Full Screen Background
                          if (currentSong != null)
                            _PlayerBackground(
                              song: currentSong,
                              opacity: fullOpacity,
                              albumArt: _currentAlbumArt,
                            ),

                          Positioned.fill(
                            child: Stack(
                              children: [
                                // 2. Lyrics Body
                                // Mobile: overlay that fades in/out
                                // Desktop Layout: side-by-side panel on the right half of the group
                                if (!isDesktopLayoutMode &&
                                    rawLyricsValue > 0.0)
                                  Opacity(
                                    opacity: rawLyricsValue,
                                    child: IgnorePointer(
                                      ignoring: rawLyricsValue < 0.8,
                                      child: _buildLyricsBody(
                                        currentSong,
                                        screenWidth,
                                        expandedLayout,
                                        isDesktopLayout: false,
                                      ),
                                    ),
                                  ),
                                if (isDesktopLayoutMode && rawLyricsValue > 0.0)
                                  Positioned(
                                    top: 0,
                                    bottom: 0,
                                    // Slide in from the right relative to the group
                                    left: lerpDouble(
                                      screenWidth,
                                      groupLeft + maxPaneWidth + paneGap,
                                      rawLyricsValue,
                                    )!,
                                    width: maxPaneWidth,
                                    child: Opacity(
                                      opacity: rawLyricsValue,
                                      child: IgnorePointer(
                                        ignoring: rawLyricsValue < 0.8,
                                        child: _buildLyricsBody(
                                          currentSong,
                                          maxPaneWidth,
                                          expandedLayout,
                                          isDesktopLayout: true,
                                        ),
                                      ),
                                    ),
                                  ),

                                // 3. Album Art
                                Positioned(
                                  top: artTop,
                                  left: artLeft,
                                  width: artSize,
                                  height: artSize,
                                  child: Watch((context) {
                                    final position = audioSignal.position.value;
                                    return _buildMorphingArt(
                                      currentSong,
                                      value,
                                      artSize,
                                      isPlaying,
                                      duration,
                                      position,
                                    );
                                  }),
                                ),

                                // 4. Song Info (Text)
                                _buildMorphingText(
                                  value,
                                  lyricsValue,
                                  collapsedWidth,
                                  currentSong,
                                  isPlaying,
                                  expandedLayout.info,
                                  targetLyricsInfoRect,
                                  isCompact,
                                  isMobile,
                                ),

                                // 4. Playback Controls
                                _buildMorphingControls(
                                  value,
                                  screenWidth,
                                  collapsedWidth,
                                  isPlaying,
                                  isCompact,
                                  expandedLayout.controls,
                                ),

                                // 5. Seekbar
                                Watch((context) {
                                  final position = audioSignal.position.value;
                                  final hasLyrics =
                                      audioSignal.currentLyrics.value != null;
                                  return _buildMorphingSeekbar(
                                    isMobile,
                                    value,
                                    lyricsValue,
                                    hasLyrics,
                                    position,
                                    duration,
                                    screenWidth,
                                    expandedLayout.seekbar,
                                  );
                                }),

                                // 6. Expanded Content (Actions)
                                _buildMorphingActions(
                                  currentSong,
                                  value,
                                  expandedLayout.actions,
                                  collapsedWidth,
                                  isCompact,
                                ),
                              ],
                            ),
                          ),

                          // 7. Collapse Button
                          if (fullOpacity > 0)
                            Positioned(
                              top: 8 + currentTopPadding,
                              left: screenWidth / 2 - 24,
                              child: Opacity(
                                opacity: fullOpacity,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    size: 24,
                                  ),
                                  onPressed: () => _controller.animateTo(
                                    0.0,
                                    curve: Curves.fastLinearToSlowEaseIn,
                                  ),
                                ),
                              ),
                            ),

                          // 8. Reserved Space for Morphings (removed redundancy)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }


  Widget _buildMorphingSeekbar(
    bool isMobile,
    double value,
    double lyricsValue,
    bool hasLyrics,
    Duration position,
    Duration duration,
    double screenWidth,
    Rect targetRect,
  ) {
    if (value < 0.9) return const SizedBox.shrink();

    // Fade out seekbar if lyrics are showing AND they exist
    final effectLyricsOpacity = hasLyrics ? lyricsValue : 0.0;
    final seekbarOpacity =
        ((value - 0.9) * 10).clamp(0.0, 1.0) * (1.0 - effectLyricsOpacity);

    if (seekbarOpacity <= 0) return const SizedBox.shrink();

    // Interpolate
    // Start state isn't really visible, so we can just interpolate to target
    final currentTop = targetRect.top;
    final currentLeft = targetRect.left;
    final currentWidth = targetRect.width;

    return Positioned(
      top: currentTop,
      left: currentLeft,
      width: currentWidth,
      child: IgnorePointer(
        ignoring:
            value < 0.9 ||
            effectLyricsOpacity >
                0.5, // Only interactive when fully expanded and lyrics hidden
        child: Opacity(
          opacity: seekbarOpacity,
          child: Column(
            spacing: 6,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeIn,
                tween: Tween<double>(begin: 6.0, end: _isSeeking ? 14.0 : 6.0),
                builder: (context, height, child) {
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: height,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 6,
                      ),
                      activeTrackColor: Theme.of(context).colorScheme.secondary,
                      inactiveTrackColor: Theme.of(
                        context,
                      ).colorScheme.secondary.withOpacity(0.3),
                      thumbColor: Theme.of(context).colorScheme.secondary,
                    ),
                    child: Slider(
                      value:
                          (position.inMilliseconds /
                                  (duration.inMilliseconds > 0
                                      ? duration.inMilliseconds
                                      : 1))
                              .clamp(0.0, 1.0),
                      onChangeStart: (v) {
                        setState(() {
                          _isSeeking = true;
                        });
                      },
                      onChangeEnd: (v) {
                        setState(() {
                          _isSeeking = false;
                        });
                      },
                      onChanged: (v) {
                        final pos = v * duration.inMilliseconds;
                        audioSignal.seek(Duration(milliseconds: pos.round()));
                      },
                    ),
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMorphingText(
    double value,
    double lyricsValue,
    double collapsedWidth,
    Song? currentSong,
    bool isPlaying,
    Rect targetRect,
    Rect lyricsTargetRect,
    bool isCompact,
    bool isMobile,
  ) {
    final startArtLeft = isCompact
        ? (isMobile ? _compactPadding : _fullPadding)
        : _fullPadding + _leftControlsWidth + _artSpacing;

    final fixedStartLeft = startArtLeft + 50.0 + 16;
    final fixedStartHeight = 50.0; // Perfectly match art height
    final fixedStartTop = 13.0; // Perfectly centered in 80px bar: (80-50)/2

    // Calculate start width based on layout (Compact vs Full)
    final rightControlsWidth = isCompact
        ? 130.0 // Balanced buffer for mobile (100px controls + 30px buffer)
        : 300.0; // Balanced buffer for desktop (280px controls + padding + margin)
    final fixedStartWidth =
        (collapsedWidth - fixedStartLeft - rightControlsWidth).clamp(
          10.0,
          1200.0,
        );

    // Interpolation (Mini -> Expanded)
    final baseLeft = lerpDouble(fixedStartLeft, targetRect.left, value)!;
    final baseTop = lerpDouble(fixedStartTop, targetRect.top, value)!;
    final baseWidth = lerpDouble(fixedStartWidth, targetRect.width, value)!;
    final baseHeight = lerpDouble(fixedStartHeight, targetRect.height, value)!;

    // Interpolation (Expanded -> Lyrics Header)
    final currentLeft = lerpDouble(
      baseLeft,
      lyricsTargetRect.left,
      lyricsValue,
    )!;
    final currentTop = lerpDouble(baseTop, lyricsTargetRect.top, lyricsValue)!;
    final currentWidth = lerpDouble(
      baseWidth,
      lyricsTargetRect.width,
      lyricsValue,
    )!;
    final currentHeight = lerpDouble(
      baseHeight,
      lyricsTargetRect.height,
      lyricsValue,
    )!;

    // Text Styles (Mini -> Expanded)
    final baseTitleStyle = TextStyle.lerp(
      TextStyle(
        color: Theme.of(context).colorScheme.secondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 1.2,
      ),
      TextStyle(
        color: Theme.of(context).colorScheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      value,
    )!;

    final baseArtistStyle = TextStyle.lerp(
      TextStyle(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
        fontSize: 12,
        height: 1.2,
      ),
      TextStyle(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.4,
      ),
      value,
    )!;

    // Morph to Lyrics Header Styles
    final lyricsTitleStyle = TextStyle(
      color: Theme.of(context).colorScheme.secondary,
      fontWeight: FontWeight.bold,
      fontSize: 20,
      height: 1.3,
    );
    final lyricsArtistStyle = TextStyle(
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.3,
    );

    final titleStyle = TextStyle.lerp(
      baseTitleStyle,
      lyricsTitleStyle,
      lyricsValue,
    )!;
    final artistStyle = TextStyle.lerp(
      baseArtistStyle,
      lyricsArtistStyle,
      lyricsValue,
    )!;

    return Positioned(
      left: currentLeft,
      top: currentTop,
      width: currentWidth,
      height: currentHeight,
      child: RepaintBoundary(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: value > 0.1
                    ? ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.black, Colors.transparent],
                            stops: [0.9, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ClipRect(
                          child: _buildTextContent(
                            currentSong,
                            titleStyle,
                            artistStyle,
                            isPlaying,
                            value,
                          ),
                        ),
                      )
                    : _buildTextContent(
                        currentSong,
                        titleStyle,
                        artistStyle,
                        isPlaying,
                        value,
                      ),
              ),
              if (value > 0.5)
                Opacity(
                  opacity: ((value - 0.5) * 2).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Watch((context) {
                      final isFav =
                          currentSong != null &&
                          audioSignal.isFavorite(currentSong.path);
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: FaIcon(
                          isFav
                              ? FontAwesomeIcons.solidHeart
                              : FontAwesomeIcons.heart,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 24,
                        ),
                        onPressed: () {
                          if (currentSong != null) {
                            audioSignal.toggleFavorite(currentSong.path);
                          }
                        },
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(
    Song? currentSong,
    TextStyle titleStyle,
    TextStyle artistStyle,
    bool isPlaying,
    double value,
  ) {
    final title = currentSong?.title ?? 'No song playing';
    
    return Column(
      spacing: value <= 0.5 ? 0 : 1,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final textPainter = TextPainter(
              text: TextSpan(text: title, style: titleStyle),
              maxLines: 1,
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: double.infinity);

            if (textPainter.size.width <= constraints.maxWidth) {
              return Text(
                title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }

            return SizedBox(
              height: (titleStyle.fontSize ?? 16.0) * (titleStyle.height ?? 1.2),
              child: Marquee(
                text: title,
                style: titleStyle,
                scrollAxis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                blankSpace: 50.0,
                velocity: isPlaying ? 30.0 : 0.0,
                pauseAfterRound: const Duration(seconds: 4),
                startPadding: 0.0,
                accelerationDuration: const Duration(milliseconds: 500),
                accelerationCurve: Curves.linear,
                decelerationDuration: const Duration(milliseconds: 500),
                decelerationCurve: Curves.easeOut,
              ),
            );
          },
        ),
        SizedBox(height: 6),
        Text(
          currentSong?.artist ?? '',
          style: artistStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMorphingArt(
    Song? currentSong,
    double value,
    double artSize,
    bool isPlaying,
    Duration duration,
    Duration position,
  ) {
    final isYoutube = currentSong?.path.startsWith('yt:') ?? false;
    final ytThumbnailUrl = isYoutube
        ? youtubeDatasource.getArtworkUrl(currentSong!.path.substring(3))
        : null;

    return IgnorePointer(
      ignoring:
          value > 0.1 && value < 0.9, // Let controls catch hits during morph
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular Progress (Mini only)
            if (value == 0)
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0,
                  strokeWidth: 3,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.8),
                  ),
                ),
              ),

            // Art / Play Button
            GestureDetector(
              onTap: () {
                if (value == 0) {
                  if (isPlaying) {
                    audioSignal.pause();
                  } else {
                    audioSignal.play();
                  }
                }
              },
              child: Hero(
                tag: 'player-artwork',
                child: Container(
                  width: value == 0 ? 42 : artSize,
                  height: value == 0 ? 42 : artSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(value == 0 ? 50 : 8),
                    boxShadow: [
                      if (value > 0.5)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(value == 0 ? 50 : 8),
                    child: isYoutube
                        ? Image.network(
                            ytThumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          )
                        : _currentAlbumArt != null
                        ? Image.file(_currentAlbumArt!, fit: BoxFit.cover)
                        : (value == 0)
                        ? Center(
                            child: FaIcon(
                              isPlaying
                                  ? FontAwesomeIcons.pause
                                  : FontAwesomeIcons.play,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 14,
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: Icon(
                              Icons.music_note,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorphingControls(
    double value,
    double screenWidth,
    double collapsedWidth,
    bool isPlaying,
    bool isCompact,
    Rect targetRect,
  ) {
    // Detect if we're on mobile based on platform
    final isMobile = Platform.isAndroid || Platform.isIOS;

    final song = audioSignal.currentSong.value;
    final hasSong = song != null;
    final show = _showControls || value < 0.9;

    return Watch((context) {
      // Playback controls are now fixed as per user request
      final miniButtons = ['previous', 'play_pause', 'next'];
      final expandedButtons = ['previous', 'play_pause', 'next'];

      // Union layout for the Row (fixed controls)
      final allButtons = ['previous', 'play_pause', 'next'];

      // Start State (Mini)
      double startRight;
      double startLeft;
      double startTop = (isMobile ? _startTop - 1.0 : _startTop);
      double startWidth;

      if (isCompact) {
        startRight = 0.0;
        startWidth = (miniButtons.length * 48.0 + (miniButtons.length - 1) * 2.0).clamp(48.0, 200.0);
        startLeft = collapsedWidth - startRight - startWidth;
      } else {
        startLeft = 0;
        startWidth = _leftControlsWidth;
      }

      // Interpolate overall container
      final currentLeft = lerpDouble(startLeft, targetRect.left, value)!;
      final currentTop = lerpDouble(startTop, targetRect.top, value)!;
      final currentWidth = lerpDouble(startWidth, targetRect.width, value)!;

      // Button Spacing
      final buttonPadding = EdgeInsets.lerp(
        isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
        const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        value,
      )!;

      return Positioned(
        top: currentTop,
        left: currentLeft,
        width: currentWidth,
        height: lerpDouble(_barHeight, targetRect.height, value),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: show ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !show,
            child: Listener(
              onPointerDown: (_) => _resetImmersionTimer(),
              child: RepaintBoundary(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final buttonId in allButtons) ...[
                      Builder(builder: (context) {
                        final inMini = miniButtons.contains(buttonId);
                        final inExpanded = expandedButtons.contains(buttonId);

                        // Calculate opacity
                        double opacity;
                        if (inMini && inExpanded) {
                          opacity = 1.0; // Always visible
                        } else if (inMini) {
                          opacity = (1.0 - value * 2).clamp(0.0, 1.0); // Fade out
                        } else {
                          opacity = ((value - 0.5) * 2).clamp(0.0, 1.0); // Fade in
                        }

                        if (opacity <= 0) return const SizedBox.shrink();

                        // Calculate size
                        final miniSize = inMini ? (isCompact && buttonId == 'play_pause' ? 0.0 : 24.0) : 0.0;
                        final expandedSize = inExpanded ? (buttonId == 'play_pause' ? 56.0 : 40.0) : 0.0;
                        final size = lerpDouble(miniSize, expandedSize, value)!;

                        if (size < 1) return const SizedBox.shrink();

                        return Opacity(
                          opacity: opacity,
                          child: _buildPlayerButtonById(
                            context: context,
                            id: buttonId,
                            iconSize: size,
                            isPlaying: isPlaying,
                            hasSong: hasSong,
                            buttonPadding: buttonPadding,
                            isCompact: isCompact,
                            value: value,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPlayerButtonById({
    required BuildContext context,
    required String id,
    required double iconSize,
    required bool isPlaying,
    required bool hasSong,
    required EdgeInsets buttonPadding,
    required bool isCompact,
    required double value,
  }) {
    final color = hasSong
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5);

    switch (id) {
      case 'previous':
        return IconButton(
          padding: buttonPadding,
          constraints: isCompact ? const BoxConstraints() : null,
          splashColor: value > 0.05 ? Colors.transparent : null,
          highlightColor: value > 0.05 ? Colors.transparent : null,
          hoverColor: value > 0.05 ? Colors.transparent : null,
          icon: FaIcon(FontAwesomeIcons.backwardStep, color: color, size: iconSize),
          onPressed: hasSong ? audioSignal.skipPrevious : null,
        );
      case 'play_pause':
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: Platform.isAndroid || Platform.isIOS ? lerpDouble(0, 6, value)! : 6,
          ),
          child: IconButton(
            padding: buttonPadding,
            constraints: isCompact ? const BoxConstraints() : null,
            splashColor: value > 0.05 ? Colors.transparent : null,
            highlightColor: value > 0.05 ? Colors.transparent : null,
            hoverColor: value > 0.05 ? Colors.transparent : null,
            icon: FaIcon(
              isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              color: color,
              size: iconSize,
            ),
            onPressed: hasSong
                ? () {
                    if (isPlaying) {
                      audioSignal.pause();
                    } else {
                      audioSignal.play();
                    }
                  }
                : null,
          ),
        );
      case 'next':
        return IconButton(
          padding: buttonPadding,
          constraints: isCompact ? const BoxConstraints() : null,
          splashColor: value > 0.05 ? Colors.transparent : null,
          highlightColor: value > 0.05 ? Colors.transparent : null,
          hoverColor: value > 0.05 ? Colors.transparent : null,
          icon: FaIcon(FontAwesomeIcons.forwardStep, color: color, size: iconSize),
          onPressed: hasSong ? audioSignal.skipNext : null,
        );
      default:
        // Delegate to the existing actions builder for shuffle, repeat, etc.
        return _buildActionById(
          context: context,
          id: id,
          iconSize: iconSize,
          currentSong: audioSignal.currentSong.value,
        );
    }
  }

  Widget _buildMorphingActions(
    Song? currentSong,
    double value,
    Rect targetRect,
    double collapsedWidth,
    bool isCompact,
  ) {
    return Watch((context) {
    // Start State (Desktop Bar)
    // Right aligned: Shuffle, Repeat, List, More
    // Total width approx: 4 * 40 (icon + padding) + 3 * 12 (gap) = 160 + 36 = 196
    // Start Right = 20
    // Start Top = (80 - 48) / 2 = 16 - 1 = 15

    final startRight = 16.0;
    final startTop = 15.0; // Moved up by 1px
    
    // IconButton is usually 48x48, spacing is 12
    final actionsCount = settingsSignal.playerBarActions.value.length;
    final maxActionsWidth = isCompact ? (collapsedWidth * 0.45) : 600.0;
    final startWidth = (actionsCount * 48.0 + (actionsCount - 1) * 12.0).clamp(0.0, maxActionsWidth);
    final startLeft = collapsedWidth - startRight - startWidth;

    // End State (Expanded)
    // TargetRect is bottom anchored

    // Interpolate Position
    final currentLeft = lerpDouble(startLeft, targetRect.left, value)!;
    final currentTop = lerpDouble(startTop, targetRect.top, value)!;
    final currentWidth = lerpDouble(startWidth, targetRect.width, value)!;
    final currentHeight = lerpDouble(48, targetRect.height, value)!;

    // Opacity for Format Badge (Only visible in expanded)
    final badgeOpacity = ((value - 0.5) * 2).clamp(0.0, 1.0);

    // Opacity for Actions (Always visible on large Desktop bar, fade in on Compact/Mobile)
    final actionsOpacity = isCompact ? value : 1.0;

    // Interpolate Icon Size
    final iconSize = lerpDouble(24, 24, value)!;

    // Interpolate Spacing
    final spacing = lerpDouble(12, 18, value)!;

    final show = _showControls || value < 0.9;

    return Positioned(
      top: currentTop,
      left: currentLeft,
      width: currentWidth,
      height: currentHeight,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: show ? actionsOpacity : 0.0,
        child: IgnorePointer(
          ignoring: (isCompact && value < 0.05) || !show,
          child: Listener(
            onPointerDown: (_) => _resetImmersionTimer(),
            child: Stack(
              alignment: Alignment.bottomCenter, // Align to bottom
              children: [
                // Format Badge (Positioned above buttons)
                if (currentSong != null)
                  Positioned(
                    bottom: 60, // 48px (buttons) + 12px (gap)
                    child: Opacity(
                      opacity: badgeOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _codecBitrate ?? '...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Action Buttons (Pinned to bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 48,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < actionsCount; i++) ...[
                          if (i > 0) SizedBox(width: spacing),
                          _buildActionById(
                            context: context,
                            id: settingsSignal.playerBarActions.value[i],
                            iconSize: iconSize,
                            currentSong: currentSong,
                          ),
                        ],
                      ],
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
    });
  }

  Widget _buildLyricsBody(
    Song? currentSong,
    double screenWidth,
    dynamic expandedLayout, {
    bool isDesktopLayout = false,
  }) {
    if (currentSong == null) return const SizedBox.shrink();

    // For mobile overlays, lyrics start below the shifted album art.
    // For desktop side-by-side, lyrics take up the full panel.
    final topPadding = isDesktopLayout ? 80.0 : (expandedLayout.art.top + 46.0);

    return Watch((context) {
      final lyrics = audioSignal.currentLyrics.value;
      final hasLyrics = lyrics != null;

      final bottomEdge = isDesktopLayout
          ? MediaQuery.of(context).size.height
          : (hasLyrics
                ? (_showControls
                      ? expandedLayout.controls.top
                      : MediaQuery.of(context).size.height - 24.0)
                : expandedLayout.seekbar.top);

      final availableHeight = bottomEdge - topPadding;

      Widget content;
      if (!hasLyrics) {
        final loadingHeight = expandedLayout.seekbar.top - topPadding;
        content = SizedBox(
          width: screenWidth,
          height: loadingHeight,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      } else {
        final alignment = settingsSignal.lyricsAlignment.value;
        final isCentered = alignment == TextAlign.center;

        final lyricsWidget = MobileLyricsView(
          lyricsText: lyrics,
          onUserScrollDown: _resetImmersionTimer,
        );

        content = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: screenWidth,
          height: availableHeight,
          child: isDesktopLayout || isCentered
              ? lyricsWidget
              : Center(
                  child: SizedBox(
                    width: expandedLayout.info.width,
                    child: lyricsWidget,
                  ),
                ),
        );
      }

      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: content,
      );
    });
  }

  Widget _buildActionById({
    required BuildContext context,
    required String id,
    required double iconSize,
    Song? currentSong,
  }) {
    switch (id) {
      case 'shuffle':
        return Watch((context) {
          final isShuffle = audioSignal.isShuffleMode.value;
          return IconButton(
            icon: FaIcon(
              FontAwesomeIcons.shuffle,
              color: isShuffle
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
              size: iconSize,
            ),
            onPressed: audioSignal.toggleShuffle,
          );
        });
      case 'repeat':
        return Watch((context) {
          final mode = audioSignal.repeatMode.value;
          final isNone = mode == AudioServiceRepeatMode.none;
          final isOne = mode == AudioServiceRepeatMode.one;
          return IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.repeat,
                  color: !isNone
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
                  size: iconSize,
                ),
                if (isOne)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: audioSignal.toggleRepeat,
          );
        });
      case 'lyrics':
        return Watch((context) {
          final showLyrics = audioSignal.showLyrics.value;
          return IconButton(
            icon: FaIcon(
              FontAwesomeIcons.music,
              color: showLyrics
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              size: iconSize,
            ),
            onPressed: () {
              audioSignal.showLyrics.value = !showLyrics;
            },
          );
        });
      case 'queue':
        return IconButton(
          icon: FaIcon(
            FontAwesomeIcons.listUl,
            color: Theme.of(context).colorScheme.secondary,
            size: iconSize,
          ),
          onPressed: () => showQueueSheet(context),
        );
      case 'more':
        return IconButton(
          icon: FaIcon(
            FontAwesomeIcons.ellipsis,
            color: Theme.of(context).colorScheme.secondary,
            size: iconSize,
          ),
          onPressed: () {
            if (currentSong != null) {
              showSongMoreActionsSheet(
                context: context,
                song: currentSong,
                albumArt: _currentAlbumArt,
              );
            }
          },
        );
      case 'add_to_playlist':
        return IconButton(
          icon: Icon(Icons.playlist_add, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: currentSong != null ? () => PlaylistPickerDialog.show(context, song: currentSong) : null,
        );
      case 'play_next':
        return IconButton(
          icon: Icon(Icons.playlist_play, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: currentSong != null ? () => audioSignal.playNext(currentSong) : null,
        );
      case 'add_to_queue':
        return IconButton(
          icon: Icon(Icons.queue_music, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: currentSong != null ? () => audioSignal.addToQueue(currentSong) : null,
        );
      case 'go_to_album':
        return IconButton(
          icon: Icon(Icons.album_outlined, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: () {},
        );
      case 'go_to_artist':
        return IconButton(
          icon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: () {},
        );
      case 'info':
        return IconButton(
          icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: currentSong != null ? () => showSongInfoDialog(context, currentSong) : null,
        );
      case 'share':
        return IconButton(
          icon: Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: () {},
        );
      case 'sleep_timer':
        return IconButton(
          icon: Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: () => showSleepTimerDialog(context),
        );
      case 'remove_from_playlist':
        return IconButton(
          icon: Icon(Icons.playlist_remove, color: Theme.of(context).colorScheme.secondary, size: iconSize + 4),
          onPressed: () {
            // How do we know which playlist we are in?
            // currentPlaylist signal holds it if we played from a playlist
            final playlist = audioSignal.currentPlaylist.value;
            if (playlist != null && currentSong != null) {
              audioSignal.removeSongFromPlaylist(playlist.id, currentSong.path);
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PlayerBackground extends StatelessWidget {
  final Song song;
  final double opacity;
  final File? albumArt;

  const _PlayerBackground({
    required this.song,
    required this.opacity,
    this.albumArt,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();

    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: RepaintBoundary(
          child: Watch((context) {
            final isBlurEnabled = settingsSignal.enableGlobalBlur.value;
            final dominant = audioSignal.dominantColor.value;
            final muted = audioSignal.mutedColor.value;

            return Stack(
              children: [
                // 1. Image Background (Blurred)
                if (isBlurEnabled)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: _buildBackgroundImage(context),
                    ),
                  ),

                // 2. Gradient Overlay / Main Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _getBackgroundColors(
                          context,
                          isBlurEnabled,
                          dominant,
                          muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage(BuildContext context) {
    final isYoutube = song.path.startsWith('yt:');
    if (isYoutube) {
      final ytThumbnailUrl =
          youtubeDatasource.getArtworkUrl(song.path.substring(3));
      return Image.network(
        ytThumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder:
            (c, e, s) => Container(color: Theme.of(context).colorScheme.surface),
      );
    } else if (albumArt != null) {
      return Image.file(albumArt!, fit: BoxFit.cover);
    }
    return Container(color: Theme.of(context).colorScheme.surface);
  }

  List<Color> _getBackgroundColors(
    BuildContext context,
    bool isBlurEnabled,
    Color? dominant,
    Color? muted,
  ) {
    if (!isBlurEnabled && dominant != null && muted != null) {
      return [dominant.withValues(alpha: 0.8), muted.withValues(alpha: 0.95)];
    }
    return [
      Theme.of(context).colorScheme.surface.withOpacity(0.5),
      Theme.of(context).colorScheme.surface.withOpacity(0.9),
    ];
  }
}
