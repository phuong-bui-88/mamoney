import 'package:flutter/material.dart';

/// Text input field for transaction messages
class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final bool isEnabled;

  const MessageInputField({
    required this.controller,
    this.onSubmitted,
    this.isEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100] ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[300] ?? Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'e.g., "va xe 30k"',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        maxLines: 1,
        enabled: isEnabled,
        onSubmitted: isEnabled ? (_) => onSubmitted?.call() : null,
      ),
    );
  }
}
