import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  static Future<void> acceptFriendRequest(
    Map<String, dynamic> request,
    Function(String, {Color? backgroundColor}) showSnackBar,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Get current user data with error checking
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!currentUserDoc.exists) {
        throw Exception('Current user document does not exist');
      }
      
      final currentUserData = currentUserDoc.data() ?? {};
      
      // Check if they're already friends to prevent duplicates
      final currentFriends = List<Map<String, dynamic>>.from(currentUserData['friends'] ?? []);
      final isAlreadyFriend = currentFriends.any((friend) => friend['uid'] == request['uid']);
      
      if (isAlreadyFriend) {
        // Remove the friend request but don't add duplicate friend
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'friendRequests': FieldValue.arrayRemove([request]),
        });
        showSnackBar('You are already friends with ${request['name']}');
        return;
      }
      
      // Get phone numbers
      final currentUserPhone = currentUserData['phoneNumber']?.toString();
      final requestPhone = request['phoneNumber']?.toString();
      
      // Create friend objects with standardized schema
      final newFriend = <String, dynamic>{
        'uid': request['uid'],
        'name': request['name'] ?? 'Unknown User',
        'addedAt': Timestamp.now(),
      };
      
      // Add optional fields if present
      if (requestPhone?.isNotEmpty == true) {
        newFriend['phoneNumber'] = requestPhone;
      }
      
      final requestPhotoUrl = request['photoUrl']?.toString();
      if (requestPhotoUrl?.isNotEmpty == true) {
        newFriend['photoUrl'] = requestPhotoUrl;
      }
      
      final currentUserAsFriend = <String, dynamic>{
        'uid': user.uid,
        'name': '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}'.trim(),
        'addedAt': Timestamp.now(),
      };
      
      // Add optional fields if present
      if (currentUserPhone?.isNotEmpty == true) {
        currentUserAsFriend['phoneNumber'] = currentUserPhone;
      }
      
      final currentPhotoUrl = currentUserData['photoUrl']?.toString();
      if (currentPhotoUrl?.isNotEmpty == true) {
        currentUserAsFriend['photoUrl'] = currentPhotoUrl;
      }
      
      // Verify the requester user still exists
      final requesterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(request['uid'])
          .get();
          
      if (!requesterDoc.exists) {
        throw Exception('Requester user document no longer exists');
      }
      
      // Add friend to current user and remove request
      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'friends': FieldValue.arrayUnion([newFriend]),
        'friendRequests': FieldValue.arrayRemove([request]),
      }, SetOptions(merge: true));
      
      // Add current user as friend to the requester and remove sent request
      batch.set(FirebaseFirestore.instance.collection('users').doc(request['uid']), {
        'friends': FieldValue.arrayUnion([currentUserAsFriend]),
        'sentFriendRequests': FieldValue.arrayRemove([{
          'uid': user.uid,
          'name': currentUserAsFriend['name'],
          'sentAt': request['createdAt'] // Use the original timestamp
        }]),
      }, SetOptions(merge: true));
      
      await batch.commit();
      
      // Create notification for the person who sent the friend request
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': request['uid'],
        'type': 'friend_accepted',
        'title': 'Friend Request Accepted',
        'message': '${currentUserAsFriend['name']} accepted your friend request',
        'data': {
          'fromUserId': user.uid,
          'fromUserName': currentUserAsFriend['name'],
          'fromUserPhotoUrl': currentPhotoUrl,
        },
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      showSnackBar('Friend request accepted!');
    } catch (e, stackTrace) {
      String errorMessage = 'Failed to accept friend request';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Unable to accept friend request.';
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'User not found. They may have deleted their account.';
      }
      
      showSnackBar(errorMessage, backgroundColor: Colors.red);
    }
  }
  
  static Future<void> declineFriendRequest(
    Map<String, dynamic> request,
    Function(String, {Color? backgroundColor}) showSnackBar,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Remove the friend request from current user
      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'friendRequests': FieldValue.arrayRemove([request]),
      }, SetOptions(merge: true));
      
      // Remove the sent request from the requester's side
      batch.set(FirebaseFirestore.instance.collection('users').doc(request['uid']), {
        'sentFriendRequests': FieldValue.arrayRemove([{
          'uid': user.uid,
          'name': '${request['name']}', // Use requester's stored name
          'sentAt': request['createdAt']
        }]),
      }, SetOptions(merge: true));
      
      await batch.commit();
      
      showSnackBar('Friend request declined');
    } catch (e) {
      showSnackBar('Failed to decline friend request', backgroundColor: Colors.red);
    }
  }

  static Future<void> sendFriendRequest(
    Map<String, dynamic> targetUser,
    Function(String, {Color? backgroundColor}) showSnackBar,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final targetUserId = targetUser['uid'];
    if (targetUserId == null || targetUserId.isEmpty) {
      showSnackBar('Invalid user selected', backgroundColor: Colors.red);
      return;
    }

    try {
      // Get current user data with comprehensive error checking
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!currentUserDoc.exists) {
        throw Exception('Current user document does not exist in Firestore');
      }
      
      final currentUserData = currentUserDoc.data() ?? {};
      
      // Get user data with standardized schema
      final phoneNumber = currentUserData['phoneNumber']?.toString();
      final photoUrl = currentUserData['photoUrl']?.toString();
      
      // Build friend request with standardized schema
      final currentUserRequest = <String, dynamic>{
        'uid': user.uid,
        'name': '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}'.trim(),
        'createdAt': Timestamp.now(),
      };
      
      // Add optional fields if present
      if (phoneNumber?.isNotEmpty == true) {
        currentUserRequest['phoneNumber'] = phoneNumber;
      }
      
      if (photoUrl?.isNotEmpty == true) {
        currentUserRequest['photoUrl'] = photoUrl;
      }
      
      // Verify target user exists before sending request
      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();
          
      if (!targetUserDoc.exists) {
        throw Exception('Target user document does not exist');
      }
      
      // Create the batch operation to handle both users
      final batch = FirebaseFirestore.instance.batch();
      
      // Add friend request to target user
      batch.set(FirebaseFirestore.instance.collection('users').doc(targetUserId), {
        'friendRequests': FieldValue.arrayUnion([currentUserRequest]),
      }, SetOptions(merge: true));
      
      // Track sent request on sender's side to prevent duplicates
      final sentRequest = <String, dynamic>{
        'uid': targetUserId,
        'name': targetUser['name'] ?? 'Unknown User',
        'sentAt': Timestamp.now(),
      };
      
      if (targetUser['phoneNumber']?.toString().isNotEmpty == true) {
        sentRequest['phoneNumber'] = targetUser['phoneNumber'];
      }
      
      if (targetUser['photoUrl']?.toString().isNotEmpty == true) {
        sentRequest['photoUrl'] = targetUser['photoUrl'];
      }
      
      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'sentFriendRequests': FieldValue.arrayUnion([sentRequest]),
      }, SetOptions(merge: true));
      
      await batch.commit();

      // Create notification for the friend request
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': targetUserId,
        'type': 'friend_request',
        'title': 'New Friend Request',
        'message': '${currentUserRequest['name']} sent you a friend request',
        'data': {
          'fromUserId': user.uid,
          'fromUserName': currentUserRequest['name'],
          'fromUserPhotoUrl': photoUrl,
        },
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      showSnackBar('Friend request sent to ${targetUser['name']}');
    } catch (e, stackTrace) {
      // More specific error messages based on error type
      String errorMessage = 'Failed to send friend request';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your account settings.';
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'User not found. They may have deleted their account.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      showSnackBar(errorMessage, backgroundColor: Colors.red);
    }
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final queryLower = query.toLowerCase();
    
    // Get current user data to determine relationships
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final currentUserData = currentUserDoc.data() ?? {};
    final currentFriends = List<Map<String, dynamic>>.from(currentUserData['friends'] ?? []);
    final friendIds = currentFriends.map((f) => f['uid']).toSet();
    
    // Get sent friend requests
    final sentRequests = List<Map<String, dynamic>>.from(currentUserData['sentFriendRequests'] ?? []);
    final sentRequestIds = sentRequests.map((r) => r['uid']).toSet();
    
    // Get received friend requests
    final receivedRequests = List<Map<String, dynamic>>.from(currentUserData['friendRequests'] ?? []);
    final receivedRequestIds = receivedRequests.map((r) => r['uid']).toSet();
    
    // Search users by name or phone number
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    
    final results = usersSnapshot.docs
        .where((doc) {
          final data = doc.data();
          final firstName = (data['firstName'] ?? '').toString().toLowerCase();
          final lastName = (data['lastName'] ?? '').toString().toLowerCase();
          final fullName = '$firstName $lastName';
          
          // Get phone number
          final phoneNumber = data['phoneNumber']?.toString() ?? '';
          
          // Only filter out current user, include all others with relationship status
          return doc.id != user.uid &&
                 (firstName.contains(queryLower) || 
                  lastName.contains(queryLower) ||
                  fullName.contains(queryLower) ||
                  phoneNumber.contains(query)); // Exact match for phone
        })
        .map((doc) {
          final data = doc.data();
          final userId = doc.id;
          
          // Determine relationship status
          String relationshipStatus = 'none';
          if (friendIds.contains(userId)) {
            relationshipStatus = 'friend';
          } else if (sentRequestIds.contains(userId)) {
            relationshipStatus = 'requested';
          } else if (receivedRequestIds.contains(userId)) {
            relationshipStatus = 'pending';
          }
          
          // Get phone number for display
          final displayPhone = data['phoneNumber']?.toString();
          
          return {
            'uid': userId,
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            'phoneNumber': displayPhone,
            'photoUrl': data['photoUrl'],
            'relationshipStatus': relationshipStatus,
          };
        })
        .take(15) // Increased limit to accommodate more results
        .toList();

    return results;
  }

  static Future<void> removeFriend(
    Map<String, dynamic> friendToRemove,
    Function(String, {Color? backgroundColor}) showSnackBar,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Get both user documents to find exact matching friend objects
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      final friendUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendToRemove['uid'])
          .get();
      
      if (!currentUserDoc.exists) {
        throw Exception('Current user document does not exist');
      }
      
      if (!friendUserDoc.exists) {
        throw Exception('Friend user document does not exist');
      }
      
      final currentUserData = currentUserDoc.data() ?? {};
      final friendUserData = friendUserDoc.data() ?? {};
      
      // Find the exact friend object in the friend's friends list that represents current user
      final friendsFriendsList = List<Map<String, dynamic>>.from(friendUserData['friends'] ?? []);
      Map<String, dynamic>? currentUserInFriendsList;
      
      for (final friend in friendsFriendsList) {
        if (friend['uid'] == user.uid) {
          currentUserInFriendsList = friend;
          break;
        }
      }
      
      // Remove friend from current user's friends list (we have the exact object)
      batch.update(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'friends': FieldValue.arrayRemove([friendToRemove]),
      });
      
      // Remove current user from the friend's friends list (using exact object if found)
      if (currentUserInFriendsList != null) {
        batch.update(FirebaseFirestore.instance.collection('users').doc(friendToRemove['uid']), {
          'friends': FieldValue.arrayRemove([currentUserInFriendsList]),
        });
      } else {
        // Fallback: try to create the object structure and remove
        print('Warning: Could not find exact friend object, attempting fallback removal');
        final currentUserAsFriend = <String, dynamic>{
          'uid': user.uid,
          'name': '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}'.trim(),
        };
        
        batch.update(FirebaseFirestore.instance.collection('users').doc(friendToRemove['uid']), {
          'friends': FieldValue.arrayRemove([currentUserAsFriend]),
        });
      }
      
      await batch.commit();
      
      showSnackBar('${friendToRemove['name']} removed from friends');
    } catch (e) {
      print('Error removing friend: $e'); // Debug logging
      String errorMessage = 'Failed to remove friend';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Unable to remove friend.';
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'User not found. They may have deleted their account.';
      }
      
      showSnackBar(errorMessage, backgroundColor: Colors.red);
    }
  }
}