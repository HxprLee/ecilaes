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
        SliverToBoxAdapter(
          child: Watch((context) {
            return SizedBox(height: audioSignal.reservedHeight.value);
          }),
        ),
      ],
    );
  }
}
