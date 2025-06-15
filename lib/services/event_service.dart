import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventService {
  static Future<String> saveEvent({
    required String eventType,
    required String eventName,
    required String description,
    required DateTime date,
    required TimeOfDay startTime,
    required String address,
    required String pace,
    required bool isPublic,
    required bool womenOnly,
    required String runType,
    required String rideType,
    double? distance,
    String distanceUnit = 'mi',
    int? groupSize,
    String? eventId, // For editing existing events
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    String typeValue = eventType == 'run' ? runType : rideType;
    if (eventType == 'run' && typeValue != 'road' && typeValue != 'trail') {
      typeValue = 'road';
    }
    
    // Get creator name from user profile
    String creatorName = 'Unknown';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        
        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          creatorName = '$firstName $lastName';
        } else if (firstName.isNotEmpty) {
          creatorName = firstName;
        } else if (lastName.isNotEmpty) {
          creatorName = lastName;
        }
      }
    } catch (e) {
      // Error handling for creator name fetch
    }
    
    // Create standardized event data with Timestamp
    final eventData = <String, dynamic>{
      'eventType': eventType,
      'eventName': eventName,
      'description': description,
      'address': address,
      'pace': pace,
      'isPublic': isPublic,
      'womenOnly': womenOnly,
      'type': typeValue,
    };
    
    // Add date as Timestamp
    eventData['date'] = Timestamp.fromDate(date);
    
    // Add start time
    eventData['startTime'] = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    
    // Add optional numeric fields
    if (distance != null) {
      eventData['distance'] = distance;
      eventData['distanceUnit'] = distanceUnit;
    }
    
    if (groupSize != null) {
      eventData['groupSize'] = groupSize;
    }
    
    if (eventId != null) {
      // Update existing event
      eventData['updatedAt'] = FieldValue.serverTimestamp();
      eventData['creatorName'] = creatorName;
      
      // Also update creator photo URL
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      eventData['creatorPhotoUrl'] = userData['photoUrl'];
      
      // Ensure organizer is still a participant
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      
      if (eventDoc.exists) {
        final currentData = eventDoc.data()!;
        final participants = List<String>.from(currentData['participants'] ?? []);
        final participantsData = List<Map<String, dynamic>>.from(currentData['participantsData'] ?? []);
        
        // Check if organizer is in participants list
        if (!participants.contains(user.uid)) {
          // Get user data to add organizer back
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          final userData = userDoc.data() ?? {};
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          final photoUrl = userData['photoUrl'];
          
          // Add organizer as first participant
          participants.insert(0, user.uid);
          participantsData.insert(0, {
            'uid': user.uid,
            'name': fullName.isNotEmpty ? fullName : 'User',
            'firstName': firstName,
            'lastName': lastName,
            'photoUrl': photoUrl,
          });
          
          eventData['participants'] = participants;
          eventData['participantsData'] = participantsData;
        }
      }
      
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update(eventData);
      
      // Notify participants about the event changes
      await _notifyParticipantsOfChanges(eventId, eventDoc.data()!, eventData);
      
      return eventId;
    } else {
      // Create new event - add creator as first participant
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'] ?? '';
      final lastName = userData['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      final photoUrl = userData['photoUrl'];
      
      eventData['creatorId'] = user.uid;
      eventData['creatorName'] = creatorName;
      eventData['creatorPhotoUrl'] = photoUrl;
      eventData['createdAt'] = FieldValue.serverTimestamp();
      // Add creator as first participant
      eventData['participants'] = [user.uid];
      eventData['participantsData'] = [{
        'uid': user.uid,
        'name': fullName.isNotEmpty ? fullName : 'User',
        'firstName': firstName,
        'lastName': lastName,
        'photoUrl': photoUrl,
      }];
      
      final docRef = await FirebaseFirestore.instance.collection('events').add(eventData);
      
      // Initialize messages subcollection to prevent loading issues
      await docRef.collection('messages').doc('_placeholder').set({
        'isPlaceholder': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    }
  }

  static Future<void> deleteEvent(String eventId) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
  }

  static Future<void> _notifyParticipantsOfChanges(
    String eventId,
    Map<String, dynamic> originalEventData,
    Map<String, dynamic> newEventData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get the list of changes (simplified for now)
    final changes = ['Event updated'];
    if (changes.isEmpty) return;

    // Get current event data to find participants
    final eventDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();
    
    if (!eventDoc.exists) return;
    
    final eventData = eventDoc.data()!;
    final participants = List<String>.from(eventData['participants'] ?? []);
    
    // Get host information
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? {};
    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final hostName = '$firstName $lastName'.trim().isNotEmpty 
        ? '$firstName $lastName'.trim() 
        : 'Event host';

    // Create notifications for all participants except the host
    final batch = FirebaseFirestore.instance.batch();
    
    for (final participantId in participants) {
      if (participantId != user.uid) {
        final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
        
        batch.set(notificationRef, {
          'userId': participantId,
          'type': 'event_update',
          'title': 'Event Updated',
          'message': '$hostName updated "${eventData['eventName'] ?? 'the event'}"',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'eventId': eventId,
            'eventName': eventData['eventName'],
            'eventType': eventData['eventType'],
            'hostName': hostName,
            'hostPhotoUrl': userData['photoUrl'],
            'changes': changes,
          },
        });
      }
    }
    
    await batch.commit();
  }
}