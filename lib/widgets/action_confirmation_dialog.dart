import 'package:flutter/material.dart';

class ActionConfirmationDialog extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const ActionConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 320,
          maxHeight: 400,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section
            if (imageUrl != null)
              if (imageUrl!.isNotEmpty)
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.image_not_supported,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 32,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

            // Title
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onNo,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    child: Text(
                      'No',
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onYes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Yes',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Static method to show the dialog
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String description,
    String? imageUrl,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ActionConfirmationDialog(
        title: title,
        description: description,
        imageUrl: imageUrl,
        onYes: () => Navigator.of(context).pop(true),
        onNo: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
