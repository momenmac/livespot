import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/category_utils.dart';

class CategoryFilterBar extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String? initialCategory;
  final double height;
  final bool showAllOption;

  const CategoryFilterBar({
    super.key,
    required this.onCategorySelected,
    this.initialCategory,
    this.height = 40.0,
    this.showAllOption = true,
  });

  @override
  State<CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<CategoryFilterBar> {
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ??
        (widget.showAllOption ? 'all' : CategoryUtils.allCategories.first);
  }

  @override
  Widget build(BuildContext context) {
    List<String> categories = widget.showAllOption
        ? ['all', ...CategoryUtils.allCategories]
        : CategoryUtils.allCategories;

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;

          // Special handling for 'all' category
          if (category == 'all') {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = 'all');
                  widget.onCategorySelected('all');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apps,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Use the CategoryUtils helper for regular categories
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                widget.onCategorySelected(category);
              },
              child: CategoryUtils.buildCategoryChip(
                category: category,
                includeIcon: true,
                isSelected: isSelected,
                height: widget.height,
              ),
            ),
          );
        },
      ),
    );
  }
}
