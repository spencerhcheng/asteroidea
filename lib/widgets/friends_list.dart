import 'package:flutter/material.dart';
import 'friend_item.dart';
import 'friend_request_item.dart';

class FriendsList extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final Function(Map<String, dynamic>) onAcceptRequest;
  final Function(Map<String, dynamic>) onDeclineRequest;
  final Function(Map<String, dynamic>) onRemoveFriend;

  const FriendsList({
    super.key,
    required this.userData,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onRemoveFriend,
  });

  @override
  Widget build(BuildContext context) {
    final friends = userData?['friends'] as List<dynamic>? ?? [];
    final friendRequests = userData?['friendRequests'] as List<dynamic>? ?? [];
    
    if (friends.isEmpty && friendRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No friends yet. Add some friends to get started!',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Friend Requests
        if (friendRequests.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'Friend Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${friendRequests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...friendRequests.map((request) => FriendRequestItem(
            request: request,
            onAccept: () => onAcceptRequest(request),
            onDecline: () => onDeclineRequest(request),
          )),
          const SizedBox(height: 16),
        ],
        
        // Friends List
        if (friends.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'Friends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${friends.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...friends.map((friend) => FriendItem(
            friend: friend,
            onRemove: () => onRemoveFriend(friend),
          )),
        ],
      ],
    );
  }
}