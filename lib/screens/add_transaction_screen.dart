import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'add_transaction_view_model.dart';

import 'package:mamoney/widgets/chat_bubble_widget.dart';
import 'package:mamoney/widgets/transaction_card_widget.dart';
import 'package:mamoney/widgets/invoice_widgets.dart';
import 'package:mamoney/widgets/input_section_widget.dart';
import 'package:mamoney/widgets/connectivity_indicator.dart';
import 'package:mamoney/widgets/invoice_import_loading_overlay.dart';
import 'package:mamoney/widgets/image_source_picker_dialog.dart';

import 'package:mamoney/screens/invoice_preview_screen.dart';

import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/connectivity_provider.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AddTransactionViewModel(
        transactionProvider: context.read<TransactionProvider>(),
      )..init(ctx),
      child: const _AddTransactionView(),
    );
  }
}

class _AddTransactionView extends StatelessWidget {
  const _AddTransactionView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddTransactionViewModel>();
    final transactionProvider = context.watch<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        actions: const [ConnectivityIndicator()],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: vm.scrollController,
                  itemCount: vm.messages.length + vm.history.length,
                  itemBuilder: (_, i) {
                    if (i < vm.messages.length) {
                      return ChatBubbleWidget(message: vm.messages[i]);
                    }

                    final item = vm.history[i - vm.messages.length];

                    if (item is InvoiceGroup) {
                      return CompletedInvoiceGroupCard(group: item);
                    }

                    if (item is TransactionRecord) {
                      return Column(
                        children: [
                          ChatBubbleWidget(
                            message: ChatMessage(
                              type: ChatMessageType.user,
                              text: item.userMessage,
                              syncStatus: item.syncStatus,
                            ),
                          ),
                          CompletedTransactionCard(record: item),
                        ],
                      );
                    }

                    return const SizedBox();
                  },
                ),
              ),
              InputSectionWidget(
                messageController: vm.messageController,
                selectedType: vm.selectedType,
                onTypeChanged: (t) {
                  vm.selectedType = t;
                  // Trigger rebuild by notifying listeners
                  vm.notifyListeners();
                },
                onSendPressed: vm.isLoading ? null : vm.handleAI,
                onCameraPressed: vm.isProcessingImage
                    ? null
                    : () {
                        ImageSourcePickerDialog.show(
                          context,
                          onImageSourceSelected: (source) async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: source);
                            if (file == null) return;

                            final preview = await vm.handleInvoice(file);
                            if (preview == null) return;

                            final saved = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoicePreviewScreen(
                                  initialPreviewState: preview,
                                ),
                              ),
                            );

                            if (saved == true) {
                              vm.onInvoiceSaved();
                            }
                          },
                        );
                      },
              ),
            ],
          ),
          if (transactionProvider.isImporting)
            InvoiceImportLoadingOverlay(
              currentStep: transactionProvider.currentImportStep,
              uploadProgress: transactionProvider.uploadProgress,
              processingProgress: transactionProvider.processingProgress,
            ),
        ],
      ),
    );
  }
}
