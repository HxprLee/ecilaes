import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isPlaying;
  final Duration pauseDuration;
  final double pixelsPerSecond;
  final double gap;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.isPlaying = true,
    this.pauseDuration = const Duration(seconds: 5),
    this.pixelsPerSecond = 80.0,
    this.gap = 50.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  bool _isScrolling = false;
  double _textWidth = 0;
  int _animationId = 0;
  double _lastAvailableWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateTextWidth();
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _calculateTextWidth();
      _restartScrolling();
    } else if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _startScrolling();
      } else {
        _stopScrolling();
      }
    }
  }

  void _calculateTextWidth() {
    final textScaler = MediaQuery.textScalerOf(context);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: textScaler,
    )..layout();

    if (_textWidth != textPainter.width) {
      setState(() {
        _textWidth = textPainter.width;
      });
    }
  }

  void _restartScrolling() {
    _animationId++;
    _isScrolling = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _startScrolling();
  }

  @override
  void dispose() {
    _animationId++;
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    if (!mounted || !widget.isPlaying || _isScrolling) return;

    // Wait for layout and attachment
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted || !widget.isPlaying || _isScrolling) return;

    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), _startScrolling);
      return;
    }

    if (_textWidth <= _lastAvailableWidth + 1.0) return;

    _runAnimation(_animationId);
  }

  void _runAnimation(int id) async {
    if (_isScrolling || !mounted || !widget.isPlaying) return;
    _isScrolling = true;

    while (mounted && widget.isPlaying && id == _animationId) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      try {
        // Ensure starting point
        _scrollController.jumpTo(0);

        // Initial pause
        await Future.delayed(widget.pauseDuration);
        if (!mounted || !widget.isPlaying || id != _animationId) break;

        final distance = _textWidth + widget.gap;
        final duration = Duration(
          milliseconds: (distance / widget.pixelsPerSecond * 1000).toInt(),
        );

        // Scroll
        await _scrollController.animateTo(
          distance,
          duration: duration,
          curve: Curves.linear,
        );

        if (!mounted || !widget.isPlaying || id != _animationId) break;

        // Reset instantly for the next loop
        _scrollController.jumpTo(0);
        
        // Wait a tiny bit to make the loop look continuous
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    if (id == _animationId) {
      _isScrolling = false;
    }
  }

  void _stopScrolling() {
    _animationId++;
    _isScrolling = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        if (_lastAvailableWidth != availableWidth) {
          _lastAvailableWidth = availableWidth;
          // Defer to avoid "setState during build"
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_textWidth > availableWidth + 1.0) {
              _startScrolling();
            } else {
              _stopScrolling();
            }
          });
        }

        if (_textWidth <= availableWidth + 1.0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return Container(
          // Clip to avoid text bleeding out
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                Text(widget.text, style: widget.style, maxLines: 1),
                SizedBox(width: widget.gap),
                Text(widget.text, style: widget.style, maxLines: 1),
                SizedBox(width: widget.gap),
              ],
            ),
          ),
        );
      },
    );
  }
}
