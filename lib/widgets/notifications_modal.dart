import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_item.dart';
import '../event_detail.dart';
import '../profile.dart';

class NotificationsModal extends StatelessWidget {
  const NotificationsModal({super.key});

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Handle error silently for now
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> notificationData) {
    final data = notificationData['data'] as Map<String, dynamic>? ?? {};
    final eventId = data['eventId'] as String?;
    final notificationType = notificationData['type'] as String?;
    
    // Close the notifications modal first
    Navigator.of(context).pop();
    
    // Handle different notification types
    if (notificationType == 'friend_request' || notificationType == 'friend_accepted') {
      // Navigate to the profile page for friend-related notifications
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
    } else if (eventId != null) {
      // Navigate to the event detail page for event-related notifications
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EventDetailPage(
            eventId: eventId,
            eventData: {}, // Will be loaded in the page
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('Please sign in to view notifications'),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextButton(
                      onPressed: _markAllAsRead,
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Notifications list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading notifications'),
                  );
                }
                
                final notifications = snapshot.data?.docs ?? [];
                
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ll notify you about events, friends, and more',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final notificationData = notification.data() as Map<String, dynamic>;
                    
                    return NotificationItem(
                      key: ValueKey(notification.id),
                      notification: notificationData,
                      onTap: () {
                        final isRead = notificationData['isRead'] ?? false;
                        if (!isRead) {
                          // First tap: mark as read
                          _markAsRead(notification.id);
                        } else {
                          // Second tap: navigate if it has an eventId
                          _handleNotificationTap(context, notificationData);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}