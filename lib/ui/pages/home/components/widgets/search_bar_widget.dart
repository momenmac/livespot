import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class SearchBarWidget extends SearchDelegate<String> {
  SearchBarWidget()
      : super(
          searchFieldLabel: TextStrings.searchPlaceholder,
          searchFieldStyle: const TextStyle(color: ThemeConstants.black),
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // This would be where you'd show search results
    return Center(
      child: Text('Search results for: $query'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // This would show suggestions as the user types
    return Center(
      child: Text('Type to search...'),
    );
  }
}
