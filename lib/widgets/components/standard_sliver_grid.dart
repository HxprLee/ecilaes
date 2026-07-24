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
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';

class StandardSliverGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final bool addBottomPadding;

  final List<Widget>? leadingItems;

  const StandardSliverGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.maxCrossAxisExtent = 200,
    this.mainAxisSpacing = 24,
    this.crossAxisSpacing = 24,
    this.childAspectRatio = 0.8,
    this.addBottomPadding = true,
    this.leadingItems,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems =
        items.isNotEmpty || (leadingItems != null && leadingItems!.isNotEmpty);
    if (!hasItems) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SignalBuilder(builder: (context) {
      final reservedHeight = audioSignal.reservedHeight.value;
      final leadingCount = leadingItems?.length ?? 0;

      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxCrossAxisExtent,
                mainAxisSpacing: mainAxisSpacing,
                crossAxisSpacing: crossAxisSpacing,
                childAspectRatio: childAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index < leadingCount) {
                  return leadingItems![index];
                }
                final itemIndex = index - leadingCount;
                return itemBuilder(context, items[itemIndex], itemIndex);
              }, childCount: leadingCount + items.length),
            ),
          ),
          if (addBottomPadding)
            SliverToBoxAdapter(child: SizedBox(height: reservedHeight)),
        ],
      );
    });
  }
}
