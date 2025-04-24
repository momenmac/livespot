import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';

class ProfileSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> mockProfiles;

  const ProfileSearchPage({
    super.key,
    required this.mockProfiles,
  });

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecentSearches() {
    // TODO: (DATABASE) Load recent searches from local storage or user preferences
    _recentSearches = [
      {'name': 'Momen', 'username': 'momen_dev'},
      {'name': 'Nopo', 'username': 'nopo_tech'},
    ];
  }

  void _clearRecentSearches() {
    // TODO: (DATABASE) Clear recent searches from local storage or user preferences
    setState(() {
      _recentSearches = [];
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _searchResults = widget.mockProfiles.where((profile) {
          final name = profile['name'].toString().toLowerCase();
          final username = profile['username'].toString().toLowerCase();
          return name.contains(query) || username.contains(query);
        }).toList();
      } else {
        _searchResults = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for people...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: ThemeConstants.grey),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                        _searchResults = [];
                      });
                    },
                  )
                : null,
          ),
          autofocus: true,
        ),
      ),
      body: _isSearching ? _buildSearchResults() : _buildRecentSearches(),
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_recentSearches.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Clear'),
                  onPressed: _clearRecentSearches,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.history),
                ),
                title: Text(search['name']),
                subtitle: Text('@${search['username']}'),
                onTap: () {
                  // Navigate to profile
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profile['profileImage']),
            onBackgroundImageError: (_, __) => const Icon(Icons.person),
          ),
          title: Text(profile['name']),
          subtitle: Text('@${profile['username']}'),
          onTap: () {
            // Add to recent searches
            setState(() {
              _recentSearches.insert(0, {
                'name': profile['name'],
                'username': profile['username'],
              });
            });
            // TODO: Save recent searches to local storage

            // Navigate to profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtherUserProfilePage(
                  userData: profile,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
