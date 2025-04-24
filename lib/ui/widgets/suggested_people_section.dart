import 'package:flutter/material.dart';

class SuggestedPeopleSection extends StatelessWidget {
  final List<Map<String, dynamic>> suggestedUsers;
  final Function(int) onRemoveUser;

  const SuggestedPeopleSection({
    Key? key,
    required this.suggestedUsers,
    required this.onRemoveUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Suggested People',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: suggestedUsers.length,
            itemBuilder: (context, index) {
              final user = suggestedUsers[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(user['profileImage']),
                          onBackgroundImageError: (_, __) =>
                              const Icon(Icons.person),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '@${user['username']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.all(4),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                        ),
                        onPressed: () => onRemoveUser(index),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
