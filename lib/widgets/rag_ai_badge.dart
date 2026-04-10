import 'package:flutter/material.dart';

class RagAiBadge extends StatelessWidget {
  final double iconSize;
  final double padding;

  const RagAiBadge({
    super.key,
    this.iconSize = 16,
    this.padding = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Posted to RAG AI',
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7C3AED),
              Color(0xFFA78BFA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(padding),
        child: Icon(
          Icons.smart_toy,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
