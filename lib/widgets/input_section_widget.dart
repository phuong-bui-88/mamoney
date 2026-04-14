import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/widgets/transaction_type_selector.dart';
import 'package:mamoney/widgets/message_input_field.dart';
import 'package:mamoney/widgets/input_action_buttons.dart';

// Input Section Bottom Widget (everything at the bottom of the screen)
class InputSectionWidget extends StatelessWidget {
  final TextEditingController messageController;
  final TransactionType selectedType;
  final Function(TransactionType) onTypeChanged;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onSendPressed;
  final bool isProcessingImage;
  final bool isSavingTransaction;
  final bool isImporting;
  final bool showSuggestedText;

  const InputSectionWidget({
    required this.messageController,
    required this.selectedType,
    required this.onTypeChanged,
    this.onCameraPressed,
    this.onSendPressed,
    this.isProcessingImage = false,
    this.isSavingTransaction = false,
    this.isImporting = false,
    this.showSuggestedText = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isProcessingImage || isSavingTransaction || isImporting;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200] ?? Colors.grey),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick entry input
          Row(
            children: [
              Expanded(
                child: MessageInputField(
                  controller: messageController,
                  onSubmitted: onSendPressed,
                  isEnabled: !isDisabled,
                ),
              ),
              InputActionButtons(
                onCameraPressed: onCameraPressed,
                onSendPressed: onSendPressed,
                isProcessingImage: isProcessingImage,
                isSavingTransaction: isSavingTransaction,
                isImporting: isImporting,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Transaction Type Selector
          TransactionTypeSelector(
            selectedType: selectedType,
            onTypeChanged: onTypeChanged,
            isEnabled: !isDisabled,
          ),
        ],
      ),
    );
  }
}
