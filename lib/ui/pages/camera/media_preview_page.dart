import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/camera/unified_camera_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class MediaPreviewPage extends StatefulWidget {
  final String mediaPath;
  final String mediaType; // 'photo' or 'video'
  final Position? position;
  final String? address;
  final DateTime? customDateTime; // Add custom datetime parameter

  const MediaPreviewPage({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.position,
    this.address,
    this.customDateTime, // Add custom datetime parameter
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<String> _additionalMedia = [];
  String _selectedCategory = CategoryUtils.allCategories.first;
  bool _isAnonymous = false;
  bool _isPosting = false;

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

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(File(widget.mediaPath));
    await _videoController!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool _isVideoFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', '3gp']
        .contains(extension);
  }

  Future<void> _addMoreMedia() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: ThemeConstants.darkBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add More Media',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMediaOption(
                    icon: Icons.camera_alt,
                    label: 'Take Photo',
                    onTap: () {
                      Navigator.pop(context);
                      _capturePhoto();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMediaOption(
                    icon: Icons.videocam,
                    label: 'Record Video',
                    onTap: () {
                      Navigator.pop(context);
                      _captureVideo();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeConstants.darkCardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[600]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: ThemeConstants.primaryColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedCameraPage(isAddingMedia: true),
      ),
    );

    if (result != null && result['type'] == 'photo') {
      setState(() {
        _additionalMedia.add(result['path']);
      });
    }
  }

  Future<void> _captureVideo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedCameraPage(isAddingMedia: true),
      ),
    );

    if (result != null && result['type'] == 'video') {
      setState(() {
        _additionalMedia.add(result['path']);
      });
    }
  }

  void _removeAdditionalMedia(int index) {
    setState(() {
      _additionalMedia.removeAt(index);
    });
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: ThemeConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: ThemeConstants.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? ThemeConstants.darkCardColor
            : Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? ThemeConstants.darkCardColor
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: ThemeConstants.primaryColor),
              items: CategoryUtils.allCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Icon(
                        CategoryUtils.getCategoryIcon(category),
                        color: ThemeConstants.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CategoryUtils.getCategoryDisplayName(category),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Status (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
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

  Widget _buildAdditionalMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Additional Media',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton.icon(
              onPressed: _addMoreMedia,
              icon: const Icon(Icons.add, color: ThemeConstants.primaryColor),
              label: const Text(
                'Add More',
                style: TextStyle(color: ThemeConstants.primaryColor),
              ),
            ),
          ],
        ),
        if (_additionalMedia.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? ThemeConstants.darkCardColor
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Add photos or videos to tell a better story',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _additionalMedia.length,
              itemBuilder: (context, index) {
                final mediaPath = _additionalMedia[index];
                final isVideo = _isVideoFile(mediaPath);

                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isVideo
                              ? Stack(
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      color: Colors.black87,
                                      child: const Icon(
                                        Icons.video_library,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Image.file(
                                  File(mediaPath),
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _removeAdditionalMedia(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
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
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]!.withValues(alpha: 0.5)
                : Colors.grey[100]!,
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]!.withValues(alpha: 0.3)
                : Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isAnonymous
                  ? Colors.orange.withValues(alpha: 0.1)
                  : ThemeConstants.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isAnonymous ? Icons.visibility_off : Icons.person,
              color: _isAnonymous ? Colors.orange : ThemeConstants.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAnonymous ? 'Anonymous Post' : 'Public Post',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAnonymous
                      ? 'Your identity will be hidden'
                      : 'Your profile will be visible',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (value) {
              setState(() {
                _isAnonymous = value;
              });
            },
            activeColor: Colors.orange,
            inactiveTrackColor:
                ThemeConstants.primaryColor.withValues(alpha: 0.3),
            inactiveThumbColor: ThemeConstants.primaryColor,
          ),
        ],
      ),
    );
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.position == null) {
      ResponsiveSnackBar.showError(
        context: context,
        message: 'Location is required. Please enable location services.',
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      // Debug logging for event status
      debugPrint(
          '🐛 MediaPreviewPage: Creating post with event status: $_eventStatus');

      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      // Upload main media file
      final String? mainMediaUrl =
          await postsProvider.uploadMedia(widget.mediaPath);
      if (mainMediaUrl == null) {
        throw Exception('Failed to upload main media file');
      }

      // Collect all media URLs (main + additional)
      List<String> allMediaUrls = [mainMediaUrl];

      // Upload additional media files
      for (String additionalMediaPath in _additionalMedia) {
        final String? additionalMediaUrl =
            await postsProvider.uploadMedia(additionalMediaPath);
        if (additionalMediaUrl != null) {
          allMediaUrls.add(additionalMediaUrl);
        }
      }

      // Debug logging before creating post
      debugPrint('🐛 MediaPreviewPage: About to create post with:');
      debugPrint('  - Title: ${_titleController.text.trim()}');
      debugPrint('  - Content: ${_contentController.text.trim()}');
      debugPrint('  - Category: $_selectedCategory');
      debugPrint('  - Event Status: $_eventStatus');
      debugPrint('  - Media URLs: $allMediaUrls');
      debugPrint('  - Anonymous: $_isAnonymous');
      debugPrint(
          '  - Custom DateTime: ${widget.customDateTime?.toIso8601String()}');

      // Create the post with all media URLs
      await postsProvider.createPost(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        latitude: widget.position!.latitude,
        longitude: widget.position!.longitude,
        address: widget.address,
        category: _selectedCategory,
        mediaUrls: allMediaUrls,
        tags: [], // Tags functionality removed
        isAnonymous: _isAnonymous,
        eventStatus: _eventStatus, // Pass the event status to the backend
        createdAt: widget.customDateTime, // Pass custom datetime if provided
      );

      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: 'Post created successfully!',
        );

        // Return to home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('🐛 MediaPreviewPage: Error creating post: $e');
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error creating post: $e',
        );
      }
    } finally {
      setState(() => _isPosting = false);
    }
  }

  Widget _buildMainMediaPreview() {
    if (widget.mediaType == 'video') {
      return _videoController != null && _videoController!.value.isInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                ),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                    color: ThemeConstants.primaryColor),
              ),
            );
    } else {
      // Photo preview
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: Image.file(
              File(widget.mediaPath),
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConstants.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Share',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Media preview
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            width: double.infinity,
            child: _buildMainMediaPreview(),
          ),

          // Form content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      _buildStyledTextField(
                        controller: _titleController,
                        label: 'Title',
                        hint: 'Give your post a catchy title...',
                        icon: Icons.title,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Content field
                      _buildStyledTextField(
                        controller: _contentController,
                        label: 'Description',
                        hint: 'Tell us more about what\'s happening...',
                        icon: Icons.description,
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Category selector
                      _buildCategorySelector(),
                      const SizedBox(height: 24),

                      // Event status section
                      _buildEventStatusSection(),
                      const SizedBox(height: 24),

                      // Additional media section
                      _buildAdditionalMediaSection(),
                      const SizedBox(height: 24),

                      // Privacy section
                      _buildPrivacySection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
