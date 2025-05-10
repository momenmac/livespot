import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/category_utils.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  bool isSelected;

  CategoryItem({
    required this.name,
    required this.icon,
    this.isSelected = false,
  });

  // Override equals to compare category items properly
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryItem &&
          runtimeType == other.runtimeType &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

class MapCategories extends StatefulWidget {
  final Function(List<CategoryItem>) onCategorySelected;
  final bool alwaysVisible;

  // Get categories directly from CategoryUtils - no additional groups or subgroups
  static final List<CategoryItem> allCategories = CategoryUtils.allCategories
      .map((category) => CategoryItem(
            name: category,
            icon: CategoryUtils.getCategoryIcon(category),
          ))
      .toList();

  const MapCategories({
    super.key,
    required this.onCategorySelected,
    this.alwaysVisible = true,
  });

  @override
  State<MapCategories> createState() => _MapCategoriesState();
}

class _MapCategoriesState extends State<MapCategories> {
  // Set of selected categories to easily check if a category is selected
  final Set<CategoryItem> _selectedCategories = {};

  // Dynamic list of visible categories in the main view - start with initial list
  late final List<CategoryItem> _visibleCategories =
      List.from(MapCategories.allCategories.take(5).toList());

  // Maximum number of visible categories
  final int _maxVisibleCategories = 5;

  @override
  void initState() {
    super.initState();
    // Reset all isSelected properties to ensure clean state
    for (var category in MapCategories.allCategories) {
      category.isSelected = false;
    }
  }

  void _toggleCategorySelection(CategoryItem category) {
    setState(() {
      // Update the category's isSelected property
      category.isSelected = !category.isSelected;

      if (category.isSelected) {
        _selectedCategories.add(category);

        // If the category is not visible in the main list, promote it
        if (!_visibleCategories.contains(category)) {
          _promoteCategory(category);
        }
      } else {
        _selectedCategories.remove(category);
      }
    });

    // Call the callback with the updated list
    widget.onCategorySelected(_selectedCategories.toList());
  }

  // Promote a category from "More" to the visible list
  void _promoteCategory(CategoryItem category) {
    if (_visibleCategories.length >= _maxVisibleCategories) {
      // Find the first non-selected visible category to replace
      int indexToRemove = _visibleCategories
          .indexWhere((item) => !_selectedCategories.contains(item));

      // If all visible categories are selected, remove the last one
      if (indexToRemove == -1) {
        indexToRemove = _visibleCategories.length - 1;
      }

      _visibleCategories.removeAt(indexToRemove);
    }

    // Add the new category at the beginning for prominence
    _visibleCategories.insert(0, category);
  }

  void _clearAllCategories() {
    setState(() {
      // Clear selection in the selected categories set
      _selectedCategories.clear();

      // Reset isSelected property for all categories
      for (var category in MapCategories.allCategories) {
        category.isSelected = false;
      }

      // Notify parent that no categories are selected
      widget.onCategorySelected([]);
    });
  }

  void _showCategoriesSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height *
              0.5, // Reduced from 0.7 to 0.5
          decoration: BoxDecoration(
            color: isDarkMode
                ? ThemeConstants.darkCardColor.withOpacity(0.95)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)), // More rounded corners
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Sleeker header section with handle and close button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ThemeConstants.primaryColor
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.category,
                                color: ThemeConstants.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              TextStrings.allCategories,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_selectedCategories.isNotEmpty)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _clearAllCategories();
                                    setModalState(() {}); // Update modal state
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Text(
                                      TextStrings.clearAll,
                                      style: TextStyle(
                                        color: ThemeConstants.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              onPressed: () => Navigator.pop(context),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              iconSize: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Modern compact grid with cool animations
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 categories per row
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: MapCategories.allCategories.length,
                    itemBuilder: (context, index) {
                      final category = MapCategories.allCategories[index];
                      final isSelected = category.isSelected;
                      final color =
                          CategoryUtils.getCategoryColor(category.name);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          // Removing the border/outline
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                _toggleCategorySelection(category);
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      category.icon,
                                      color: isSelected ? Colors.white : color,
                                      size: 26, // Increased from 22 to 26
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      CategoryUtils.getCategoryDisplayName(
                                          category.name),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),

                                // Selected indicator
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: color,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.check,
                                          color: color,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Cool floating apply button
              if (_selectedCategories.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                    left: 16,
                    right: 16,
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: ThemeConstants.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: ThemeConstants.primaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _selectedCategories.length.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Apply Filters',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define better colors for dark mode
    final unselectedBackgroundColor =
        isDarkMode ? ThemeConstants.darkCardColor : theme.cardColor;

    final unselectedTextColor = isDarkMode
        ? Colors.white.withOpacity(0.9) // More visible text in dark mode
        : theme.textTheme.bodyLarge?.color;

    final unselectedBorderColor = isDarkMode
        ? Colors.white.withOpacity(0.2) // More visible border in dark mode
        : Colors.grey.withOpacity(0.2);

    return Opacity(
      opacity: widget.alwaysVisible ? 1.0 : 0.9,
      child: Container(
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ..._visibleCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _toggleCategorySelection(category),
                  icon: Icon(category.icon,
                      size: 14, color: isSelected ? Colors.white : null),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CategoryUtils.getCategoryDisplayName(category.name),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isSelected ? Colors.white : unselectedTextColor,
                        ),
                      ),
                      if (isSelected) const SizedBox(width: 4),
                      if (isSelected)
                        const Icon(Icons.check, size: 12, color: Colors.white),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? ThemeConstants.primaryColor
                        : unselectedBackgroundColor,
                    foregroundColor:
                        isSelected ? Colors.white : unselectedTextColor,
                    elevation: 2,
                    shadowColor: isDarkMode ? Colors.black38 : Colors.black26,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isSelected
                            ? ThemeConstants.primaryColor
                            : unselectedBorderColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
            ElevatedButton.icon(
              onPressed: () => _showCategoriesSheet(context),
              icon: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedCategories.isNotEmpty
                      ? ThemeConstants.primaryColor
                      : null,
                ),
                child: _selectedCategories.isNotEmpty
                    ? Center(
                        child: Text(
                          _selectedCategories.length.toString(),
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : Icon(Icons.more_horiz,
                        size: 14,
                        color:
                            isDarkMode ? Colors.white.withOpacity(0.9) : null),
              ),
              label: Text(
                TextStrings.more,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: unselectedBackgroundColor,
                foregroundColor: unselectedTextColor,
                elevation: 2,
                shadowColor: isDarkMode ? Colors.black38 : Colors.black26,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _selectedCategories.isNotEmpty
                        ? ThemeConstants.primaryColor.withOpacity(0.5)
                        : unselectedBorderColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
