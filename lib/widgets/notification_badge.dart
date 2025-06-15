import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final String type;

  const NotificationBadge({
    super.key,
    required this.type,
  });

  Widget _getNotificationTypeBadge(String type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'friend_request':
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case 'friend_accepted':
        icon = Icons.people;
        color = Colors.green;
        break;
      case 'event_invitation':
        icon = Icons.mail;
        color = Colors.orange;
        break;
      case 'event_update':
        icon = Icons.edit_calendar;
        color = Colors.purple;
        break;
      case 'event_cancelled':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'event_reminder':
        icon = Icons.access_time;
        color = Colors.amber;
        break;
      case 'new_participant':
        icon = Icons.person_add;
        color = Colors.teal;
        break;
      case 'participant_left':
        icon = Icons.person_remove;
        color = Colors.orange;
        break;
      case 'event_message':
        icon = Icons.chat_bubble;
        color = Colors.indigo;
        break;
      case 'new_message':
        icon = Icons.message;
        color = Colors.indigo;
        break;
      case 'user_joined_event':
        icon = Icons.group_add;
        color = Colors.teal;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }
    
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 10,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _getNotificationTypeBadge(type);
  }
}