import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/services/location/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';

class CreatePostPage extends StatefulWidget {
  final int? relatedToPostId; // Add this parameter for related posts

  const CreatePostPage({super.key, this.relatedToPostId});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _pickedImages = [];
  String _selectedCategory = 'general';
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  String? _currentAddress;
  Position? _currentPosition;
  bool _isAnonymous = false; // Add this field to track anonymous posts

  // Event status options (matching backend PostStatus model)
  String? _eventStatus;
  final List<Map<String, dynamic>> _eventStatusOptions = [
    {
      'value': 'happening',
      'label': 'This is currently happening',
      'icon': Icons.play_circle_fill,
      'color': Colors.green
    },
    {
      'value': 'ended',
      'label': 'This has ended',
      'icon': Icons.stop_circle,
      'color': Colors.red
    },
  ];

  final List<Map<String, dynamic>> _categories = [
    {'value': 'general', 'label': 'General', 'icon': Icons.article},
    {'value': 'news', 'label': 'News', 'icon': Icons.newspaper},
    {'value': 'event', 'label': 'Event', 'icon': Icons.event},
    {'value': 'question', 'label': 'Question', 'icon': Icons.help},
    {'value': 'alert', 'label': 'Alert', 'icon': Icons.warning},
    {'value': 'traffic', 'label': 'Traffic', 'icon': Icons.traffic},
    {'value': 'weather', 'label': 'Weather', 'icon': Icons.cloud},
    {'value': 'crime', 'label': 'Crime', 'icon': Icons.local_police},
    {'value': 'community', 'label': 'Community', 'icon': Icons.people},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentAddress();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentAddress() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);

      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();

      if (!mounted) return;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;

        setState(() {
          _currentPosition = position;
          _currentAddress = [
            place.street,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error getting address: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (!mounted) return; // Add mounted check

      if (images.isNotEmpty) {
        setState(() {
          _pickedImages.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (!mounted) return; // Add mounted check

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (!mounted) return; // Add mounted check

      if (image != null) {
        setState(() {
          _pickedImages.add(image);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (!mounted) return; // Add mounted check

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);

        // First, we would upload the images to a server or cloud storage
        // and then get the URLs to store in the post
        List<String> mediaUrls = [];
        for (var image in _pickedImages) {
          // In a real app, you'd upload the image and get a URL
          mediaUrls.add(image.path);
        }

        if (_currentPosition == null) {
          throw Exception('Location is required to create a post');
        }

        final postsProvider =
            Provider.of<PostsProvider>(context, listen: false);

        // Check if we're creating a related post
        if (widget.relatedToPostId != null) {
          // Create a related post
          final post = await postsProvider.createRelatedPost(
            relatedToPostId: widget.relatedToPostId!,
            title: _titleController.text,
            content: _contentController.text,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            address: _currentAddress ??
                "Unknown location", // Provide default if null
            category: _selectedCategory,
            isAnonymous: _isAnonymous, // Add the missing required parameter
            mediaUrls: mediaUrls,
            // Remove tags parameter as it's not needed
          );

          if (!mounted) return;

          if (post != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Related post created successfully!'),
                backgroundColor: ThemeConstants.green,
              ),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Failed to create related post. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Create a regular post
          final post = await postsProvider.createPost(
            title: _titleController.text,
            content: _contentController.text,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            address: _currentAddress ??
                "Unknown location", // Provide default if null
            category: _selectedCategory,
            isAnonymous: _isAnonymous, // Add isAnonymous parameter
            mediaUrls: mediaUrls,
            eventStatus: _eventStatus, // Pass the event status to the backend
            // Remove tags parameter as it's not needed
          );

          if (!mounted) return;

          if (post != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post created successfully!'),
                backgroundColor: ThemeConstants.green,
              ),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create post. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error creating post: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _submitPost,
            icon: const Icon(Icons.send),
            label: const Text('Post'),
            style: TextButton.styleFrom(
              foregroundColor: ThemeConstants.primaryColor,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location info
                    _buildLocationInfoCard(),

                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Content
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter some content';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Category selector
                    _buildCategorySelector(),

                    const SizedBox(height: 16),

                    // Anonymous post toggle
                    SwitchListTile(
                      title: const Text(
                        'Post Anonymously',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text(
                        'Your username will not be shown with this post',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isAnonymous,
                      activeColor: ThemeConstants.primaryColor,
                      onChanged: (value) {
                        setState(() {
                          _isAnonymous = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Event status section
                    _buildEventStatusSection(),

                    const SizedBox(height: 16),

                    // Media picker
                    _buildMediaPicker(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeConstants.primaryColorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                color: ThemeConstants.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentAddress ?? 'Fetching location...',
                    style: TextStyle(
                      color: ThemeConstants.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category['value'];
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = category['value'] as String;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeConstants.primaryColor
                      : ThemeConstants.greyLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : ThemeConstants.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : ThemeConstants.grey,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMediaPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConstants.greyLight,
                  foregroundColor: ThemeConstants.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConstants.primaryColorLight,
                  foregroundColor: ThemeConstants.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_pickedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedImages.length,
              itemBuilder: (context, index) {
                final image = _pickedImages[index];
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(image.path),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Status (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ..._eventStatusOptions.map((option) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _eventStatus =
                      _eventStatus == option['value'] ? null : option['value'];
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _eventStatus == option['value']
                      ? option['color'].withOpacity(0.1)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? ThemeConstants.darkCardColor
                          : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _eventStatus == option['value']
                        ? option['color']
                        : Colors.grey[300]!,
                    width: _eventStatus == option['value'] ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      option['icon'],
                      color: _eventStatus == option['value']
                          ? option['color']
                          : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option['label'],
                        style: TextStyle(
                          color: _eventStatus == option['value']
                              ? option['color']
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black),
                          fontWeight: _eventStatus == option['value']
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
