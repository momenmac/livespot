import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            TextStrings.categories,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _buildCategoryChip(context, TextStrings.trendingNow,
                  ThemeConstants.primaryColor, true),
              _buildCategoryChip(context, TextStrings.war, ThemeConstants.red),
              _buildCategoryChip(
                  context, TextStrings.politics, ThemeConstants.orange),
              _buildCategoryChip(
                  context, TextStrings.crime, ThemeConstants.pink),
              _buildCategoryChip(
                  context, TextStrings.weather, ThemeConstants.yellow),
              _buildCategoryChip(
                  context, TextStrings.health, ThemeConstants.green),
              _buildCategoryChip(
                  context, TextStrings.technology, ThemeConstants.primaryColor),
              _buildCategoryChip(
                  context, TextStrings.economy, ThemeConstants.orange),
              _buildCategoryChip(
                  context, TextStrings.sports, ThemeConstants.green),
              _buildCategoryChip(
                  context, TextStrings.entertainment, ThemeConstants.pink),
              _buildCategoryChip(
                  context, TextStrings.environment, ThemeConstants.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context, String label, Color color,
      [bool isSelected = false]) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Chip background colors based on theme
    final chipBackground = isDarkMode ? theme.cardColor : Colors.white;

    // Border and text colors based on theme and selection state
    final borderColor = isSelected
        ? color
        : (isDarkMode ? theme.dividerColor : ThemeConstants.grey);
    final textColor = isSelected
        ? color
        : (isDarkMode
            ? theme.textTheme.bodyMedium?.color
            : ThemeConstants.black);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: chipBackground,
        selectedColor: color.withOpacity(isDarkMode ? 0.3 : 0.2),
        side: BorderSide(color: borderColor),
        checkmarkColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (selected) {
          // Handle filter selection
        },
      ),
    );
  }
}
