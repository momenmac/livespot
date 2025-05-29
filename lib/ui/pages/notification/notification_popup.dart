import 'package:flutter/material.dart';

class NotificationPopup extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Color backgroundColor;
  final Color textColor;

  const NotificationPopup({
    Key? key,
    required this.title,
    required this.message,
    this.icon,
    this.onTap,
    this.onDismiss,
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black87,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Dismiss button
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: Icon(Icons.close,
                              color: textColor.withOpacity(0.6)),
                          onPressed: onDismiss,
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
                        child: Row(
                          children: [
                            if (icon != null) ...[
                              Icon(
                                icon,
                                color: textColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress indicator
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 4),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.transparent,
                              color: textColor.withOpacity(0.2),
                              minHeight: 2,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
