import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mamoney/services/firebase_service.dart';

class InvoiceImageWidget extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const InvoiceImageWidget({
    required this.imageUrl,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Handle both local and network images
    if (imageUrl.startsWith('local://')) {
      // Local image - fetch from SharedPreferences
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
              future: FirebaseService().getLocalImage(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child:
                          Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Image.memory(
                      snapshot.data!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } else {
      // Network image - use Image.network
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child:
                            Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// Image Preview Dialog
class ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;

  const ImagePreviewDialog({
    required this.imageUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: imageUrl.startsWith('local://')
                ? FutureBuilder<Uint8List?>(
                    future: FirebaseService().getLocalImage(imageUrl),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return InteractiveViewer(
                          child: Image.memory(snapshot.data!),
                        );
                      }
                      return const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(),
                      );
                    },
                  )
                : InteractiveViewer(
                    child: Image.network(imageUrl),
                  ),
          ),
        ),
      ),
    );
  }
}
