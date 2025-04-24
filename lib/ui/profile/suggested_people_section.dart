import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/profile/all_profiles_page.dart';

class SuggestedPeopleSection extends StatefulWidget {
  const SuggestedPeopleSection({super.key});

  @override
  State<SuggestedPeopleSection> createState() => _SuggestedPeopleSectionState();
}

class _SuggestedPeopleSectionState extends State<SuggestedPeopleSection> {
  // Updated mock data to match profiles
  final List<Map<String, dynamic>> _suggestedPeople = [
    {
      'name': 'Momen',
      'username': 'momen_dev',
      'profileImage': 'https://picsum.photos/seed/momen/200',
    },
    {
      'name': 'Nopo',
      'username': 'nopo_tech',
      'profileImage': 'https://picsum.photos/seed/nopo/200',
    },
    {
      'name': 'Sarah Chen',
      'username': 'sarah_code',
      'profileImage': 'https://picsum.photos/seed/sarah/200',
    },
    {
      'name': 'Carlos Rodriguez',
      'username': 'carlos_tech',
      'profileImage': 'https://picsum.photos/seed/carlos/200',
    },
    {
      'name': 'Emma Watson',
      'username': 'emma_dev',
      'profileImage': 'https://picsum.photos/seed/emma/200',
    },
    {
      'name': 'Julia Chen',
      'username': 'julia_dev',
      'profileImage': 'https://picsum.photos/seed/julia/200',
    },
    {
      'name': 'Mark Wilson',
      'username': 'mark_tech',
      'profileImage': 'https://picsum.photos/seed/mark/200',
    },
    {
      'name': 'Sophie Brown',
      'username': 'sophie_code',
      'profileImage': 'https://picsum.photos/seed/sophie/200',
    },
  ];

  void _removeUser(int index) {
    // TODO: (DATABASE) Update in database that this suggestion was dismissed
    setState(() {
      _suggestedPeople.removeAt(index);
    });
  }

  void _followUser(int index) {
    // TODO: (DATABASE) Update follow status in database
    // TODO: (DATABASE) Add to user's following list
    // TODO: (DATABASE) Update follower count for both users
    _removeUser(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestedPeople.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // LINE: Above Discover People
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discover People',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllProfilesPage(
                        profiles: _suggestedPeople,
                      ),
                    ),
                  );
                },
                child: Text(
                  'ALL',
                  style: TextStyle(
                    color: ThemeConstants.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // LINE: Below Discover People, above people cards
        SizedBox(
          height: 180, // Fixed height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _suggestedPeople.length,
            itemBuilder: (context, index) {
              final user = _suggestedPeople[index];
              return Container(
                width: 130,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(user['profileImage']),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '@${user['username']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ThemeConstants.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => _followUser(index),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: ThemeConstants.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Follow',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0, // Changed from 0 to -2
                      right: 0, // Changed from 0 to -2
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Theme.of(context).cardTheme.color ??
                            (Theme.of(context).brightness == Brightness.dark
                                ? ThemeConstants.darkCardColor
                                : ThemeConstants.lightCardColor),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () => _removeUser(index),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // LINE: Below people cards, above tabs
        const Divider(),
      ],
    );
  }
}
