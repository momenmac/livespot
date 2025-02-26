import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  final List<CategoryItem>? subCategories;

  const CategoryItem({
    required this.name,
    required this.icon,
    this.subCategories,
  });

  // Override equals to compare category items properly
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          icon == other.icon;

  @override
  int get hashCode => name.hashCode ^ icon.hashCode;
}

class MapCategories extends StatefulWidget {
  final Function(List<CategoryItem>) onCategorySelected;

  // Sample categories - using text constants
  static final List<CategoryItem> mainCategories = [
    CategoryItem(name: TextStrings.following, icon: Icons.people_outline),
    CategoryItem(name: TextStrings.events, icon: Icons.event_available),
    CategoryItem(name: TextStrings.food, icon: Icons.restaurant_outlined),
    CategoryItem(name: TextStrings.shopping, icon: Icons.shopping_bag_outlined),
    CategoryItem(name: TextStrings.hotels, icon: Icons.hotel_outlined),
    CategoryItem(
        name: TextStrings.entertainment, icon: Icons.attractions_outlined),
  ];

  // Important categories using text constants
  static final CategoryItem mainCategoriesGroup = CategoryItem(
    name: TextStrings.mainCategories,
    icon: Icons.category,
    subCategories: mainCategories,
  );

  // Additional categories using text constants
  static final List<CategoryItem> additionalCategories = [
    CategoryItem(
      name: TextStrings.activities,
      icon: Icons.local_activity,
      subCategories: [
        CategoryItem(name: TextStrings.sports, icon: Icons.sports),
        CategoryItem(name: TextStrings.arts, icon: Icons.palette),
        CategoryItem(name: TextStrings.music, icon: Icons.music_note),
      ],
    ),
    CategoryItem(
      name: TextStrings.places,
      icon: Icons.place,
      subCategories: [
        CategoryItem(name: TextStrings.parks, icon: Icons.park),
        CategoryItem(name: TextStrings.museums, icon: Icons.museum),
        CategoryItem(name: TextStrings.libraries, icon: Icons.local_library),
      ],
    ),
    // Add more categories as needed
  ];

  // Combined categories for the More dialog
  static final List<CategoryItem> allCategories = [
    mainCategoriesGroup,
    ...additionalCategories,
  ];

  const MapCategories({
    super.key,
    required this.onCategorySelected,
  });

  @override
  State<MapCategories> createState() => _MapCategoriesState();
}

class _MapCategoriesState extends State<MapCategories> {
  // Set of selected categories to easily check if a category is selected
  final Set<CategoryItem> _selectedCategories = {};

  // Dynamic list of visible categories in the main view
  final List<CategoryItem> _visibleCategories =
      List.from(MapCategories.mainCategories);

  // Maximum number of visible categories
  final int _maxVisibleCategories = 5;

  void _toggleCategorySelection(CategoryItem category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);

        // If the category is not visible in the main list, promote it
        if (!_visibleCategories.contains(category)) {
          _promoteCategory(category);
        }
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

  void _showCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header section with handle and close button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TextStrings.allCategories,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Row(
                          children: [
                            if (_selectedCategories.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _selectedCategories.clear();
                                    widget.onCategorySelected([]);
                                  });
                                  setState(() {}); // Update main view
                                },
                                child: Text(TextStrings.clearAll),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              iconSize: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Categories list
              Expanded(
                child: ListView.builder(
                  itemCount: MapCategories.allCategories.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final category = MapCategories.allCategories[index];
                    return _buildCategorySection(
                        context, category, setModalState);
                  },
                ),
              ),
              // Apply button at bottom
              if (_selectedCategories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      TextStrings.applyFilters.replaceFirst(
                          '%d', _selectedCategories.length.toString()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
      BuildContext context, CategoryItem category, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            category.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (category.subCategories != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.subCategories!
                .map((subCategory) =>
                    _buildCategoryChip(context, subCategory, setModalState))
                .toList(),
          ),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildCategoryChip(
      BuildContext context, CategoryItem category, StateSetter setModalState) {
    final isSelected = _selectedCategories.contains(category);

    return ActionChip(
      avatar: Icon(
        category.icon,
        size: 18,
        color: isSelected ? Colors.white : null,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.name,
            style: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) const SizedBox(width: 4),
          if (isSelected)
            const Icon(Icons.check, size: 16, color: Colors.white),
        ],
      ),
      backgroundColor: isSelected ? ThemeConstants.primaryColor : null,
      onPressed: () {
        // Update both the parent state and the modal's state
        setModalState(() {
          _toggleCategorySelection(category);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32, // Reduced height
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
                icon: Icon(
                  category.icon,
                  size: 14,
                  color: isSelected ? Colors.white : null,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : null,
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
                      : Theme.of(context).cardColor,
                  foregroundColor: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  elevation: 2,
                  shadowColor: Colors.black26,
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
                          : Colors.grey.withOpacity(0.2),
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
                  : const Icon(Icons.more_horiz, size: 14),
            ),
            label: Text(
              TextStrings.more,
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
              elevation: 2,
              shadowColor: Colors.black26,
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
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
