// This file contains a helper function for building initials avatar
// to be used in the StoryViewerPage

import 'package:flutter/material.dart';

/// Builds an avatar with user initials
Widget buildInitialsAvatar(String username) {
  // Extract initials: up to 2 characters
  String initials = '';
  if (username.isNotEmpty) {
    List<String> nameParts = username.trim().split(RegExp(r'\s+'));
    if (nameParts.isNotEmpty) {
      // First character of first name
      if (nameParts[0].isNotEmpty) {
        initials += nameParts[0][0].toUpperCase();
      }

      // First character of last name (if available)
      if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
        initials += nameParts[1][0].toUpperCase();
      }
    }
  }

  // Default to a single character if we couldn't extract initials
  if (initials.isEmpty && username.isNotEmpty) {
    initials = username[0].toUpperCase();
  }

  // If still empty, use a default
  if (initials.isEmpty) {
    initials = 'U';
  }

  return Text(
    initials,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
  );
}
