import 'package:flutter/material.dart';

/// Enum to track the current step in the invoice import process
enum InvoiceImportStep {
  selecting,
  processing,
  uploading,
  saving,
  none,
}

/// A fullscreen modal overlay that displays during invoice import.
/// Shows progressive steps and blocks user interaction until import completes.
class InvoiceImportLoadingOverlay extends StatelessWidget {
  final InvoiceImportStep currentStep;
  final double uploadProgress; // Progress from 0.0 to 1.0 (only used during uploading step)
  final double processingProgress; // Progress from 0.0 to 1.0 (only used during processing step)

  const InvoiceImportLoadingOverlay({
    super.key,
    required this.currentStep,
    this.uploadProgress = 0.0,
    this.processingProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Map steps to display information
    final steps = [
      _ImportStep(
        order: 1,
        label: 'Selecting Image',
        isActive: currentStep == InvoiceImportStep.selecting,
        isCompleted: currentStep != InvoiceImportStep.none &&
            currentStep != InvoiceImportStep.selecting,
      ),
      _ImportStep(
        order: 2,
        label: 'Processing Invoice',
        isActive: currentStep == InvoiceImportStep.processing,
        isCompleted: currentStep == InvoiceImportStep.uploading ||
            currentStep == InvoiceImportStep.saving,
      ),
      _ImportStep(
        order: 3,
        label: 'Uploading Image',
        isActive: currentStep == InvoiceImportStep.uploading,
        isCompleted: currentStep == InvoiceImportStep.saving,
      ),
      _ImportStep(
        order: 4,
        label: 'Saving Transaction',
        isActive: currentStep == InvoiceImportStep.saving,
        isCompleted: false,
      ),
    ];

    return Stack(
      children: [
        // Semi-transparent dark background that blocks interaction
        GestureDetector(
          onTap: () {
            // Prevent interaction with elements behind the overlay
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // Centered loading content
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'Importing Invoice',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Steps list
                Column(
                  children: steps
                      .map((step) => _ImportStepTile(
                            step: step,
                            uploadProgress: currentStep == InvoiceImportStep.uploading
                                ? uploadProgress
                                : 0.0,
                            processingProgress: currentStep == InvoiceImportStep.processing
                                ? processingProgress
                                : 0.0,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Model for import step display data
class _ImportStep {
  final int order;
  final String label;
  final bool isActive;
  final bool isCompleted;

  _ImportStep({
    required this.order,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });
}

/// A single step row in the import process
class _ImportStepTile extends StatelessWidget {
  final _ImportStep step;
  final double uploadProgress; // 0.0 to 1.0, only used for uploading step
  final double processingProgress; // 0.0 to 1.0, only used for processing step

  const _ImportStepTile({
    super.key,
    required this.step,
    this.uploadProgress = 0.0,
    this.processingProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which progress to show and calculate percentage
    final double currentProgress = step.order == 2 ? processingProgress : uploadProgress;
    final int progressPercent = (currentProgress * 100).toInt();
    final bool showProgress = (step.order == 2 && processingProgress > 0) || 
                              (step.order == 3 && uploadProgress > 0);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step indicator: spinner for active, checkmark for completed, number for pending
              SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: step.isActive
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                      : step.isCompleted
                          ? Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 24,
                            )
                          : Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${step.order}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 16),
              // Step label
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: step.isActive
                            ? Theme.of(context).primaryColor
                            : step.isCompleted
                                ? Colors.grey[600]
                                : Colors.grey[600],
                      ),
                    ),
                    // Show percentage during processing or upload
                    if (step.isActive && showProgress)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '$progressPercent%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Progress bar for processing or uploading steps
          if (step.isActive && showProgress)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: currentProgress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
