import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;

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
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  final Map<int, bool> _isFollowingMap = {};
  final Map<int, bool> _isLoadingMap = {};
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

  Future<void> _saveRecentSearch(Map<String, dynamic> profile) async {
    try {
      // Create a map with minimal profile data for recent searches
      final searchData = {
        'id': profile['id'],
        'name': profile['name'],
        'username': profile['username'],
        'profileImage': profile['profileImage'],
      };

      // Add to the start of the list and remove duplicates
      _recentSearches.removeWhere((item) => item['id'] == profile['id']);
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

        // Initialize following status for new results
        for (var user in results) {
          final userId = user['id'] as int;
          if (!_isFollowingMap.containsKey(userId)) {
            _isLoadingMap[userId] = true;
            setState(() {}); // Update UI to show loading indicators
            
            // Check actual follow status from server for each user
            try {
              final isFollowing = await widget.profileProvider.checkFollowing(userId);
              if (mounted) {
                setState(() {
                  _isFollowingMap[userId] = isFollowing;
                  _isLoadingMap[userId] = false;
                });
              }
              developer.log('User $userId follow status: $isFollowing', name: 'ProfileSearchPage');
            } catch (e) {
              if (mounted) {
                setState(() {
                  _isFollowingMap[userId] = false;
                  _isLoadingMap[userId] = false;
                });
              }
              developer.log('Error checking follow status for user $userId: $e', name: 'ProfileSearchPage');
            }
          }
        }

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

  Future<void> _toggleFollow(BuildContext context, int userId) async {
    if (_isLoadingMap[userId] == true) return;

    setState(() {
      _isLoadingMap[userId] = true;
    });

    try {
      bool success;
      if (_isFollowingMap[userId] == true) {
        success = await widget.profileProvider.unfollowUser(userId);
        if (success) {
          developer.log('Unfollowed user: $userId', name: 'ProfileSearchPage');
          setState(() {
            _isFollowingMap[userId] = false;
            
            // Update followers count in search results
            for (int i = 0; i < _searchResults.length; i++) {
              if (_searchResults[i]['id'] == userId) {
                _searchResults[i]['followers'] = (_searchResults[i]['followers'] ?? 1) - 1;
                break;
              }
            }
          });
        }
      } else {
        success = await widget.profileProvider.followUser(userId);
        if (success) {
          developer.log('Followed user: $userId', name: 'ProfileSearchPage');
          setState(() {
            _isFollowingMap[userId] = true;
            
            // Update followers count in search results
            for (int i = 0; i < _searchResults.length; i++) {
              if (_searchResults[i]['id'] == userId) {
                _searchResults[i]['followers'] = (_searchResults[i]['followers'] ?? 0) + 1;
                break;
              }
            }
          });
        }
      }

      if (!success && mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: widget.profileProvider.error ?? 'Failed to update follow status',
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMap[userId] = false;
        });
      }
    }
  }

  // Helper method to navigate to user profile
  void _navigateToUserProfile(BuildContext context, Map<String, dynamic> profile) async {
    await _saveRecentSearch(profile);

    if (mounted) {
      // Check if this is the current user's profile
      final profileProvider = widget.profileProvider;
      final currentUserId = profileProvider.currentUserProfile?.account.id;
      final profileId = profile['id'] as int;
      
      if (currentUserId != null && currentUserId == profileId) {
        // Navigate to current user's profile page (which is the parent page)
        Navigator.pop(context);
      } else {
        // Show loading indicator while we fetch fresh data
        final loadingDialog = showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          // Fetch fresh user data from the API instead of using potentially outdated cached data
          final freshUserProfile = await profileProvider.fetchUserProfileById(profileId);
          
          // Dismiss loading dialog
          Navigator.of(context, rootNavigator: true).pop();
          
          if (freshUserProfile != null) {
            // Convert UserProfile object to Map
            final Map<String, dynamic> userData = {
              'id': freshUserProfile.account.id,
              'name': freshUserProfile.account.fullName,
              'username': freshUserProfile.username,
              'email': freshUserProfile.account.email,
              'bio': freshUserProfile.bio,
              'location': freshUserProfile.location,
              'honesty': freshUserProfile.honestyScore,
              'followers': freshUserProfile.followersCount,
              'following': freshUserProfile.followingCount,
              'posts': freshUserProfile.postsCount,
              'joinDate': freshUserProfile.joinDate.toIso8601String(),
              'isVerified': freshUserProfile.isVerified,
              'profileImage': freshUserProfile.profilePictureUrl,
              'coverPhoto': freshUserProfile.coverPhotoUrl,
              'interests': freshUserProfile.interests,
              'website': freshUserProfile.website,
              'isFollowing': await profileProvider.checkFollowing(profileId),
            };
            
            developer.log('Navigating to profile with fresh data: ${userData.toString().substring(0, userData.toString().length > 100 ? 100 : userData.toString().length)}...', 
              name: 'ProfileSearchPage');
            
            // Navigate to other user's profile with fresh data
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtherUserProfilePage(
                  userData: userData,
                ),
              ),
            ).then((_) {
              // Refresh when coming back
              profileProvider.refreshCurrentUserProfile();
            });
          } else {
            // Use the cached data as fallback if we couldn't fetch fresh data
            _navigateWithCachedData(context, profile, profileProvider, profileId);
          }
        } catch (e) {
          // Dismiss loading dialog on error
          Navigator.of(context, rootNavigator: true).pop();
          
          // Log error and use cached data as fallback
          developer.log('Error fetching fresh profile data: $e', name: 'ProfileSearchPage');
          _navigateWithCachedData(context, profile, profileProvider, profileId);
        }
      }
    }
  }
  
  // Helper method to navigate with cached data as fallback
  void _navigateWithCachedData(BuildContext context, Map<String, dynamic> profile, 
      UserProfileProvider profileProvider, int profileId) {
    // Make sure we include all relevant profile data
    final fullProfileData = Map<String, dynamic>.from(profile);
    
    // Add following status
    fullProfileData['isFollowing'] = _isFollowingMap[profileId] ?? false;
    
    // Ensure field names match what OtherUserProfilePage expects
    if (fullProfileData.containsKey('honesty_score')) {
      fullProfileData['honesty'] = fullProfileData['honesty_score'];
    }
    
    // Format the join date properly if it exists
    if (fullProfileData.containsKey('joinDate') && 
        fullProfileData['joinDate'] != null && 
        fullProfileData['joinDate'].toString().isNotEmpty) {
      // Keep as is - it's already in the correct format
    } else if (fullProfileData.containsKey('join_date') && 
               fullProfileData['join_date'] != null && 
               fullProfileData['join_date'].toString().isNotEmpty) {
      // Convert from API format to display format if needed
      fullProfileData['joinDate'] = fullProfileData['join_date'];
    }
    
    developer.log('Navigating to profile with cached data (fallback): ${fullProfileData.toString().substring(0, fullProfileData.toString().length > 100 ? 100 : fullProfileData.toString().length)}...', 
      name: 'ProfileSearchPage');
    
    // Navigate to other user's profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(
          userData: fullProfileData,
        ),
      ),
    ).then((_) {
      // Refresh when coming back
      profileProvider.refreshCurrentUserProfile();
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
                      onTap: () => _navigateToUserProfile(context, search),
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
        final userId = profile['id'] as int;
        final isFollowing = _isFollowingMap[userId] ?? false;
        final isLoading = _isLoadingMap[userId] ?? false;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: profile['profileImage'] != null && 
                            profile['profileImage'].isNotEmpty
                ? NetworkImage(profile['profileImage'])
                : null,
            child: profile['profileImage'] == null || profile['profileImage'].isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Row(
            children: [
              Text(profile['name'] ?? ''),
              if (profile['is_verified'] == true)
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
          subtitle: Text('@${profile['username'] ?? ''}'),
          trailing: SizedBox(
            width: 120, // Increased from 100 to 120
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(  // Added Flexible to allow the container to shrink if needed
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Added to make Row take minimum space needed
                      children: [
                        Icon(Icons.people, size: 16, color: ThemeConstants.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${profile['followers'] ?? 0}',
                          style: TextStyle(fontSize: 12, color: ThemeConstants.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          isFollowing ? Icons.person_remove : Icons.person_add,
                          color: isFollowing ? ThemeConstants.grey : ThemeConstants.primaryColor,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero, // Reduced padding to save space
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: () => _toggleFollow(context, userId),
                      ),
              ],
            ),
          ),
          onTap: () => _navigateToUserProfile(context, profile),
        );
      },
    );
  }
}
