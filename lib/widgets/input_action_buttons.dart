import 'package:flutter/material.dart';

/// Action buttons for input section (Camera and Send)
class InputActionButtons extends StatelessWidget {
  final VoidCallback? onCameraPressed;
  final VoidCallback? onSendPressed;
  final bool isProcessingImage;
  final bool isSavingTransaction;
  final bool isImporting;

  const InputActionButtons({
    this.onCameraPressed,
    this.onSendPressed,
    this.isProcessingImage = false,
    this.isSavingTransaction = false,
    this.isImporting = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isProcessingImage || isSavingTransaction || isImporting;

    return Row(
      children: [
        const SizedBox(width: 8),
        // Camera button for invoice
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
          ),
          child: IconButton(
            onPressed: isDisabled ? null : onCameraPressed,
            icon: const Icon(
              Icons.camera_alt,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button for text input
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          child: IconButton(
            onPressed: isDisabled ? null : onSendPressed,
            icon: const Icon(
              Icons.send,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
