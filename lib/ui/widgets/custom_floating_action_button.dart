import 'package:flutter/material.dart';

/// A wrapper for FloatingActionButton that always includes a unique hero tag.
class CustomFloatingActionButton extends StatelessWidget {
  final String heroTag;
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final MaterialTapTargetSize? tapTargetSize;
  final double? focusElevation;
  final double? hoverElevation;
  final double? highlightElevation;
  final double? disabledElevation;
  final Color? foregroundColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? splashColor;
  final bool? isExtended;
  final String? tooltip;

  const CustomFloatingActionButton({
    super.key,
    required this.heroTag,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.tapTargetSize,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.foregroundColor,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.isExtended,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      foregroundColor: foregroundColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      tooltip: tooltip,
      child: child,
    );
  }

  /// Factory method to create a mini version of the button
  factory CustomFloatingActionButton.small({
    required String heroTag,
    required VoidCallback onPressed,
    required Widget child,
    Color? backgroundColor,
    double elevation = 0,
    Color? foregroundColor,
    ShapeBorder? shape,
  }) {
    return CustomFloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      elevation: elevation,
      foregroundColor: foregroundColor,
      shape: shape,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      child: child,
    );
  }
}
