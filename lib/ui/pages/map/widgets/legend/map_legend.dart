import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class MapLegend extends StatefulWidget {
  const MapLegend({super.key});

  @override
  State<MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<MapLegend> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        // Help button (moved to left)
        Positioned(
          bottom: 16,
          left: 16, // Changed from right to left
          child: FloatingActionButton(
            heroTag: 'help_button',
            onPressed: _toggleExpanded,
            backgroundColor: _isExpanded 
                ? ThemeConstants.primaryColor.withOpacity(0.8)
                : isDarkMode 
                    ? ThemeConstants.darkCardColor 
                    : Colors.white,
            elevation: 4,
            mini: true,
            child: Icon(
              _isExpanded ? Icons.close : Icons.help_outline,
              color: _isExpanded 
                  ? Colors.white 
                  : ThemeConstants.primaryColor,
            ),
          ),
        ),
        
        // Legend Panel
        if (_isExpanded)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                bottom: 70,
                left: 16, // Changed from right to left
                child: Opacity(
                  opacity: _animation.value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * _animation.value),
                    child: _buildLegendPanel(isDarkMode),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
  
  Widget _buildLegendPanel(bool isDarkMode) {
    return Container(
      width: 340, // Increased from 280 to 340
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? ThemeConstants.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeConstants.primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Map Legend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Icons',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Grid of category icons
                  _buildCategoryIconsGrid(),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Special icons section
                  const Text(
                    'Special Icons',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSpecialIconsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryIconsGrid() {
    // Filter out special categories that have custom icons
    final specialCategories = ['casualties', 'explosion', 'military', 'fire'];
    final regularCategories = CategoryUtils.allCategories
        .where((cat) => !specialCategories.contains(cat))
        .toList();
        
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3, // Changed from 2.5 to 3 for better fit in wider panel
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: regularCategories.length,
      itemBuilder: (context, index) {
        final category = regularCategories[index];
        return _buildLegendItem(category);
      },
    );
  }
  
  Widget _buildSpecialIconsList() {
    final specialCategories = ['casualties', 'explosion', 'military', 'fire'];
    
    return Column(
      children: specialCategories.map((category) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildLegendItem(
            category,
            isSpecial: true,
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildLegendItem(String category, {bool isSpecial = false}) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: isSpecial 
              ? CategoryUtils.buildLiveUAMapMarker(category, showShadow: false)
              : Container(
                  decoration: BoxDecoration(
                    color: CategoryUtils.getCategoryColor(category),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      CategoryUtils.getCategoryIcon(category),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            CategoryUtils.getCategoryDisplayName(category),
            style: TextStyle(
              fontSize: isSpecial ? 14 : 12,
              fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}