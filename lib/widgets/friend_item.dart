import 'package:flutter/material.dart';

class FriendItem extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onRemove;

  const FriendItem({
    super.key,
    required this.friend,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: friend['photoUrl'] != null && friend['photoUrl'].isNotEmpty
                ? NetworkImage(friend['photoUrl'])
                : null,
            child: friend['photoUrl'] == null || friend['photoUrl'].isEmpty
                ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (friend['phoneNumber'] != null)
                  Text(
                    friend['phoneNumber'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: () => _showRemoveConfirmation(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Icon(
                Icons.person_remove,
                size: 16,
                color: Colors.red[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Friend'),
          content: Text('Are you sure you want to remove ${friend['name'] ?? 'this person'} from your friends list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRemove();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}