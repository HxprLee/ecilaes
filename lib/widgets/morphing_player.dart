import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:music_app/widgets/marquee_text.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';
import '../signals/settings_signal.dart';
import '../services/album_art_cache.dart';
import '../models/song.dart';

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
  File? _currentAlbumArt;
  String? _currentSongPath;
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
        });

    _visibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

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
    effect(() {
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
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _visibilityController.dispose();
    _dragResetController.dispose();
    super.dispose();
  }

  void _loadAlbumArt(String? songPath) async {
    if (songPath == null || songPath == _currentSongPath) return;
    _currentSongPath = songPath;

    final art = await AlbumArtCache().getArt(songPath);
    if (mounted && songPath == _currentSongPath) {
      setState(() {
        _currentAlbumArt = art;
      });
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStartValue = _controller.value;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_controller.value == 0 && settingsSignal.swipeDownToStop.value) {
      final delta = details.primaryDelta!;
      // Only handle as a "swipe down to stop" if we are dragging down
      // OR we have already moved the bar down.
      if (delta > 0 || _dragDownOffset > 0) {
        setState(() {
          _dragDownOffset += delta;
          if (_dragDownOffset < 0) _dragDownOffset = 0;
        });

        // If we still have a downward offset, consume the event.
        // If we've returned to 0, let it fall through to handle expansion.
        if (_dragDownOffset > 0) return;
      }
    }

    final screenHeight = MediaQuery.of(context).size.height;
    _controller.value -= details.primaryDelta! / screenHeight;
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
    const maxArtSize = 550.0;
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
    final isSmallScreen = screenWidth < 600;
    final isActualMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final isMobile = isActualMobile; // Use platform check for layout style
    final isCompact = isSmallScreen; // Use screen width for compact elements

    return Watch((context) {
      final currentSong = audioSignal.currentSong.value;
      final isPlaying = audioSignal.isPlaying.value;
      final duration = audioSignal.duration.value;

      if (currentSong != null) {
        _loadAlbumArt(currentSong.path);
      }

      // Calculate where the scrollable content should start
      // final fullArtSize = isMobile ? screenWidth - 64.0 : 560.0;
      // final contentTopStart = 100.0 + fullArtSize + 24.0 + 58.0;

      // Dynamic Layout Values based on Config
      final margin = isMobile ? _compactMargin : _fullMargin;
      final startArtLeft = isCompact
          ? (isMobile ? _compactPadding : _fullPadding)
          : _fullPadding + _leftControlsWidth + _artSpacing;

      return AnimatedBuilder(
        animation: Listenable.merge([_controller, _visibilityController]),
        builder: (context, child) {
          final value = _controller.value;
          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final currentTopPadding = lerpDouble(0, topPadding, value)!;
          final currentBottomPadding = lerpDouble(0, bottomPadding, value)!;

          // --- Layout Interpolation ---
          // Calculate target layout for expanded state
          final expandedLayout = _calculateExpandedLayout(
            screenWidth,
            screenHeight,
            currentTopPadding,
            currentBottomPadding,
            isCompact || isMobile,
          );

          final currentHeight = lerpDouble(_barHeight, screenHeight, value)!;

          // Calculate collapsed state values
          final availableWidth = screenWidth - widget.leftOffset;
          final collapsedWidth = (availableWidth - (margin * 2)).clamp(
            0.0,
            1200.0,
          );
          final collapsedLeft = isCompact
              ? widget.leftOffset + margin
              : widget.leftOffset + (availableWidth - collapsedWidth) / 2;

          final currentWidth = lerpDouble(collapsedWidth, screenWidth, value)!;

          final currentLeft = lerpDouble(collapsedLeft, 0, value)!;
          final currentBottom = lerpDouble(
            widget.bottomOffset + margin,
            0,
            value,
          )!;

          // Opacities
          final fullOpacity = ((value - 0.2) * 5).clamp(0.0, 1.0);

          // Art Layout
          final startArtTop = 13.3; // Perfectly centered in 80px bar: (80-50)/2
          final artTop = lerpDouble(
            startArtTop,
            expandedLayout.art.top,
            value,
          )!;
          final artLeft = lerpDouble(
            startArtLeft,
            expandedLayout.art.left,
            value,
          )!;
          final artSize = lerpDouble(
            _miniArtSize,
            expandedLayout.art.width,
            value,
          )!;

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
            child: PopScope(
              canPop: value == 0,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                if (value > 0) {
                  _controller.animateTo(
                    0.0,
                    curve: Curves.fastLinearToSlowEaseIn,
                  );
                }
              },
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
                    : null,
                child: Material(
                  type: MaterialType.transparency,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      lerpDouble(50, 0, value)!,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            const Color(0xFF11171C).withOpacity(0.6),
                            const Color(0xFF0D1117).withOpacity(0.8),
                            value,
                          ),
                          borderRadius: BorderRadius.circular(
                            lerpDouble(50, 0, value)!,
                          ),
                          border: Border.all(
                            color: Color.lerp(
                              const Color.fromARGB(38, 255, 239, 175),
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
                              _buildBackground(currentSong, fullOpacity),

                            Positioned.fill(
                              child: Stack(
                                children: [
                                  // 2. Album Art
                                  Positioned(
                                    top: artTop,
                                    left: artLeft,
                                    width: artSize,
                                    height: artSize,
                                    child: Watch((context) {
                                      final position =
                                          audioSignal.position.value;
                                      return _buildMorphingArt(
                                        value,
                                        artSize,
                                        isPlaying,
                                        duration,
                                        position,
                                      );
                                    }),
                                  ),

                                  // 3. Song Info (Text)
                                  _buildMorphingText(
                                    value,
                                    screenWidth,
                                    currentSong,
                                    isPlaying,
                                    expandedLayout.info,
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
                                    return _buildMorphingSeekbar(
                                      isMobile,
                                      value,
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
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Color(0xFFFCE7AC),
                                      size: 24,
                                    ),
                                    onPressed: () => _controller.animateTo(
                                      0.0,
                                      curve: Curves.fastLinearToSlowEaseIn,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildBackground(Song currentSong, double fullOpacity) {
    if (_currentAlbumArt == null || fullOpacity <= 0)
      return const SizedBox.shrink();
    return Positioned.fill(
      child: Opacity(
        opacity: fullOpacity,
        child: RepaintBoundary(
          child: Stack(
            children: [
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Image.file(_currentAlbumArt!, fit: BoxFit.cover),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0D1117).withOpacity(0.5),
                        const Color(0xFF0D1117).withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMorphingSeekbar(
    bool isMobile,
    double value,
    Duration position,
    Duration duration,
    double screenWidth,
    Rect targetRect,
  ) {
    if (value < 0.9) return const SizedBox.shrink();

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
        ignoring: value < 0.9, // Only interactive when fully expanded
        child: Opacity(
          opacity: ((value - 0.9) * 10).clamp(0.0, 1.0),
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
                      activeTrackColor: const Color(0xFFFCE7AC),
                      inactiveTrackColor: const Color(
                        0xFFFCE7AC,
                      ).withOpacity(0.3),
                      thumbColor: const Color(0xFFFCE7AC),
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
                    style: const TextStyle(
                      color: Color(0x9FFCE7AC),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Color(0x9FFCE7AC),
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
    double screenWidth,
    Song? currentSong,
    bool isPlaying,
    Rect targetRect,
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
        ? 120.0 // 100px controls + 20px padding
        : 260.0; // Increased for desktop
    final availableWidth = screenWidth - widget.leftOffset;
    final margin = isMobile ? _compactMargin : _fullMargin;
    final collapsedWidth = (availableWidth - (margin * 2)).clamp(0.0, 1200.0);
    final fixedStartWidth =
        collapsedWidth - fixedStartLeft - rightControlsWidth;

    // Interpolation
    final currentLeft = lerpDouble(fixedStartLeft, targetRect.left, value)!;
    final currentTop = lerpDouble(fixedStartTop, targetRect.top, value)!;
    final currentWidth = lerpDouble(fixedStartWidth, targetRect.width, value)!;
    final currentHeight = lerpDouble(
      fixedStartHeight,
      targetRect.height,
      value,
    )!;

    // Text Styles
    final titleStyle = TextStyle.lerp(
      const TextStyle(
        color: Color(0xFFFCE7AC),
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.2,
      ),
      const TextStyle(
        color: Color(0xFFFCE7AC),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      value,
    )!;

    final artistStyle = TextStyle.lerp(
      const TextStyle(
        color: Color.fromARGB(204, 252, 231, 172),
        fontSize: 14,
        height: 1.2,
      ),
      const TextStyle(
        color: Color.fromARGB(180, 252, 231, 172),
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.2,
      ),
      value,
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
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const FaIcon(
                        FontAwesomeIcons.heart,
                        color: Color(0xFFFCE7AC),
                        size: 24,
                      ),
                      onPressed: () {}, // TODO: Implement favorites
                    ),
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
    return Column(
      spacing: value <= 0.5 ? 0 : 1,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        value > 0.5
            ? MarqueeText(
                text: currentSong?.title ?? 'No song playing',
                style: titleStyle,
                isPlaying: isPlaying,
              )
            : Text(
                currentSong?.title ?? 'No song playing',
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    double value,
    double artSize,
    bool isPlaying,
    Duration duration,
    Duration position,
  ) {
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
                  backgroundColor: const Color.fromARGB(51, 255, 239, 175),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(204, 255, 239, 175),
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
                    borderRadius: BorderRadius.circular(value == 0 ? 50 : 12),
                    boxShadow: [
                      if (value > 0.5)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(value == 0 ? 50 : 12),
                    child: _currentAlbumArt != null
                        ? Image.file(_currentAlbumArt!, fit: BoxFit.cover)
                        : (value == 0)
                        ? Center(
                            child: FaIcon(
                              isPlaying
                                  ? FontAwesomeIcons.pause
                                  : FontAwesomeIcons.play,
                              color: const Color(0xFFFCE7AC),
                              size: 16,
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
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

    // Start State (Mini)
    double startRight;
    double startLeft;
    double startTop = _startTop;

    double startWidth;
    double startPlayBtnSize;

    if (isCompact) {
      // Mobile: Right aligned, Play button hidden
      // We use MainAxisAlignment.center for the Row to ensure it centers correctly when expanded.
      // For the mini-player, we position the "center" of this block near the right edge.
      startRight = 0.0; // Pushed closer to edge
      startWidth =
          140.0; // Narrower width to make "Center" alignment appear right-aligned
      startLeft = collapsedWidth - startRight - startWidth;
      startPlayBtnSize = 0;
    } else {
      // Desktop: Left aligned, Play button visible (just icon)
      startLeft = 0;
      startWidth = _leftControlsWidth;
      startPlayBtnSize = 24; // Enough for icon, background transparent
    }

    // End State (Full)
    // Centered between seekbar and bottom section
    // Seekbar is at contentTopStart + 20, height ~80

    // Interpolate
    final currentLeft = lerpDouble(startLeft, targetRect.left, value)!;
    final currentTop = lerpDouble(startTop, targetRect.top, value)!;
    final currentWidth = lerpDouble(startWidth, targetRect.width, value)!;

    // Button Spacing
    // final spacing = lerpDouble(8, 40, value)!;
    final buttonPadding = EdgeInsets.lerp(
      isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      value,
    )!;

    // Play Button Size/Opacity
    final playBtnSize = lerpDouble(startPlayBtnSize, 56, value)!;
    // final playBtnOpacity = lerpDouble(startPlayBtnOpacity, 1.0, value)!;

    // Icon Size
    // final startIconSize = isCompact
    //     ? 0.0
    //     : 24.0; // Standardized to 24px for desktop
    // final iconSize = lerpDouble(startIconSize, 24, value)!;

    // Icon Color
    // final iconOpacity = isCompact ? value : 1.0;

    final song = audioSignal.currentSong.value;
    final hasSong = song != null;

    return Positioned(
      top: currentTop,
      left: currentLeft,
      width: currentWidth,
      height: lerpDouble(
        _barHeight,
        targetRect.height,
        value,
      ), // Use full bar height in mini mode
      child: RepaintBoundary(
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // Always center to prevent snapping
          children: [
            IconButton(
              padding: buttonPadding,
              constraints: isCompact
                  ? const BoxConstraints()
                  : null, // Allow shrinking
              splashColor: value > 0.05 ? Colors.transparent : null,
              highlightColor: value > 0.05 ? Colors.transparent : null,
              hoverColor: value > 0.05 ? Colors.transparent : null,
              icon: FaIcon(
                FontAwesomeIcons.backwardStep,
                color: hasSong
                    ? const Color(0xFFFCE7AC)
                    : const Color(0xFFFCE7AC).withOpacity(0.5),
                size: lerpDouble(24, 40, value)!,
              ),
              onPressed: hasSong ? audioSignal.skipPrevious : null,
            ),

            isMobile ? const SizedBox(width: 2) : const SizedBox(width: 0),
            // Play/Pause Button (Morphing)
            // Use dynamic padding to collapse the container width to 0 when hidden
            Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? lerpDouble(0, 6, value)! : 6,
              ),
              child: playBtnSize >= 24
                  ? IconButton(
                      // Hide if too small
                      padding: buttonPadding,
                      constraints: isCompact ? const BoxConstraints() : null,
                      splashColor: value > 0.05 ? Colors.transparent : null,
                      highlightColor: value > 0.05 ? Colors.transparent : null,
                      hoverColor: value > 0.05 ? Colors.transparent : null,
                      icon: FaIcon(
                        isPlaying
                            ? FontAwesomeIcons.pause
                            : FontAwesomeIcons.play,
                        color: hasSong
                            ? const Color(0xFFFCE7AC)
                            : const Color(0xFFFCE7AC).withOpacity(0.5),
                        size: playBtnSize,
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
                    )
                  : null,
            ),

            isMobile ? const SizedBox(width: 2) : const SizedBox(width: 0),

            IconButton(
              padding: buttonPadding,
              constraints: isCompact ? const BoxConstraints() : null,
              splashColor: value > 0.05 ? Colors.transparent : null,
              highlightColor: value > 0.05 ? Colors.transparent : null,
              hoverColor: value > 0.05 ? Colors.transparent : null,
              icon: FaIcon(
                FontAwesomeIcons.forwardStep,
                color: hasSong
                    ? const Color(0xFFFCE7AC)
                    : const Color(0xFFFCE7AC).withOpacity(0.5),
                size: lerpDouble(24, 40, value)!,
              ),
              onPressed: hasSong ? audioSignal.skipNext : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorphingActions(
    Song? currentSong,
    double value,
    Rect targetRect,
    double collapsedWidth,
    bool isCompact,
  ) {
    // Start State (Desktop Bar)
    // Right aligned: Shuffle, Repeat, List, More
    // Total width approx: 4 * 40 (icon + padding) + 3 * 12 (gap) = 160 + 36 = 196
    // Start Right = 20
    // Start Top = (80 - 48) / 2 = 16 - 1 = 15

    final startRight = 20.0;
    final startTop = 15.0; // Moved up by 1px
    final startWidth =
        220.0; // Increased width to prevent overflow (200 was too tight)
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

    // Opacity for Actions (Always visible on Desktop, fade in on Mobile)
    final actionsOpacity = isCompact ? value : 1.0;

    // Interpolate Icon Size
    final iconSize = lerpDouble(24, 24, value)!;

    // Interpolate Spacing
    final spacing = lerpDouble(12, 18, value)!;

    return Positioned(
      top: currentTop,
      left: currentLeft,
      width: currentWidth,
      height: currentHeight,
      child: Opacity(
        opacity: actionsOpacity,
        child: IgnorePointer(
          ignoring: isCompact && value < 0.05,
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
                        color: const Color(0xFFFCE7AC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFCE7AC).withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        '${currentSong.path.split('.').last.toUpperCase()} | ${currentSong.bitrate ?? '---'}Kbps',
                        style: const TextStyle(
                          color: Color(0xFF21282D),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
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
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.shuffle,
                        color: const Color(0xFFFCE7AC),
                        size: iconSize,
                      ),
                      onPressed: audioSignal.toggleShuffle,
                    ),
                    SizedBox(width: spacing),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.repeat,
                        color: const Color(0xFFFCE7AC),
                        size: iconSize,
                      ),
                      onPressed: () {},
                    ),
                    SizedBox(width: spacing),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.listUl,
                        color: const Color(0xFFFCE7AC),
                        size: iconSize,
                      ),
                      onPressed: () {},
                    ),
                    SizedBox(width: spacing),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.ellipsis,
                        color: const Color(0xFFFCE7AC),
                        size: iconSize,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
