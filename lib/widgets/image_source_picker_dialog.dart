import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/widgets/invoice_import_loading_overlay.dart';

/// A reusable bottom sheet dialog for selecting an image source (camera or photo library)
class ImageSourcePickerDialog {
  /// Show the image source picker bottom sheet
  /// [onCameraSelected] - Callback when camera option is selected
  /// [onGallerySelected] - Callback when photo library option is selected
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(ImageSource) onImageSourceSelected,
  }) async {
    final provider = context.read<TransactionProvider>();
    provider.setImportStep(InvoiceImportStep.selecting);

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Camera option
                  _ImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      onImageSourceSelected(ImageSource.camera);
                    },
                  ),
                  // Photo Library option
                  _ImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Photo Library',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      onImageSourceSelected(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    provider.clearImportStep();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      provider.clearImportStep();
    });
  }
}

/// Individual image source option button
class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}
