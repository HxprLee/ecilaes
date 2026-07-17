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

import 'package:flutter/material.dart';

/// Shimmer skeleton list rows for the search results screen.
/// Matches the layout of a SongTile: 48x48 square art thumbnail + title + subtitle.
class SearchSkeleton extends StatelessWidget {
  final int itemCount;

  const SearchSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    const shimmerFraction = 0.3;

    return SliverMainAxisGroup(
      slivers: List.generate(
        itemCount,
        (i) => SliverToBoxAdapter(
          child: _SkeletonRow(
            baseColor: base,
            shimmerFraction: shimmerFraction,
            delayIndex: i,
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final Color baseColor;
  final double shimmerFraction;
  final int delayIndex;

  const _SkeletonRow({
    required this.baseColor,
    required this.shimmerFraction,
    required this.delayIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Album art placeholder
          _UniqueTickerSkeleton(
            builder: (context, anim) {
              final stops = [
                (anim - shimmerFraction).clamp(0.0, 1.0),
                anim.clamp(0.0, 1.0),
                (anim + shimmerFraction).clamp(0.0, 1.0),
              ];
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: stops,
                    colors: [
                      baseColor,
                      baseColor.withValues(alpha: 0.5),
                      baseColor,
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerLine(
                  width: 200,
                  height: 14,
                  baseColor: baseColor,
                  shimmerFraction: shimmerFraction,
                  delayIndex: delayIndex,
                ),
                const SizedBox(height: 6),
                _ShimmerLine(
                  width: 120,
                  height: 12,
                  baseColor: baseColor,
                  shimmerFraction: shimmerFraction,
                  delayIndex: delayIndex,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  final Color baseColor;
  final double shimmerFraction;
  final int delayIndex;

  const _ShimmerLine({
    required this.width,
    required this.height,
    required this.baseColor,
    required this.shimmerFraction,
    required this.delayIndex,
  });

  @override
  Widget build(BuildContext context) {
    return _UniqueTickerSkeleton(
      builder: (context, anim) {
        final stops = [
          (anim - shimmerFraction).clamp(0.0, 1.0),
          anim.clamp(0.0, 1.0),
          (anim + shimmerFraction).clamp(0.0, 1.0),
        ];
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: stops,
              colors: [
                baseColor,
                baseColor.withValues(alpha: 0.5),
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Owns its own AnimationController with a unique ticker so each instance
/// animates out of phase with others, producing a natural staggered shimmer.
class _UniqueTickerSkeleton extends StatefulWidget {
  final Widget Function(BuildContext context, double animValue) builder;

  const _UniqueTickerSkeleton({required this.builder});

  @override
  State<_UniqueTickerSkeleton> createState() => _UniqueTickerSkeletonState();
}

class _UniqueTickerSkeletonState extends State<_UniqueTickerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _anim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => widget.builder(context, _anim.value),
    );
  }
}
