import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoadingImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const ShimmerLoadingImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  State<ShimmerLoadingImage> createState() => _ShimmerLoadingImageState();
}

class _ShimmerLoadingImageState extends State<ShimmerLoadingImage> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Shimmer effect while loading
        if (_isLoading)
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: widget.width,
              height: widget.height,
              color: Colors.white,
            ),
          ),

        // Actual image
        Image.network(
          widget.imageUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              // Image is fully loaded
              if (_isLoading && mounted) {
                // Use post-frame callback to avoid setState during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                });
              }
              return child;
            }
            // Image is still loading, return empty container to show shimmer
            return Container();
          },
          errorBuilder: (context, error, stackTrace) {
            // Use post-frame callback to avoid setState during build
            if (_isLoading && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                  });
                }
              });
            }
            // Return custom error widget if provided, otherwise default error widget
            return widget.errorWidget ??
                Container(
                  width: widget.width,
                  height: widget.height,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                );
          },
        ),
      ],
    );
  }
}
