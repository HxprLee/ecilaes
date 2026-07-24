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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/navigation_signal.dart';

class DebugNavOverlay extends StatefulWidget {
  const DebugNavOverlay({super.key});

  @override
  State<DebugNavOverlay> createState() => _DebugNavOverlayState();
}

class _DebugNavOverlayState extends State<DebugNavOverlay> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    // Belt-and-suspenders: main.dart already wraps this in a kDebugMode
    // guard, but if DebugNavOverlay is ever mounted by another widget we
    // still want a no-op in release/profile builds.
    if (!kDebugMode) return const SizedBox.shrink();

    return SignalBuilder(builder: (context) {
      // Hide while the morphing player is expanded so the panel doesn't
      // sit on top of the fullscreen lyrics/queue UI.
      final expanded = audioSignal.playerExpansion.value > 0.5;

      if (!_visible) {
        return Positioned(
          bottom: 16,
          right: 16,
          child: AnimatedOpacity(
            opacity: expanded ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: expanded,
              child: FloatingActionButton.small(
                onPressed: () => setState(() => _visible = true),
                child: const Icon(Icons.bug_report, size: 18),
              ),
            ),
          ),
        );
      }

      return Positioned(
        bottom: 16,
        right: 16,
        child: AnimatedOpacity(
          opacity: expanded ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: expanded,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 320,
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.navigation, size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        const Text(
                          'Route History',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _visible = false),
                          icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Colors.white24),
                    const SizedBox(height: 8),
                    _buildCurrentRoute(),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Colors.white24),
                    const SizedBox(height: 8),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCurrentRoute() {
    return SignalBuilder(builder: (context) {
      final back = navigationSignal.backStack;
      final currentRoute = back.isNotEmpty ? back.last : '(none)';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Route',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 2),
          SelectableText(
            currentRoute,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    });
  }

  Widget _buildHistoryList() {
    return SignalBuilder(builder: (context) {
      final back = navigationSignal.backStack;
      final forward = navigationSignal.forwardStack;

      final items = <Widget>[
        if (forward.isNotEmpty) ...[
          const Text(
            'Forward Stack',
            style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...forward.reversed.map((r) => _routeTile(r, Colors.green.shade700)),
          const SizedBox(height: 8),
        ],
        const Text(
          'Back Stack',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (back.isEmpty)
          const Text(
            '(empty)',
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          )
        else
          ...back.asMap().entries.map((e) {
            final isCurrent = e.key == back.length - 1;
            return _routeTile(
              '${e.key}: ${e.value}',
              isCurrent ? Colors.amber : Colors.white60,
              bold: isCurrent,
            );
          }),
      ];

      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: items,
          ),
        ),
      );
    });
  }

  Widget _routeTile(String label, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
