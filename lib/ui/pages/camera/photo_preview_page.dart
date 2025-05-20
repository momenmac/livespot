import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPreviewPage extends StatefulWidget {
  final String imagePath;
  final Position? position;
  final String? address;

  const PhotoPreviewPage({
    super.key,
    required this.imagePath,
    this.position,
    this.address,
  });

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _selectedTags = [];
  String _selectedCategory = CategoryUtils.allCategories.first;
  bool _isAnonymous = false;
  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
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
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      // First upload the image
      final String? mediaUrl =
          await postsProvider.uploadMedia(widget.imagePath);

      if (mediaUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Create the post with the uploaded image URL
      await postsProvider.createPost(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        latitude: widget.position!.latitude,
        longitude: widget.position!.longitude,
        address: widget.address,
        category: _selectedCategory,
        mediaUrls: [mediaUrl],
        tags: _selectedTags,
        isAnonymous: _isAnonymous,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('New Post', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _createPost,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: ThemeConstants.primaryColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: ThemeConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview at top
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Image.file(
                File(widget.imagePath),
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // Location indicator
            if (widget.address != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.address!,
                        style: TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Post form
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter a title for your post',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Content/description field
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what\'s in this photo',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: CategoryUtils.allCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                CategoryUtils.getCategoryIcon(category),
                                color: CategoryUtils.getCategoryColor(category),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CategoryUtils.getCategoryDisplayName(category),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              labelText: 'Tags',
                              hintText: 'Add tags',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTag,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConstants.primaryColor,
                            padding: const EdgeInsets.all(15),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Selected tags
                    Wrap(
                      spacing: 8,
                      children: _selectedTags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag),
                          backgroundColor: ThemeConstants.primaryColorLight,
                          labelStyle: const TextStyle(
                              color: ThemeConstants.primaryColor),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Anonymous post option
                    SwitchListTile(
                      title: const Text('Post Anonymously'),
                      subtitle: const Text(
                          'Your name will not be shown on this post'),
                      value: _isAnonymous,
                      activeColor: ThemeConstants.primaryColor,
                      onChanged: (value) {
                        setState(() {
                          _isAnonymous = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
