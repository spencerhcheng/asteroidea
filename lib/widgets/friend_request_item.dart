import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class FriendRequestItem extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FriendRequestItem({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: request['photoUrl'] != null && request['photoUrl'].isNotEmpty
                ? NetworkImage(request['photoUrl'])
                : null,
            child: request['photoUrl'] == null || request['photoUrl'].isEmpty
                ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['name'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (request['phoneNumber'] != null)
                  Text(
                    request['phoneNumber'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton(
                onPressed: onAccept,
                backgroundColor: Colors.green[600],
                child: const Text(
                  'Accept',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                onPressed: onDecline,
                child: Text(
                  'Decline',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}