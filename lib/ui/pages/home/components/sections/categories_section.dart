import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), // Reduced padding
          child: Text(
            TextStrings.categories,
            style: const TextStyle(
              fontSize: 16, // Slightly smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 38, // Reduced height
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _buildCategoryChip(
                  TextStrings.trendingNow, ThemeConstants.primaryColor, true),
              _buildCategoryChip(TextStrings.war, ThemeConstants.red),
              _buildCategoryChip(TextStrings.politics, ThemeConstants.orange),
              _buildCategoryChip(TextStrings.crime, ThemeConstants.pink),
              _buildCategoryChip(TextStrings.weather, ThemeConstants.yellow),
              _buildCategoryChip(TextStrings.health, ThemeConstants.green),
              _buildCategoryChip(
                  TextStrings.technology, ThemeConstants.primaryColor),
              _buildCategoryChip(TextStrings.economy, ThemeConstants.orange),
              _buildCategoryChip(TextStrings.sports, ThemeConstants.green),
              _buildCategoryChip(
                  TextStrings.entertainment, ThemeConstants.pink),
              _buildCategoryChip(TextStrings.environment, ThemeConstants.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, Color color,
      [bool isSelected = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4), // Reduced padding
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12, // Smaller text
            color: isSelected ? color : ThemeConstants.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: color.withOpacity(0.2),
        side: BorderSide(color: isSelected ? color : ThemeConstants.grey),
        checkmarkColor: color,
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 0), // Reduced padding
        materialTapTargetSize:
            MaterialTapTargetSize.shrinkWrap, // Smaller tap target
        onSelected: (selected) {
          // Handle filter selection
        },
      ),
    );
  }
}
