import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/user_profile.dart';
import 'package:flutter_application_2/models/account.dart';
import 'package:flutter_application_2/models/jwt_token.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/services/api/account/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _currentUserProfile;
  final Map<int, UserProfile> _profileCache = {};
  final AccountProvider _accountProvider;
  bool _isLoading = false;
  String? _error;

  // Constructor
  UserProfileProvider({
    required AccountProvider accountProvider,
  }) : _accountProvider = accountProvider {
    // Initialize by loading cached profile data
    _loadCachedCurrentProfile();

    // Listen to account changes and update profile accordingly
    _accountProvider.addListener(_handleAccountChange);
  }

  // Getters
  UserProfile? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get a cached profile by ID, or null if not cached
  UserProfile? getCachedProfile(int userId) => _profileCache[userId];

  // Handle account changes (login/logout)
  void _handleAccountChange() {
    final account = _accountProvider.currentUser;
    if (account == null) {
      // User logged out, clear current profile
      _currentUserProfile = null;
      notifyListeners();
    } else if (_currentUserProfile == null ||
        _currentUserProfile!.account.id != account.id) {
      // Different user logged in, fetch their profile
      fetchCurrentUserProfile();
    }
  }

  // Load cached profile data from SharedPreferences
  Future<void> _loadCachedCurrentProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('current_user_profile');

      if (profileJson != null) {
        final profileData = json.decode(profileJson);
        _currentUserProfile = UserProfile.fromJson(profileData);
        notifyListeners();

        developer.log(
            'Loaded cached user profile for ${_currentUserProfile!.username}',
            name: 'UserProfileProvider');
      }
    } catch (e) {
      developer.log('Error loading cached profile: $e',
          name: 'UserProfileProvider');
    }
  }

  // Cache the current user profile to SharedPreferences
  Future<void> _cacheCurrentProfile() async {
    if (_currentUserProfile == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'current_user_profile', json.encode(_currentUserProfile!.toJson()));

      developer.log('Cached current user profile', name: 'UserProfileProvider');
    } catch (e) {
      developer.log('Error caching profile: $e', name: 'UserProfileProvider');
    }
  }

  // Fetch the current user's profile from the server
  Future<void> fetchCurrentUserProfile({bool forceRefresh = true}) async {
    final account = _accountProvider.currentUser;
    if (account == null) {
      _error = 'Not logged in';
      notifyListeners();
      return;
    }

    final token = _accountProvider.token;
    if (token == null) {
      _error = 'No authentication token available';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Always fetch fresh data from the server when forceRefresh is true
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await ApiClient.get(
          '/accounts/profile/?nocache=$timestamp',
          token: token.accessToken);

      developer.log('Fetching current user profile response: $response',
          name: 'UserProfileProvider');

      // Handle nested response structure - extract the actual profile data
      Map<String, dynamic> profileData;
      if (response['success'] == true && response.containsKey('data')) {
        var data = response['data'];

        // Check if data is nested another level deep
        if (data is Map &&
            data.containsKey('success') &&
            data.containsKey('data')) {
          developer.log('Detected nested data structure in API response',
              name: 'UserProfileProvider');
          profileData = data['data'];
        } else {
          profileData = data;
        }

        // Add the account data to the profile data if it's not already included
        if (!profileData.containsKey('account')) {
          profileData['account'] = account.toJson();
        }

        _currentUserProfile = UserProfile.fromJson(profileData);

        // Cache the profile data for offline use
        _profileCache[account.id] = _currentUserProfile!;
        await _cacheCurrentProfile();

        developer.log(
            'Fetched fresh profile data for: ${_currentUserProfile!.username}',
            name: 'UserProfileProvider');
      } else {
        // If the profile doesn't exist yet on the server, create a basic one from account
        _currentUserProfile = _createBasicProfileFromAccount(account);

        // Create profile on the server
        await _createProfileOnServer(_currentUserProfile!, token);
      }
    } catch (e) {
      _error = 'Failed to load profile: ${e.toString()}';
      developer.log('Error fetching user profile: $e',
          name: 'UserProfileProvider');

      // Fallback to creating a profile from the account if no server data
      _currentUserProfile ??= _createBasicProfileFromAccount(account);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create user profile on the server
  Future<bool> _createProfileOnServer(
      UserProfile profile, JwtToken token) async {
    // Prepare data, ensuring nullable fields are handled properly
    final data = {
      'username': profile.username,
      'bio': profile.bio,
      'location': profile.location,
      'website': profile.website ?? '', // Send empty string instead of null
      'interests': profile.interests ?? [], // Send empty list instead of null
    };

    developer.log('Creating profile with data: $data',
        name: 'UserProfileProvider');

    try {
      final response = await ApiClient.post(
        '/accounts/users/profile/update/', // Using the correct endpoint for profile updates
        body: data,
        token: token.accessToken,
      );

      developer.log('Profile creation response: $response',
          name: 'UserProfileProvider');

      return response['success'] == true;
    } catch (e) {
      _error = 'Failed to create profile on server: ${e.toString()}';
      developer.log('Error creating profile on server: $e',
          name: 'UserProfileProvider');
      // We still keep the local profile even if server creation fails
      return false;
    }
  }

  // Create a basic profile from account data (fallback when server data unavailable)
  UserProfile _createBasicProfileFromAccount(Account account) {
    return UserProfile(
      account: account,
      username: account.email.split('@')[0], // Basic username from email
      joinDate: account.createdAt ??
          DateTime.now(), // Use current date if createdAt is null
      activityStatus: ActivityStatus.online,
    );
  }

  // Update the current user's profile
  Future<bool> updateCurrentUserProfile({
    String? username,
    String? bio,
    String? location,
    String? website,
    List<String>? interests,
  }) async {
    if (_currentUserProfile == null) {
      _error = 'No profile to update';
      notifyListeners();
      return false;
    }

    final token = _accountProvider.token;
    if (token == null) {
      _error = 'No authentication token available';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Create updated profile data - include all fields to ensure complete update
      final updatedData = {
        'username': username ?? _currentUserProfile!.username,
        'bio': bio ?? _currentUserProfile!.bio,
        'location': location ?? _currentUserProfile!.location,
        'website': website ?? _currentUserProfile!.website ?? '',
        'interests': interests ?? _currentUserProfile!.interests ?? [],
      };

      // Log the request for debugging
      developer.log('Updating profile with data: $updatedData',
          name: 'UserProfileProvider');

      // Make API call to update user profile
      final response = await ApiClient.post(
        '/accounts/users/profile/update/',
        body: updatedData,
        token: token.accessToken,
      );

      // Log the response for debugging
      developer.log('Profile update response: $response',
          name: 'UserProfileProvider');

      if (response['success'] == true) {
        // First update local profile with new data
        _currentUserProfile = _currentUserProfile!.copyWith(
          username: username ?? _currentUserProfile!.username,
          bio: bio ?? _currentUserProfile!.bio,
          location: location ?? _currentUserProfile!.location,
          website: website ?? _currentUserProfile!.website,
          interests: interests ?? _currentUserProfile!.interests,
        );

        // Update cache
        _profileCache[_currentUserProfile!.account.id] = _currentUserProfile!;
        await _cacheCurrentProfile();

        // Force a refresh of the UI
        notifyListeners();
        return true;
      } else if (response['status'] == 404 &&
          (response['error'] != null &&
              response['error'].toString().contains('not found'))) {
        // Profile doesn't exist yet, try creating it first
        developer.log('Profile not found, attempting to create one first',
            name: 'UserProfileProvider');

        // Create profile on the server
        final createSuccess =
            await _createProfileOnServer(_currentUserProfile!, token);

        if (createSuccess) {
          // Now try updating again without recursive call to avoid potential infinite loop
          developer.log(
              'Profile created successfully, now updating with new data directly',
              name: 'UserProfileProvider');

          // Try a direct update with the same data after profile creation
          final directUpdateResponse = await ApiClient.post(
            '/accounts/users/profile/update/',
            body: updatedData,
            token: token.accessToken,
          );

          if (directUpdateResponse['success'] == true) {
            // Update local profile with new data
            _currentUserProfile = _currentUserProfile!.copyWith(
              username: username ?? _currentUserProfile!.username,
              bio: bio ?? _currentUserProfile!.bio,
              location: location ?? _currentUserProfile!.location,
              website: website ?? _currentUserProfile!.website,
              interests: interests ?? _currentUserProfile!.interests,
            );

            // Update cache
            _profileCache[_currentUserProfile!.account.id] =
                _currentUserProfile!;
            await _cacheCurrentProfile();

            notifyListeners();
            return true;
          } else {
            // Fix: Better error handling for structured error responses
            _handleErrorResponse(directUpdateResponse);
            return false;
          }
        } else {
          _error = 'Failed to create user profile';
          return false;
        }
      } else {
        // Fix: Better error handling for structured error responses
        _handleErrorResponse(response);
        return false;
      }
    } catch (e) {
      // Improved error handling
      if (e.toString().contains('FormatException') ||
          e.toString().contains('DOCTYPE')) {
        _error =
            'Server returned an invalid response. Please check your internet connection or try again later.';
        developer.log(
            'Server returned non-JSON response. Possible API endpoint issue or server error.',
            name: 'UserProfileProvider');
      } else {
        _error = 'Error updating profile: ${e.toString()}';
      }

      developer.log(_error!, name: 'UserProfileProvider', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to handle structured error responses
  void _handleErrorResponse(Map<String, dynamic> response) {
    if (response['error'] != null) {
      var error = response['error'];

      // If error is a Map (field-specific errors)
      if (error is Map) {
        StringBuffer errorMsg = StringBuffer('Validation errors: ');
        error.forEach((field, errors) {
          if (errors is List) {
            errorMsg.write('$field: ${errors.join(', ')}. ');
          } else {
            errorMsg.write('$field: $errors. ');
          }
        });
        _error = errorMsg.toString();
      } else {
        // If error is a string
        _error = error.toString();
      }
    } else if (response['message'] != null) {
      _error = response['message'];
    } else {
      _error = 'Failed to update profile: Unknown error';
    }
  }

  // Update profile picture
  Future<bool> updateProfilePicture(String imagePath) async {
    final token = _accountProvider.token;
    final account = _accountProvider.currentUser;

    if (token == null || account == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      developer.log('Uploading profile picture from path: $imagePath',
          name: 'UserProfileProvider');

      // Create multipart request for profile image upload
      final response = await ApiClient.uploadFile(
        '/accounts/profile-image/',
        filePath: imagePath,
        fileField: 'profile_image',
        token: token.accessToken,
      );

      developer.log('Profile picture upload response: $response',
          name: 'UserProfileProvider');

      // Check for success and get the URL from the correct response key
      if (response['success'] == true) {
        // Try different possible key names that might contain the URL
        String? newProfilePictureUrl;
        if (response.containsKey('profile_picture_url')) {
          newProfilePictureUrl = response['profile_picture_url'];
        } else if (response.containsKey('data') && response['data'] is Map) {
          final data = response['data'];
          newProfilePictureUrl = data['profile_picture_url'] ??
              data['avatar_url'] ??
              data['url'] ??
              data['image_url'];

          // If we still don't have a URL, check if the account field is present with profile_picture
          if (newProfilePictureUrl == null && data.containsKey('account')) {
            newProfilePictureUrl = data['account']['profile_picture'];
          }
        }

        // If we found a URL, update the profile
        if (newProfilePictureUrl != null) {
          developer.log('New profile picture URL: $newProfilePictureUrl',
              name: 'UserProfileProvider');

          // Properly update account and profile with new picture URL
          final updatedAccount =
              account.copyWith(profilePictureUrl: newProfilePictureUrl);

          // Update local profile with new picture URL
          if (_currentUserProfile != null) {
            _currentUserProfile = _currentUserProfile!.copyWith(
              account: updatedAccount,
            );

            _profileCache[account.id] = _currentUserProfile!;
            await _cacheCurrentProfile();
          }

          notifyListeners();
          return true;
        } else {
          // Successfully uploaded but couldn't find URL in response
          _error = 'Profile picture uploaded but URL not returned';
          developer.log(_error!, name: 'UserProfileProvider');

          // Force profile refresh to get the updated URL from server
          await refreshCurrentUserProfile();
          return true; // We consider this a success and rely on refresh
        }
      }

      _error = response['error'] ?? 'Failed to update profile picture';
      return false;
    } catch (e) {
      _error = 'Error updating profile picture: ${e.toString()}';
      developer.log(_error!, name: 'UserProfileProvider', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Force refresh profile data from the server
  Future<bool> refreshProfile() async {
    try {
      await refreshCurrentUserProfile();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Refresh the current user's profile without clearing data first
  Future<void> refreshCurrentUserProfile() async {
    final account = _accountProvider.currentUser;
    if (account == null) {
      _error = 'Not logged in';
      notifyListeners();
      return;
    }

    final token = _accountProvider.token;
    if (token == null) {
      _error = 'No authentication token available';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Add cache-busting parameter to ensure we get fresh data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await ApiClient.get(
          '/accounts/profile/?nocache=$timestamp',
          token: token.accessToken);

      developer.log('Refreshing current user profile',
          name: 'UserProfileProvider');

      // Handle nested response structure - extract the actual profile data
      Map<String, dynamic> profileData;
      if (response['success'] == true && response.containsKey('data')) {
        var data = response['data'];

        // Check if data is nested another level deep
        if (data is Map &&
            data.containsKey('success') &&
            data.containsKey('data')) {
          profileData = data['data'];
        } else {
          profileData = data;
        }

        // Create new profile with latest data
        _currentUserProfile = UserProfile.fromJson(profileData);

        // Update cache
        _profileCache[account.id] = _currentUserProfile!;
        await _cacheCurrentProfile();

        developer.log(
            'Refreshed profile data for: ${_currentUserProfile!.username}',
            name: 'UserProfileProvider');
      }
    } catch (e) {
      _error = 'Failed to refresh profile: ${e.toString()}';
      developer.log(_error!, name: 'UserProfileProvider', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch followers for the current user
  Future<List<UserProfile>> getFollowers(
      {int limit = 20, int offset = 0}) async {
    if (_currentUserProfile == null) return [];

    final token = _accountProvider.token;
    if (token == null) return [];

    try {
      final response = await ApiClient.get(
        '/accounts/users/${_currentUserProfile!.account.id}/followers/?limit=$limit&offset=$offset',
        token: token.accessToken,
      );

      developer.log('Get followers response: $response',
          name: 'UserProfileProvider');

      if (response['success'] == true && response.containsKey('data')) {
        var data = response['data'];
        
        // Check if data is nested another level deep
        if (data is Map && data.containsKey('success') && data.containsKey('data')) {
          developer.log('Detected nested data structure in followers response', name: 'UserProfileProvider');
          data = data['data'];
        }
        
        // Extract followers from the proper location in the response
        final List<dynamic> followersData;
        if (data is Map && data.containsKey('followers')) {
          followersData = data['followers'] as List;
        } else {
          followersData = [];
          developer.log('No followers found in response', name: 'UserProfileProvider');
        }

        final followers = followersData.map((data) {
          // Make sure account data is included if not already
          if (data is Map &&
              !data.containsKey('account') &&
              data.containsKey('user_id')) {
            data['account'] = {'id': data['user_id']};
          }
          return UserProfile.fromJson(data);
        }).toList();

        // Cache the profiles
        for (var profile in followers) {
          _profileCache[profile.account.id] = profile;
        }

        return followers;
      }
      return [];
    } catch (e) {
      developer.log('Error fetching followers: $e',
          name: 'UserProfileProvider');
      return [];
    }
  }

  // Fetch following for the current user
  Future<List<UserProfile>> getFollowing(
      {int limit = 20, int offset = 0}) async {
    if (_currentUserProfile == null) return [];

    final token = _accountProvider.token;
    if (token == null) return [];

    try {
      final response = await ApiClient.get(
        '/accounts/users/${_currentUserProfile!.account.id}/following/?limit=$limit&offset=$offset',
        token: token.accessToken,
      );

      developer.log('Get following response: $response',
          name: 'UserProfileProvider');

      if (response['success'] == true && response.containsKey('data')) {
        var data = response['data'];
        
        // Check if data is nested another level deep
        if (data is Map && data.containsKey('success') && data.containsKey('data')) {
          developer.log('Detected nested data structure in following response', name: 'UserProfileProvider');
          data = data['data'];
        }
        
        // Extract following from the proper location in the response
        final List<dynamic> followingData;
        if (data is Map && data.containsKey('following')) {
          followingData = data['following'] as List;
        } else {
          followingData = [];
          developer.log('No following users found in response', name: 'UserProfileProvider');
        }

        final following = followingData.map((data) {
          // Make sure account data is included if not already
          if (data is Map &&
              !data.containsKey('account') &&
              data.containsKey('user_id')) {
            data['account'] = {'id': data['user_id']};
          }
          return UserProfile.fromJson(data);
        }).toList();

        // Cache the profiles
        for (var profile in following) {
          _profileCache[profile.account.id] = profile;
        }

        return following;
      }
      return [];
    } catch (e) {
      developer.log('Error fetching following: $e',
          name: 'UserProfileProvider');
      return [];
    }
  }

  // Search for users
  Future<List<Map<String, dynamic>>> searchUsers(String query,
      {int limit = 20, int offset = 0}) async {
    final token = _accountProvider.token;
    if (token == null) return [];

    try {
      developer.log('Searching for users with query: "$query"', name: 'UserProfileProvider');
      
      // Construct the full URL for debugging
      final endpoint = '/accounts/users/search/?q=${Uri.encodeComponent(query)}&limit=$limit&offset=$offset';
      developer.log('Search endpoint: $endpoint', name: 'UserProfileProvider');
      
      final response = await ApiClient.get(
        endpoint,
        token: token.accessToken,
      );

      developer.log('Search users raw response: $response', name: 'UserProfileProvider');

      if (response['success'] == true && response['data'] != null) {
        // Handle the nested response structure
        var data = response['data'];
        
        // Check if data is nested another level deep
        if (data is Map && data.containsKey('success') && data.containsKey('data')) {
          developer.log('Detected nested data structure in search response', name: 'UserProfileProvider');
          data = data['data'];
        }
        
        // Check if 'users' key exists
        if (!data.containsKey('users')) {
          developer.log('No "users" key in response data: $data', name: 'UserProfileProvider');
          return [];
        }
        
        final List<dynamic> usersData = data['users'] as List;
        developer.log('Found ${usersData.length} users', name: 'UserProfileProvider');

        return usersData.map((userData) {
          // Convert each user data into a format that can be used by the UI
          final account = userData['account'] ?? {};
          developer.log('User data: $userData', name: 'UserProfileProvider');
          return {
            'id': account['id'],
            'email': account['email'],
            'name': '${account['first_name'] ?? ''} ${account['last_name'] ?? ''}'.trim(),
            'profileImage': account['profile_picture'],
            'username': userData['username'],
            'bio': userData['bio'] ?? '',
            'location': userData['location'] ?? '',
            'website': userData['website'] ?? '',
            'is_verified': userData['is_verified'] ?? false,
            'followers': userData['followers_count'] ?? 0,
            'following': userData['following_count'] ?? 0,
            'posts': userData['posts_count'] ?? 0,
            'saved': userData['saved_posts_count'] ?? 0,
            'upvoted': userData['upvoted_posts_count'] ?? 0,
            'comments': userData['comments_count'] ?? 0,
            'honesty': userData['honesty_score'] ?? 0,
            'joinDate': userData['join_date'] ?? '',
            'activityStatus': userData['activity_status'] ?? 'offline',
            'interests': userData['interests'] is List ? List<String>.from(userData['interests']) : [],
          };
        }).toList();
      } else {
        developer.log('Search failed or returned no data: $response', name: 'UserProfileProvider');
      }
      return [];
    } catch (e) {
      developer.log('Error searching users: $e', name: 'UserProfileProvider', error: e);
      return [];
    }
  }

  // Follow a user
  Future<bool> followUser(int userId) async {
    final token = _accountProvider.token;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }

    try {
      final response = await ApiClient.post(
        '/accounts/users/$userId/follow/',
        token: token.accessToken,
      );

      developer.log('Follow user response: $response', name: 'UserProfileProvider');

      if (response['success'] == true) {
        // Force refresh profile data after following a user
        await refreshCurrentUserProfile();
        return true;
      }

      _error = response['error'] ?? 'Failed to follow user';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error following user: ${e.toString()}';
      developer.log(_error!, name: 'UserProfileProvider');
      notifyListeners();
      return false;
    }
  }

  // Unfollow a user
  Future<bool> unfollowUser(int userId) async {
    final token = _accountProvider.token;
    if (token == null) {
      _error = 'Not authenticated';
      notifyListeners();
      return false;
    }

    try {
      final response = await ApiClient.post(
        '/accounts/users/$userId/unfollow/',
        token: token.accessToken,
      );

      developer.log('Unfollow user response: $response', name: 'UserProfileProvider');

      if (response['success'] == true) {
        // Force refresh profile data after unfollowing a user
        await refreshCurrentUserProfile();
        return true;
      }

      _error = response['error'] ?? 'Failed to unfollow user';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error unfollowing user: ${e.toString()}';
      developer.log(_error!, name: 'UserProfileProvider');
      notifyListeners();
      return false;
    }
  }

  // Check if the current user follows a user
  Future<bool> checkFollowing(int userId) async {
    final token = _accountProvider.token;
    if (token == null || _currentUserProfile == null) return false;

    try {
      // Get followers of the target user to check if current user is among them
      final response = await ApiClient.get(
        '/accounts/users/$userId/followers/',
        token: token.accessToken,
      );

      if (response['success'] == true && response.containsKey('data')) {
        var data = response['data'];
        
        // Handle nested response structure
        if (data is Map && data.containsKey('success') && data.containsKey('data')) {
          data = data['data'];
        }
        
        // Extract followers from the correct location
        final List<dynamic> followers;
        if (data is Map && data.containsKey('followers')) {
          followers = data['followers'] as List;
          
          // Check if current user's ID is in the followers list
          final currentUserId = _currentUserProfile!.account.id;
          for (var follower in followers) {
            if (follower is Map && 
                follower.containsKey('account') && 
                follower['account'] is Map &&
                follower['account']['id'] == currentUserId) {
              developer.log('User $userId follow status check: true', name: 'OtherUserProfilePage');
              return true;
            }
          }
        }
      }
      
      developer.log('User $userId follow status check: false', name: 'OtherUserProfilePage');
      return false;
    } catch (e) {
      developer.log('Error checking follow status: $e', name: 'UserProfileProvider');
      return false;
    }
  }

  // Fetch another user's profile by ID
  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    final token = _accountProvider.token;
    if (token == null) return null;

    try {
      developer.log('Fetching profile for user ID: $userId', name: 'UserProfileProvider');
      
      // Use a specific endpoint that returns the complete user profile with all fields
      final response = await ApiClient.get(
        '/accounts/users/$userId/profile/',
        token: token.accessToken,
      );

      developer.log('Fetch user profile response: $response', name: 'UserProfileProvider');

      if (response['success'] == true && response.containsKey('data')) {
        var data = response['data'];
        
        // Handle nested response structure
        if (data is Map && data.containsKey('success') && data.containsKey('data')) {
          data = data['data'];
        }
        
        if (data is Map && data.containsKey('user')) {
          data = data['user'];
        }

        // Extract user account data
        final Map<String, dynamic> account = data['account'] ?? {};
        
        // Create a standardized format that matches what OtherUserProfilePage expects
        return {
          'id': account['id'],
          'email': account['email'],
          'name': '${account['first_name'] ?? ''} ${account['last_name'] ?? ''}'.trim(),
          'profileImage': account['profile_picture'],
          'username': data['username'] ?? '',
          'bio': data['bio'] ?? '',
          'location': data['location'] ?? '',
          'website': data['website'] ?? '',
          'is_verified': data['is_verified'] ?? false,
          'followers': data['followers_count'] ?? 0,
          'following': data['following_count'] ?? 0,
          'posts': data['posts_count'] ?? 0,
          'saved': data['saved_posts_count'] ?? 0,
          'upvoted': data['upvoted_posts_count'] ?? 0, 
          'comments': data['comments_count'] ?? 0,
          'honesty': data['honesty_score'] ?? 0,
          'joinDate': data['join_date'] ?? account['created_at']?.toString().split('T')[0] ?? '',
          'activityStatus': data['activity_status'] ?? 'offline',
          'interests': data['interests'] is List ? List<String>.from(data['interests']) : [],
        };
      }
      return null;
    } catch (e) {
      developer.log('Error fetching user profile: $e', name: 'UserProfileProvider');
      return null;
    }
  }

  // Fetch a user profile by ID with fresh data (no caching)
  Future<UserProfile?> fetchUserProfileById(int userId) async {
    final token = _accountProvider.token;
    if (token == null) return null;

    try {
      developer.log('Fetching fresh profile for user ID: $userId',
          name: 'UserProfileProvider');
      
      // Add cache-busting parameter to ensure fresh data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Use the user profile endpoint with nocache parameter
      final response = await ApiClient.get(
        '/accounts/users/$userId/profile/?nocache=$timestamp',
        token: token.accessToken,
      );

      if (response['success'] == true && response.containsKey('data')) {
        var profileData = response['data'];
        
        // Handle nested response structure
        if (profileData is Map && 
            profileData.containsKey('success') && 
            profileData.containsKey('data')) {
          profileData = profileData['data'];
        }
        
        // If we have a 'user' wrapper, extract the user data
        if (profileData is Map && profileData.containsKey('user')) {
          profileData = profileData['user'];
        }

        // Create a UserProfile object from the data
        final userProfile = UserProfile.fromJson(profileData);
        
        // Update the cache with fresh data
        _profileCache[userId] = userProfile;
        
        // Log success for debugging
        developer.log('Successfully fetched fresh profile for user ID: $userId',
            name: 'UserProfileProvider');
            
        // Notify listeners if this is the current user's profile
        if (_currentUserProfile != null && _currentUserProfile!.account.id == userId) {
          _currentUserProfile = userProfile;
          notifyListeners();
        }
            
        return userProfile;
      } else {
        // If we failed to get fresh data but have cached data, return that as fallback
        if (_profileCache.containsKey(userId)) {
          developer.log('Using cached profile for user ID: $userId as fallback',
              name: 'UserProfileProvider');
          return _profileCache[userId];
        }
        
        developer.log('Failed to fetch profile for user ID: $userId: ${response['error'] ?? "Unknown error"}',
            name: 'UserProfileProvider');
        return null;
      }
    } catch (e) {
      developer.log('Error fetching user profile by ID: $e',
          name: 'UserProfileProvider', error: e);
          
      // On error, return cached data if available as fallback
      if (_profileCache.containsKey(userId)) {
        developer.log('Using cached profile for user ID: $userId as fallback after error',
            name: 'UserProfileProvider');
        return _profileCache[userId];
      }
      
      return null;
    }
  }

  // Cleanup
  @override
  void dispose() {
    _accountProvider.removeListener(_handleAccountChange);
    super.dispose();
  }
}
