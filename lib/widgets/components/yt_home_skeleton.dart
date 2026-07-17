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

/// A stateless skeleton/shimmer widget matching the YouTube Music home layout.
/// Renders shimmer placeholders for the mood chip row and three content sections
/// without requiring any shimmer library.
class YtHomeSkeleton extends StatelessWidget {
  const YtHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    const shimmerFraction = 0.3;

    return SliverMainAxisGroup(
      slivers: [
        // Mood chips row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, _) => _SkeletonBox(
                  width: 80,
                  height: 40,
                  borderRadius: 20,
                  baseColor: base,
                  shimmerFraction: shimmerFraction,
                ),
              ),
            ),
          ),
        ),

        // Three content sections
        for (var i = 0; i < 3; i++) ...[
          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: _SkeletonBox(
                width: 140,
                height: 24,
                borderRadius: 4,
                baseColor: base,
                shimmerFraction: shimmerFraction,
              ),
            ),
          ),
          // Horizontal card row
          SliverToBoxAdapter(
            child: SizedBox(
              height: 215,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, _) => _SkeletonCard(
                  baseColor: base,
                  shimmerFraction: shimmerFraction,
                ),
              ),
            ),
          ),
        ],

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

/// A shimmer-loading rectangle.
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final double shimmerFraction;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    required this.baseColor,
    required this.shimmerFraction,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_anim.value - widget.shimmerFraction).clamp(0.0, 1.0),
                _anim.value.clamp(0.0, 1.0),
                (_anim.value + widget.shimmerFraction).clamp(0.0, 1.0),
              ],
              colors: [
                widget.baseColor,
                widget.baseColor.withValues(alpha: 0.5),
                widget.baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A shimmer-loading card: square thumbnail + title line + subtitle line.
class _SkeletonCard extends StatelessWidget {
  final Color baseColor;
  final double shimmerFraction;

  const _SkeletonCard({
    required this.baseColor,
    required this.shimmerFraction,
  });

  @override
  Widget build(BuildContext context) {
    // Use a unique ticker per card so each shimmer is out-of-phase.
    return _UniqueTickerSkeleton(
      builder: (context, anim) {
        final stops = [
          (anim - shimmerFraction).clamp(0.0, 1.0),
          anim.clamp(0.0, 1.0),
          (anim + shimmerFraction).clamp(0.0, 1.0),
        ];
        return SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
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
                ),
              ),
              const SizedBox(height: 8),
              // Title line
              _ShimmerBox(
                width: 120,
                height: 14,
                stops: stops,
                baseColor: baseColor,
              ),
              const SizedBox(height: 4),
              // Subtitle line
              _ShimmerBox(
                width: 80,
                height: 12,
                stops: stops,
                baseColor: baseColor,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final List<double> stops;
  final Color baseColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.stops,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
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
