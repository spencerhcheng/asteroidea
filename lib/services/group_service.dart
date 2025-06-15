import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new group (first person to claim name becomes admin)
  static Future<String> createGroup({
    required String name,
    required String description,
    String? logoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if group name already exists
    final existingGroups = await _firestore
        .collection('groups')
        .where('name', isEqualTo: name.trim())
        .get();

    if (existingGroups.docs.isNotEmpty) {
      throw Exception('Group name already exists');
    }

    // Get current user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    // Create group
    final groupData = {
      'name': name.trim(),
      'description': description.trim(),
      'adminId': user.uid,
      'adminName': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
      'logoUrl': logoUrl,
      'members': [user.uid],
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('groups').add(groupData);

    // Add group to user's groups list
    await _firestore.collection('users').doc(user.uid).update({
      'groups': FieldValue.arrayUnion([docRef.id])
    });

    return docRef.id;
  }

  // Request to join a group
  static Future<void> requestToJoinGroup({
    required String groupId,
    String? message,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    // Check if user is already a member
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (groupDoc.exists) {
      final groupData = groupDoc.data()!;
      final members = List<String>.from(groupData['members'] ?? []);
      if (members.contains(user.uid)) {
        throw Exception('You are already a member of this group');
      }
    }

    // Check if request already exists
    final existingRequest = await _firestore
        .collection('groupRequests')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('You already have a pending request for this group');
    }

    // Create join request
    await _firestore.collection('groupRequests').add({
      'groupId': groupId,
      'userId': user.uid,
      'status': 'pending',
      'message': message?.trim() ?? '',
      'requestedAt': FieldValue.serverTimestamp(),
      'userInfo': {
        'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
        'photoUrl': userData['photoUrl'],
        'firstName': userData['firstName'],
        'lastName': userData['lastName'],
      },
    });
  }

  // Admin: Approve a join request
  static Future<void> approveJoinRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.runTransaction((transaction) async {
      // Get the request
      final requestDoc = await transaction.get(
        _firestore.collection('groupRequests').doc(requestId)
      );
      
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final groupId = requestData['groupId'];
      final userId = requestData['userId'];

      // Get the group
      final groupDoc = await transaction.get(
        _firestore.collection('groups').doc(groupId)
      );

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data()!;

      // Check if current user is admin
      if (groupData['adminId'] != user.uid) {
        throw Exception('Only group admin can approve requests');
      }

      // Update request status
      transaction.update(requestDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': user.uid,
      });

      // Add user to group members
      transaction.update(groupDoc.reference, {
        'members': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
      });

      // Add group to user's groups list
      transaction.update(_firestore.collection('users').doc(userId), {
        'groups': FieldValue.arrayUnion([groupId])
      });
    });
  }

  // Admin: Reject a join request
  static Future<void> rejectJoinRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final requestDoc = await _firestore.collection('groupRequests').doc(requestId).get();
    
    if (!requestDoc.exists) {
      throw Exception('Request not found');
    }

    final requestData = requestDoc.data()!;
    final groupId = requestData['groupId'];

    // Check if current user is admin
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (groupDoc.exists) {
      final groupData = groupDoc.data()!;
      if (groupData['adminId'] != user.uid) {
        throw Exception('Only group admin can reject requests');
      }
    }

    // Update request status
    await _firestore.collection('groupRequests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': user.uid,
    });
  }

  // Get user's groups
  static Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    
    if (!userDoc.exists) return [];

    final userData = userDoc.data()!;
    final groupIds = List<String>.from(userData['groups'] ?? []);

    if (groupIds.isEmpty) return [];

    final groups = await _firestore
        .collection('groups')
        .where(FieldPath.documentId, whereIn: groupIds)
        .get();

    return groups.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  // Search groups by name
  static Future<List<Map<String, dynamic>>> searchGroups(String query) async {
    if (query.trim().isEmpty) return [];

    final queryLower = query.toLowerCase();

    final groups = await _firestore.collection('groups').get();

    final results = groups.docs
        .where((doc) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString().toLowerCase();
          final description = (data['description'] ?? '').toString().toLowerCase();
          return name.contains(queryLower) || description.contains(queryLower);
        })
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        })
        .toList();

    return results;
  }

  // Get pending requests for a group (admin only)
  static Future<List<Map<String, dynamic>>> getGroupRequests(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if user is admin of the group
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw Exception('Group not found');
    }

    final groupData = groupDoc.data()!;
    if (groupData['adminId'] != user.uid) {
      throw Exception('Only group admin can view requests');
    }

    final requests = await _firestore
        .collection('groupRequests')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .get();

    return requests.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  // Get group details
  static Future<Map<String, dynamic>?> getGroup(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'id': doc.id,
      ...data,
    };
  }

  // Check if user is member of a group
  static Future<bool> isGroupMember(String groupId, String userId) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    
    if (!groupDoc.exists) return false;

    final groupData = groupDoc.data()!;
    final members = List<String>.from(groupData['members'] ?? []);
    
    return members.contains(userId);
  }

  // Check if user has pending request for a group
  static Future<bool> hasPendingRequest(String groupId, String userId) async {
    final requests = await _firestore
        .collection('groupRequests')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    return requests.docs.isNotEmpty;
  }
}