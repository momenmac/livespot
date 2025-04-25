import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class StoryControlsPage extends StatefulWidget {
  const StoryControlsPage({Key? key}) : super(key: key);

  @override
  State<StoryControlsPage> createState() => _StoryControlsPageState();
}

class _StoryControlsPageState extends State<StoryControlsPage> {
  // State variables for story privacy settings
  String _storyVisibility = 'Public'; // Default visibility
  List<Map<String, dynamic>> _hiddenFromUsers = [];

  // Mock data for muted stories
  final List<Map<String, dynamic>> _mutedStories = [
    {
      'name': 'Jane Smith',
      'username': 'jane_smith',
      'imageUrl': 'https://picsum.photos/seed/jane/100',
      'mutedSince': '2 days ago',
    },
    {
      'name': 'Alex Williams',
      'username': 'alex_will',
      'imageUrl': 'https://picsum.photos/seed/alex/100',
      'mutedSince': '1 week ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Controls'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Who Can See Your Story'),
          _buildVisibilityCard(),
          const SizedBox(height: 16),
          _buildSectionHeader('Stories You\'ve Muted'),
          _buildMutedStoriesCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVisibilityCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: const Text('Public'),
            subtitle: const Text('Anyone can view your story'),
            value: 'Public',
            groupValue: _storyVisibility,
            activeColor: ThemeConstants.primaryColor,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _storyVisibility = value;
                });
              }
            },
          ),
          const Divider(height: 1),
          RadioListTile<String>(
            title: const Text('Friends Only'),
            subtitle: const Text('Only people you follow can view your story'),
            value: 'Friends',
            groupValue: _storyVisibility,
            activeColor: ThemeConstants.primaryColor,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _storyVisibility = value;
                });
              }
            },
          ),
          const Divider(height: 1),
          RadioListTile<String>(
            title: const Text('Custom'),
            subtitle: const Text('Choose who can view your story'),
            value: 'Custom',
            groupValue: _storyVisibility,
            activeColor: ThemeConstants.primaryColor,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _storyVisibility = value;
                });
              }
            },
          ),
          if (_storyVisibility == 'Custom')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hide From (${_hiddenFromUsers.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => _showHideFromSelector(),
                        child: const Text('Select People'),
                      ),
                    ],
                  ),
                  if (_hiddenFromUsers.isNotEmpty)
                    Container(
                      height: 50,
                      alignment: Alignment.centerLeft,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _hiddenFromUsers.length,
                        itemBuilder: (context, index) {
                          final user = _hiddenFromUsers[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              avatar: CircleAvatar(
                                backgroundImage: NetworkImage(user['imageUrl']),
                                backgroundColor: ThemeConstants.greyLight,
                              ),
                              label: Text(user['name']),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _hiddenFromUsers.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMutedStoriesCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: _mutedStories.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('You haven\'t muted any stories'),
            )
          : ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _mutedStories.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _mutedStories[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user['imageUrl']),
                    backgroundColor: ThemeConstants.greyLight,
                    radius: 20,
                  ),
                  title: Text(user['name']),
                  subtitle: Text('@${user['username']}'),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        _mutedStories.removeAt(index);
                      });
                    },
                    child: const Text('Unmute'),
                  ),
                );
              },
            ),
    );
  }

  void _showHideFromSelector() {
    // Mock users for selection
    final List<Map<String, dynamic>> allUsers = List.generate(
      10,
      (index) => {
        'id': index,
        'name': 'User ${index + 1}',
        'username': 'user${index + 1}',
        'imageUrl': 'https://picsum.photos/seed/user$index/100',
        'selected': _hiddenFromUsers.any((element) => element['id'] == index),
      },
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hide Story From',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Apply selections
                              setState(() {
                                _hiddenFromUsers = allUsers
                                    .where((user) => user['selected'] == true)
                                    .map((user) => {
                                          'id': user['id'],
                                          'name': user['name'],
                                          'username': user['username'],
                                          'imageUrl': user['imageUrl'],
                                        })
                                    .toList();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: allUsers.length,
                        itemBuilder: (context, index) {
                          final user = allUsers[index];
                          return CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.trailing,
                            value: user['selected'],
                            onChanged: (value) {
                              setModalState(() {
                                user['selected'] = value;
                              });
                            },
                            secondary: CircleAvatar(
                              backgroundImage: NetworkImage(user['imageUrl']),
                              backgroundColor: ThemeConstants.greyLight,
                            ),
                            title: Text(user['name']),
                            subtitle: Text('@${user['username']}'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
