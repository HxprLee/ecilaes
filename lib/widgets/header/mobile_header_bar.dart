import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/navigation_signal.dart';
import '../../theme/app_theme_extensions.dart';

class MobileHeaderBar extends StatefulWidget {
  final double leftOffset;
  final double hideContentOpacity;
  final double expansion;
  final TextEditingController searchController;

  const MobileHeaderBar({
    super.key,
    required this.leftOffset,
    required this.hideContentOpacity,
    required this.expansion,
    required this.searchController,
  });

  @override
  State<MobileHeaderBar> createState() => _MobileHeaderBarState();
}

class _MobileHeaderBarState extends State<MobileHeaderBar> {
  bool _isSearchExpanded = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
    });
    if (_isSearchExpanded) {
      _focusNode.requestFocus();
      final currentRoute = navigationSignal.currentRoute.value;
      if (currentRoute != '/search') {
        context.go('/search');
      }
    } else {
      _focusNode.unfocus();
      widget.searchController.clear();
      audioSignal.searchQuery.value = '';
    }
  }

  /// Derive a display title from the current route.
  String _getPageTitle(String route) {
    if (route == '/') return 'Home';
    if (route == '/songs') return 'Songs';
    if (route == '/search') return 'Search';
    if (route == '/library') return 'Library';
    if (route == '/explorer') return 'Folders';
    if (route == '/recently-played') return 'Recently Played';
    if (route == '/recently-added') return 'Recently Added';
    if (route == '/settings') return 'Settings';
    if (route == '/settings/appearance') return 'Appearance';
    if (route == '/settings/playback') return 'Playback';
    if (route == '/settings/library') return 'Library';
    if (route == '/settings/about') return 'About';
    if (route == '/settings/appearance/actions-layout') return 'Actions Layout';
    if (route.startsWith('/explorer/')) return 'Folders';
    if (route.startsWith('/playlist/')) {
      // Try to find playlist name
      final id = route.split('/').last;
      try {
        final playlist = audioSignal.playlists.value.firstWhere(
          (p) => p.id == id,
        );
        return playlist.name;
      } catch (_) {
        return 'Playlist';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Watch((context) {
      final currentRoute = navigationSignal.currentRoute.value;
      final isSearchPage = currentRoute == '/search';
      final titleProgress = audioSignal.headerTitleProgress.value;
      final pageTitle = _getPageTitle(currentRoute);
      final shouldBack =
          currentRoute.startsWith('/settings') ||
          currentRoute == '/songs' ||
          currentRoute.startsWith('/playlist') ||
          currentRoute.startsWith('/playlists') ||
          currentRoute == '/recently-played' ||
          currentRoute == '/recently-added' ||
          currentRoute.startsWith('/explorer');

      // Auto-collapse if we navigate away from search
      if (!isSearchPage && _isSearchExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isSearchExpanded = false;
              _focusNode.unfocus();
            });
          }
        });
      }

      return Container(
        height: 60 + topPadding,
        padding: EdgeInsets.only(top: topPadding, left: 12, right: 12),
        child: Opacity(
          opacity: widget.hideContentOpacity,
          child: IgnorePointer(
            ignoring: widget.expansion > 0.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Default Row: Hamburger/Back + Title
                AnimatedOpacity(
                  opacity: _isSearchExpanded ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          );
                        },
                        child: IconButton(
                          key: ValueKey(shouldBack),
                          onPressed: () {
                            if (shouldBack) {
                              navigationSignal.goBack(context);
                            } else {
                              Scaffold.of(context).openDrawer();
                            }
                          },
                          icon: shouldBack
                              ? Icon(
                                  Icons.arrow_back,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 24,
                                )
                              : FaIcon(
                                  FontAwesomeIcons.bars,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 24,
                                ),
                        ),
                      ),

                      // Morphing page title
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRect(
                          child: AnimatedSlide(
                            offset: Offset(
                              0,
                              1.0 -
                                  (currentRoute.startsWith('/explorer')
                                      ? 1.0
                                      : titleProgress),
                            ),
                            duration: Duration.zero,
                            child: Opacity(
                              opacity: currentRoute.startsWith('/explorer')
                                  ? 1.0
                                  : titleProgress,
                              child: Row(
                                children: [
                                  if (audioSignal.headerArtCover.value !=
                                      null) ...[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        image: DecorationImage(
                                          image: FileImage(
                                            File(
                                              audioSignal.headerArtCover.value!,
                                            ),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      pageTitle,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Space for settings and search which are in the layer above
                      const SizedBox(width: 96),
                    ],
                  ),
                ),

                // Search & Settings Layer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          final offsetAnimation = Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            ),
                          );
                        },
                        child: _isSearchExpanded
                            ? const SizedBox.shrink()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Watch((context) {
                                    final isScanning =
                                        audioSignal.isScanning.value;
                                    if (!isScanning)
                                      return const SizedBox.shrink();

                                    return Watch((context) {
                                      final progress =
                                          audioSignal.scanProgress.value;
                                      return Container(
                                        width: 28,
                                        height: 28,
                                        margin: const EdgeInsets.only(right: 4),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 2,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withValues(alpha: 0.2),
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                            ),
                                            Text(
                                              '${(progress * 100).round()}',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    });
                                  }),
                                  IconButton(
                                    onPressed: _toggleSearch,
                                    icon: FaIcon(
                                      FontAwesomeIcons.magnifyingGlass,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      size: 20,
                                    ),
                                  ),
                                  if (!currentRoute.startsWith('/settings'))
                                    IconButton(
                                      onPressed: () => context.go('/settings'),
                                      icon: FaIcon(
                                        FontAwesomeIcons.gear,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    if (_isSearchExpanded)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: MediaQuery.of(context).size.width - 48,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).extension<AppThemeExtension>()!.headerBarBackground,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              onPressed: () {
                                _toggleSearch();
                                if (navigationSignal.canPopSync) {
                                  navigationSignal.goBack(context);
                                } else {
                                  context.go('/');
                                }
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: widget.searchController,
                                focusNode: _focusNode,
                                onChanged: (value) =>
                                    audioSignal.searchQuery.value = value,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search songs...',
                                  hintStyle: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.38),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.38),
                                ),
                                onPressed: () {
                                  widget.searchController.clear();
                                  audioSignal.searchQuery.value = '';
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
