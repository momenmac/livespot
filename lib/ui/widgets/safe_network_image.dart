import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final String fallbackText;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.size = 40,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        color: ThemeConstants.primaryColor.withOpacity(0.2),
        child: imageUrl.isEmpty
            ? _buildFallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // On error, show fallback
                  return _buildFallback();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
        style: TextStyle(
          color: ThemeConstants.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}
