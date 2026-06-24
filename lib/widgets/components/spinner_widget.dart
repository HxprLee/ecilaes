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
import '../../theme/app_theme_tokens.dart';

class SpinnerWidget extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String Function(double)? formatValue;
  final double? Function(String)? parseValue;
  final double width;

  const SpinnerWidget({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.formatValue,
    this.parseValue,
    this.width = 48,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.secondary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.sidebarBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpinnerButton(
            icon: Icons.remove,
            onTap: value > min
                ? () {
                    // Small epsilon rounding to avoid 0.999999999
                    final raw = value - step;
                    final rounded = double.parse(raw.toStringAsFixed(4));
                    onChanged(rounded.clamp(min, max));
                  }
                : null,
            accentColor: accentColor,
            isLeft: true,
          ),
          Container(
            width: 1,
            height: 32,
            color: onSurface.withValues(alpha: 0.12),
          ),
          _SpinnerTextField(
            value: value,
            accentColor: accentColor,
            onChanged: (val) {
              final parsed = parseValue != null ? parseValue!(val) : double.tryParse(val);
              if (parsed != null) {
                onChanged(parsed.clamp(min, max));
              }
            },
            formatValue: formatValue,
            width: width,
          ),
          Container(
            width: 1,
            height: 32,
            color: onSurface.withValues(alpha: 0.12),
          ),
          _SpinnerButton(
            icon: Icons.add,
            onTap: value < max
                ? () {
                    final raw = value + step;
                    final rounded = double.parse(raw.toStringAsFixed(4));
                    onChanged(rounded.clamp(min, max));
                  }
                : null,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _SpinnerButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool isLeft;

  const _SpinnerButton({
    required this.icon,
    required this.onTap,
    required this.accentColor,
    this.isLeft = false,
  });

  @override
  State<_SpinnerButton> createState() => _SpinnerButtonState();
}

class _SpinnerButtonState extends State<_SpinnerButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    Color bgColor = Colors.transparent;
    if (enabled) {
      if (_isPressed) {
        bgColor = widget.accentColor.withValues(alpha: 0.18);
      } else if (_isHovered) {
        bgColor = widget.accentColor.withValues(alpha: 0.10);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 38,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.isLeft ? 32 : 0),
              bottomLeft: Radius.circular(widget.isLeft ? 32 : 0),
              topRight: Radius.circular(widget.isLeft ? 0 : 32),
              bottomRight: Radius.circular(widget.isLeft ? 0 : 32),
            ),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color: enabled
                  ? widget.accentColor
                  : widget.accentColor.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinnerTextField extends StatefulWidget {
  final double value;
  final Color accentColor;
  final ValueChanged<String> onChanged;
  final String Function(double)? formatValue;
  final double width;

  const _SpinnerTextField({
    required this.value,
    required this.accentColor,
    required this.onChanged,
    this.formatValue,
    required this.width,
  });

  @override
  State<_SpinnerTextField> createState() => _SpinnerTextFieldState();
}

class _SpinnerTextFieldState extends State<_SpinnerTextField> {
  late TextEditingController _controller;

  String _getFormattedValue(double val) {
    return widget.formatValue != null ? widget.formatValue!(val) : val.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _getFormattedValue(widget.value));
  }

  @override
  void didUpdateWidget(_SpinnerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newValue = _getFormattedValue(widget.value);
    if (_controller.text != newValue) {
      _controller.text = newValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 32,
      child: Center(
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onSubmitted: widget.onChanged,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}