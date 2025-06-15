import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_badge.dart';

class NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }
    
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  Widget _buildMessageWithBoldEventName(String message, String notificationType) {
    // For event invitations, make the event name bold
    if (notificationType == 'event_invitation' && message.contains(' invited you to ')) {
      final parts = message.split(' invited you to ');
      if (parts.length == 2) {
        final inviterName = parts[0];
        final eventName = parts[1];
        
        return RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
            children: [
              TextSpan(text: '$inviterName invited you to '),
              TextSpan(
                text: eventName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      }
    }
    
    // For other notification types, check if they contain event names and make them bold
    if (message.contains('"') && message.contains('"')) {
      // Handle messages with quoted event names like: 'joined your event "Event Name"'
      final regex = RegExp(r'(.*)"([^"]+)"(.*)');
      final match = regex.firstMatch(message);
      
      if (match != null) {
        return RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
            children: [
              TextSpan(text: match.group(1)),
              TextSpan(
                text: match.group(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: match.group(3)),
            ],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      }
    }
    
    // Default: return regular text
    return Text(
      message,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[700],
        height: 1.3,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] ?? false;
    final notificationType = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    var message = notification['message'] ?? '';
    final timestamp = notification['timestamp'];
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    
    // Transform old invitation messages to new format
    if (notificationType == 'event_invitation' && message.startsWith('You\'ve been invited to ')) {
      final eventName = message.replaceFirst('You\'ve been invited to ', '');
      final inviterName = data['fromUserName'] ?? 'Someone';
      final firstName = inviterName.split(' ').first;
      message = '$firstName invited you to $eventName';
    }
    
    // Get user info from notification data - handle all possible field names
    final fromUserName = data['fromUserName'] ?? 
                        data['hostName'] ?? 
                        data['participantName'] ?? 
                        data['posterName'] ?? 
                        '';
    
    final fromUserPhotoUrl = data['fromUserPhotoUrl'] ?? 
                            data['hostPhotoUrl'] ?? 
                            data['participantPhotoUrl'] ?? 
                            data['posterPhotoUrl'];
    
    final eventName = data['eventName'] ?? '';
    
    // Debug: Print notification data to understand structure (keep for now)
    if (fromUserPhotoUrl == null) {
      print('DEBUG: No photo URL found in notification. Data keys: ${data.keys.toList()}');
      print('DEBUG: Notification type: $notificationType');
      print('DEBUG: Available data: $data');
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile photo with notification badge
            SizedBox(
              width: 52, // Slightly larger to accommodate badge
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: fromUserPhotoUrl != null && fromUserPhotoUrl.toString().isNotEmpty
                        ? Image.network(
                            fromUserPhotoUrl.toString(),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.person,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                          ),
                  ),
                  ),
                  // Notification type badge
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: NotificationBadge(type: notificationType),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildMessageWithBoldEventName(message, notificationType),
                  
                  // Event context removed from all notifications as requested
                ],
              ),
            ),
            
            // Unread indicator
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}