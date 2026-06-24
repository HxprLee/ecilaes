import 'package:flutter/material.dart';

class GridCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget image;
  final VoidCallback onTap;
  final TextAlign textAlign;
  final double borderRadius;

  const GridCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.image,
    required this.onTap,
    this.textAlign = TextAlign.start,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: image,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: textAlign,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: textAlign,
          ),
        ],
      ],
    );
  }
}
