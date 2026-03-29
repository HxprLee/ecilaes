import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../signals/audio_signal.dart';

class StandardSliverList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String emptyMessage;
  final bool addBottomPadding;
  final bool isLoading;
  final Widget? loadingWidget;

  final List<Widget>? leadingItems;

  const StandardSliverList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyMessage = 'No items found',
    this.addBottomPadding = true,
    this.isLoading = false,
    this.loadingWidget,
    this.leadingItems,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: loadingWidget ?? const CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty && (leadingItems == null || leadingItems!.isEmpty)) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            ),
          ),
        ),
      );
    }

    return Watch((context) {
      final reservedHeight = audioSignal.reservedHeight.value;

      return SliverMainAxisGroup(
        slivers: [
          if (leadingItems != null)
            ...leadingItems!.map((w) => SliverToBoxAdapter(child: w)),
          SuperSliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => itemBuilder(context, items[index], index),
              childCount: items.length,
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
