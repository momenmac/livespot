import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';

class MapSearchBar extends StatefulWidget {
  final MapPageController controller;
  final FocusNode? focusNode;

  const MapSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();

    // Listen to focus changes to update the UI if needed
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // When focus is lost, ensure suggestions are hidden
        if (widget.controller.showSuggestions) {
          widget.controller.showSuggestions = false;
          widget.controller.notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    // Only dispose the focus node if we created it internally
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: 40, // Use a positive minimum height
                      ),
                      child: TextField(
                        controller: widget.controller.locationController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDarkMode
                              ? ThemeConstants.darkCardColor
                              : ThemeConstants.lightBackgroundColor,
                          hintText: TextStrings.enterYourLocation,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          // Add a clear button to the text field
                          suffixIcon: widget
                                  .controller.locationController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    widget.controller.locationController
                                        .clear();
                                    widget.controller.showSuggestions = false;
                                    widget.controller.notifyListeners();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          if (widget.controller.debounce?.isActive ?? false) {
                            widget.controller.debounce!.cancel();
                          }
                          widget.controller.debounce =
                              Timer(const Duration(milliseconds: 500), () {
                            widget.controller.fetchSuggestions(value);
                          });
                        },
                        onSubmitted: (value) {
                          widget.controller.onSearch();
                          // Hide keyboard after search submission
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      heroTag: 'search_button',
                      elevation: 0,
                      onPressed: () {
                        widget.controller.onSearch();
                        // Hide keyboard after search button press
                        FocusScope.of(context).unfocus();
                      },
                      child: const Icon(
                        Icons.search,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.controller.showSuggestions)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? ThemeConstants.darkCardColor
                      : ThemeConstants.lightBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  elevation: 5,
                  color: isDarkMode
                      ? ThemeConstants.darkCardColor
                      : ThemeConstants.lightBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.controller.searchSuggestions.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          widget.controller.searchSuggestions[index],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          widget.controller.onSuggestionSelected(
                              widget.controller.searchSuggestions[index]);
                          // Hide keyboard after suggestion selection
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
