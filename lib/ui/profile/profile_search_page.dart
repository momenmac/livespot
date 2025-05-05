import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/user_profile.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileSearchPage extends StatefulWidget {
  final UserProfileProvider profileProvider;

  const ProfileSearchPage({
    super.key,
    required this.profileProvider,
  });

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isSearching = false;
  bool _isLoading = false;

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

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearchesJson = prefs.getString('recent_profile_searches');

      if (recentSearchesJson != null) {
        final List<dynamic> searches = json.decode(recentSearchesJson);
        setState(() {
          _recentSearches = List<Map<String, dynamic>>.from(searches);
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(UserProfile profile) async {
    try {
      // Create a map with minimal profile data for recent searches
      final searchData = {
        'id': profile.account.id,
        'name': profile.fullName,
        'username': profile.username,
        'profileImage': profile.profilePictureUrl,
      };

      // Add to the start of the list and remove duplicates
      _recentSearches.removeWhere((item) => item['id'] == profile.account.id);
      _recentSearches.insert(0, searchData);

      // Limit to 10 recent searches
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'recent_profile_searches', json.encode(_recentSearches));

      setState(() {});
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_profile_searches');
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();

    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (!_isSearching) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Only search if query has at least 2 characters
    if (query.length >= 2) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Use the UserProfileProvider to search for profiles
        final results = await widget.profileProvider.searchUsers(query);

        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        debugPrint('Error searching for users: $e');
      }
    } else {
      setState(() {
        _searchResults = [];
      });
    }
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
          child: _recentSearches.isEmpty
              ? const Center(
                  child: Text('No recent searches'),
                )
              : ListView.builder(
                  itemCount: _recentSearches.length,
                  itemBuilder: (context, index) {
                    final search = _recentSearches[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: search['profileImage'] != null &&
                                search['profileImage'].isNotEmpty
                            ? NetworkImage(search['profileImage'])
                            : null,
                        child: search['profileImage'] == null ||
                                search['profileImage'].isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(search['name'] ?? 'Unknown'),
                      subtitle: Text('@${search['username'] ?? 'user'}'),
                      onTap: () {
                        // Navigate to profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OtherUserProfilePage(
                              userData: search,
                            ),
                          ),
                        );
                      },
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.length < 2) {
      return const Center(
        child: Text('Type at least 2 characters to search'),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: ThemeConstants.grey),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profile.profilePictureUrl),
            child: profile.profilePictureUrl.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Row(
            children: [
              Text(profile.fullName),
              if (profile.isVerified)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.verified,
                    size: 16,
                    color: ThemeConstants.primaryColor,
                  ),
                ),
            ],
          ),
          subtitle: Text('@${profile.username}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () async {
            // Add to recent searches
            await _saveRecentSearch(profile);

            // Convert to the format expected by OtherUserProfilePage
            final userData = {
              'id': profile.account.id,
              'name': profile.fullName,
              'username': profile.username,
              'profileImage': profile.profilePictureUrl,
              'bio': profile.bio,
              'location': profile.location,
              'honesty': profile.honestyScore,
              'followers': profile.followersCount,
              'following': profile.followingCount,
              'joinDate': profile.joinDateFormatted,
              'posts': profile.postsCount,
              'comments': profile.commentsCount,
              'saved': profile.savedPostsCount,
              'upvoted': profile.upvotedPostsCount,
              'activityStatus': profile.activityStatusStr,
            };

            if (mounted) {
              // Navigate to profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OtherUserProfilePage(
                    userData: userData,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
