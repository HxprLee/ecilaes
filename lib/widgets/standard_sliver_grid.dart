import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/audio_signal.dart';

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
    final hasItems = items.isNotEmpty || (leadingItems != null && leadingItems!.isNotEmpty);
    if (!hasItems) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return Watch((context) {
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
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < leadingCount) {
                    return leadingItems![index];
                  }
                  final itemIndex = index - leadingCount;
                  return itemBuilder(context, items[itemIndex], itemIndex);
                },
                childCount: leadingCount + items.length,
              ),
            ),
          ),
          if (addBottomPadding)
            SliverToBoxAdapter(
              child: SizedBox(height: reservedHeight),
            ),
        ],
      );
    });
  }
}
