import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'create_event.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventDetailPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isPosting = false;
  Map<String, dynamic>? _currentEventData;
  bool _showAllMessages = false;
  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  late AnimationController _shimmerController;
  bool _shimmerInitialized = false;
  
  // Local state for immediate UI updates
  List<String>? _currentParticipants;
  List<Map<String, dynamic>>? _currentParticipantsData;
  List<String>? _currentInvitedUsers;
  
  // User data cache to avoid repeated Firebase fetches
  final Map<String, Map<String, dynamic>> _userCache = {};
  
  // Method to get user data with caching
  Future<Map<String, dynamic>?> _getCachedUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      // Handle error silently and return null
    }
    
    return null;
  }
  
  // Get user data synchronously from cache (returns null if not cached)
  Map<String, dynamic>? _getUserDataFromCache(String userId) {
    return _userCache[userId];
  }
  
  // Pre-cache user data for all participants and invited users
  Future<void> _preCacheUserData() async {
    final Set<String> userIds = {};
    
    // Add participants
    if (_currentParticipantsData != null) {
      for (final participant in _currentParticipantsData!) {
        final uid = participant['uid'] as String?;
        if (uid != null) {
          userIds.add(uid);
          // Store participant data in cache
          _userCache[uid] = participant;
        }
      }
    }
    
    // Add invited users
    if (_currentInvitedUsers != null) {
      userIds.addAll(_currentInvitedUsers!);
    }
    
    // Add message authors (from recent messages)
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('messages')
        .limit(20)
        .get();
    
    for (final messageDoc in messagesSnapshot.docs) {
      final messageData = messageDoc.data();
      final userId = messageData['userId'] as String?;
      if (userId != null) userIds.add(userId);
    }
    
    // Fetch all uncached user data in parallel
    final futures = userIds
        .where((id) => !_userCache.containsKey(id))
        .map((id) => _getCachedUserData(id));
        
    await Future.wait(futures);
  }
  
  // Getter to return current event data, preferring StreamBuilder data over initial widget data
  Map<String, dynamic> get eventData => _currentEventData ?? widget.eventData;

  // Getters with fallbacks to widget data
  List<String> get currentParticipants => 
      _currentParticipants ?? List<String>.from(widget.eventData['participants'] ?? []);
  
  List<Map<String, dynamic>> get currentParticipantsData => 
      _currentParticipantsData ?? List<Map<String, dynamic>>.from(widget.eventData['participantsData'] ?? []);
  
  List<String> get currentInvitedUsers => 
      _currentInvitedUsers ?? List<String>.from(widget.eventData['invitedUsers'] ?? []);

  @override
  void initState() {
    super.initState();
    
    // Initialize local state with widget data - will be null initially, getters provide fallback
    _currentParticipants = List<String>.from(widget.eventData['participants'] ?? []);
    _currentParticipantsData = List<Map<String, dynamic>>.from(widget.eventData['participantsData'] ?? []);
    _currentInvitedUsers = List<String>.from(widget.eventData['invitedUsers'] ?? []);
    
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
    _fabController.forward();
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _shimmerController.repeat();
    _shimmerInitialized = true;
    
    // Pre-cache user data for better performance
    _preCacheUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    _fabController.dispose();
    if (_shimmerInitialized) {
      _shimmerController.dispose();
    }
    _removeOverlay(); // Clean up any active overlay
    super.dispose();
  }

  OverlayEntry? _overlayEntry;

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    
    // Remove any existing overlay
    _removeOverlay();
    
    final isSuccess = backgroundColor == null || backgroundColor == Colors.black;
    final color = backgroundColor ?? Colors.black;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSuccess ? Icons.check : Icons.error_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    
    // Auto-remove after delay
    Future.delayed(const Duration(milliseconds: 2500), () {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // Join/Leave event functionality
  Future<void> _toggleParticipation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isCurrentlyParticipant = currentParticipants.contains(user.uid);

    try {
      if (isCurrentlyParticipant) {
        // Leave event - Update local state immediately
        setState(() {
          _currentParticipants = List<String>.from(currentParticipants)..remove(user.uid);
          _currentParticipantsData = List<Map<String, dynamic>>.from(currentParticipantsData)
            ..removeWhere((p) => p['uid'] == user.uid);
        });
        _showSnackBar('You left the event');
      } else {
        // Join event - Update local state immediately
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        
        final newParticipantData = {
          'uid': user.uid,
          'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
          'firstName': userData['firstName'],
          'lastName': userData['lastName'],
          'photoUrl': userData['photoUrl'],
        };
        
        setState(() {
          _currentParticipants = List<String>.from(currentParticipants)..add(user.uid);
          _currentParticipantsData = List<Map<String, dynamic>>.from(currentParticipantsData)
            ..add(newParticipantData);
          // Remove from invited users if present
          _currentInvitedUsers = List<String>.from(currentInvitedUsers)..remove(user.uid);
        });
        _showSnackBar('Welcome to the event! 🎉');
      }

      // Update Firestore in background
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      await eventRef.update({
        'participants': currentParticipants,
        'participantsData': currentParticipantsData,
        'invitedUsers': currentInvitedUsers,
      });

      // Create notification for the event organizer
      final creatorId = widget.eventData['creatorId'] as String?;
      if (creatorId != null && creatorId != user.uid) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        final fullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        
        if (!isCurrentlyParticipant) {
          // Someone joined the event
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': creatorId,
            'type': 'new_participant',
            'title': 'New Participant',
            'message': '$fullName joined your event "${widget.eventData['eventName'] ?? 'event'}"',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'data': {
              'eventId': widget.eventId,
              'eventName': widget.eventData['eventName'],
              'eventType': widget.eventData['eventType'],
              'participantName': fullName,
              'participantId': user.uid,
              'participantPhotoUrl': userData['photoUrl'],
            },
          });
        } else {
          // Someone left the event
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': creatorId,
            'type': 'participant_left',
            'title': 'Participant Left',
            'message': '$fullName left your event "${widget.eventData['eventName'] ?? 'event'}"',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'data': {
              'eventId': widget.eventId,
              'eventName': widget.eventData['eventName'],
              'eventType': widget.eventData['eventType'],
              'participantName': fullName,
              'participantId': user.uid,
              'participantPhotoUrl': userData['photoUrl'],
            },
          });
        }
      }

    } catch (e) {
      // Revert local state on error
      setState(() {
        _currentParticipants = List<String>.from(widget.eventData['participants'] ?? []);
        _currentParticipantsData = List<Map<String, dynamic>>.from(widget.eventData['participantsData'] ?? []);
        _currentInvitedUsers = List<String>.from(widget.eventData['invitedUsers'] ?? []);
      });
      _showSnackBar('Error updating participation', backgroundColor: Colors.red[600]);
    }
  }

  // Post message functionality
  Future<void> _postMessage({String? gifUrl, String? photoUrl}) async {
    if (_messageController.text.trim().isEmpty && gifUrl == null && photoUrl == null) return;

    setState(() => _isPosting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isPosting = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final messageData = {
        'userId': user.uid,
        'userName': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
        'photoUrl': userData['photoUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      };

      // Add text if present
      if (_messageController.text.trim().isNotEmpty) {
        messageData['text'] = _messageController.text.trim();
      }

      // Add GIF if present
      if (gifUrl != null) {
        messageData['gifUrl'] = gifUrl;
        messageData['type'] = 'gif';
      } else if (photoUrl != null) {
        messageData['photoUrl'] = photoUrl;
        messageData['type'] = 'photo';
      } else {
        messageData['type'] = 'text';
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .add(messageData);

      // Create notifications for all participants and host (except the poster)
      final participants = List<String>.from(widget.eventData['participants'] ?? []);
      final creatorId = widget.eventData['creatorId'] as String?;
      final userFullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      
      // Collect all users who should be notified (participants + creator, excluding poster)
      Set<String> usersToNotify = {};
      usersToNotify.addAll(participants);
      if (creatorId != null) {
        usersToNotify.add(creatorId);
      }
      usersToNotify.remove(user.uid); // Don't notify the person who posted
      
      // Create notifications for each user
      for (final userId in usersToNotify) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'type': 'event_message',
          'title': 'New Message',
          'message': '$userFullName posted a message in "${widget.eventData['eventName'] ?? 'event'}"',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'eventId': widget.eventId,
            'eventName': widget.eventData['eventName'],
            'eventType': widget.eventData['eventType'],
            'posterName': userFullName,
            'posterId': user.uid,
            'posterPhotoUrl': userData['photoUrl'],
            'messageType': messageData['type'],
          },
        });
      }

      _messageController.clear();
      String successMessage = 'Message posted!';
      if (gifUrl != null) successMessage = 'GIF posted!';
      if (photoUrl != null) successMessage = 'Photo posted!';
      _showSnackBar(successMessage);
    } catch (e) {
      _showSnackBar('Failed to post message', backgroundColor: Colors.red[600]);
    } finally {
      setState(() => _isPosting = false);
    }
  }

  // Delete message
  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .doc(messageId)
          .delete();
      _showSnackBar('Message deleted');
    } catch (e) {
      _showSnackBar('Failed to delete message', backgroundColor: Colors.red[600]);
    }
  }

  // Handle media insertion from keyboard (GIFs, images, stickers)
  Future<void> _handleKeyboardMediaInsertion(KeyboardInsertedContent data) async {
    if (data.hasData) {
      try {
        final bytes = data.data;
        final mimeType = data.mimeType;
        
        // Check if we have valid byte data
        if (bytes == null) {
          _showSnackBar('No media data received', backgroundColor: Colors.red[600]);
          return;
        }
        
        // Determine if it's a GIF or regular image
        if (mimeType?.contains('gif') == true) {
          // Handle as GIF
          await _uploadAndPostGif(bytes);
        } else if (mimeType?.startsWith('image/') == true) {
          // Handle as regular image
          await _uploadAndPostImage(bytes);
        }
      } catch (e) {
        _showSnackBar('Failed to process media from keyboard', backgroundColor: Colors.red[600]);
      }
    }
  }

  // Upload and post GIF from keyboard
  Future<void> _uploadAndPostGif(Uint8List bytes) async {
    // Show immediate feedback
    setState(() {
      _isPosting = true;
    });

    try {
      // Create temporary file for the GIF
      final tempDir = await getTemporaryDirectory();
      final fileName = 'keyboard_gif_${DateTime.now().millisecondsSinceEpoch}.gif';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      // Create optimistic message first (local only)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        
        // Create temporary local file URL for immediate display
        final localGifUrl = tempFile.path;
        
        // Post message immediately with local file path for instant UI update
        final messageData = {
          'userId': user.uid,
          'userName': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
          'photoUrl': userData['photoUrl'],
          'timestamp': FieldValue.serverTimestamp(),
          'reactions': {},
          'gifUrl': localGifUrl, // Temporary local path
          'type': 'gif',
          'uploading': true, // Flag to indicate upload in progress
        };

        // Add to Firestore immediately
        final docRef = await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('messages')
            .add(messageData);

        // Upload in background
        _uploadGifInBackground(tempFile, docRef.id, userData);
      }

      setState(() {
        _isPosting = false;
      });
      
      _showSnackBar('GIF posted! 🎬');
    } catch (e) {
      setState(() {
        _isPosting = false;
      });
      _showSnackBar('Failed to upload GIF', backgroundColor: Colors.red[600]);
    }
  }

  // Background upload for GIF
  Future<void> _uploadGifInBackground(File tempFile, String messageId, Map<String, dynamic> userData) async {
    try {
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_gifs')
          .child('${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.gif');

      final uploadTask = storageRef.putFile(tempFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update message with real URL
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .doc(messageId)
          .update({
        'gifUrl': downloadUrl,
        'uploading': false, // Upload complete
      });

      // Clean up temp file
      await tempFile.delete();

      // Create notifications for participants
      await _createMessageNotifications(userData, 'gif');
    } catch (e) {
      // Update message to show upload failed
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .doc(messageId)
          .update({
        'uploadFailed': true,
        'uploading': false,
      });
      
      // Clean up temp file
      await tempFile.delete();
    }
  }

  // Upload and post image from keyboard
  Future<void> _uploadAndPostImage(Uint8List bytes) async {
    try {
      // Create temporary file for the image
      final tempDir = await getTemporaryDirectory();
      final fileName = 'keyboard_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      // Compress and upload the image (reuse existing logic)
      final compressedFile = await _compressImage(tempFile);
      if (compressedFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_photos')
            .child('${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = storageRef.putFile(compressedFile);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Clean up temp files
        await tempFile.delete();
        await compressedFile.delete();

        // Post message with photo URL
        await _postMessage(photoUrl: downloadUrl);
        
        _showSnackBar('Photo posted! 📸');
      }
    } catch (e) {
      _showSnackBar('Failed to upload image', backgroundColor: Colors.red[600]);
    }
  }

  // Build GIF image widget (handles both local and network URLs)
  Widget _buildGifImage(Map<String, dynamic> data) {
    final gifUrl = data['gifUrl'] as String;
    final isLocalFile = gifUrl.startsWith('/');
    
    if (isLocalFile) {
      // Show local file while uploading
      return Image.file(
        File(gifUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.error),
            ),
          );
        },
      );
    } else {
      // Show network image after upload
      return Image.network(
        gifUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.error),
            ),
          );
        },
      );
    }
  }

  // Create notifications for message participants
  Future<void> _createMessageNotifications(Map<String, dynamic> userData, String messageType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final participants = List<String>.from(eventData['participants'] ?? []);
    final creatorId = eventData['creatorId'] as String?;
    final userFullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    
    // Collect all users who should be notified (participants + creator, excluding poster)
    Set<String> usersToNotify = {};
    usersToNotify.addAll(participants.where((id) => id != user.uid));
    if (creatorId != null && creatorId != user.uid) {
      usersToNotify.add(creatorId);
    }

    // Create notifications
    final batch = FirebaseFirestore.instance.batch();
    for (final userId in usersToNotify) {
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      
      batch.set(notificationRef, {
        'userId': userId,
        'type': 'event_message',
        'title': 'New Message',
        'message': '$userFullName posted a message in "${eventData['eventName'] ?? 'event'}"',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'eventId': widget.eventId,
          'eventName': eventData['eventName'],
          'eventType': eventData['eventType'],
          'posterName': userFullName,
          'posterId': user.uid,
          'posterPhotoUrl': userData['photoUrl'],
          'messageType': messageType,
        },
      });
    }
    
    await batch.commit();
  }

  // Toggle emoji reaction
  Future<void> _toggleReaction(String messageId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .doc(messageId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final messageDoc = await transaction.get(messageRef);
        final data = messageDoc.data() ?? {};
        final reactions = Map<String, List<dynamic>>.from(data['reactions'] ?? {});

        // Find and remove user's existing reaction from any emoji
        String? currentUserReaction;
        reactions.forEach((existingEmoji, users) {
          if (users.contains(user.uid)) {
            currentUserReaction = existingEmoji;
          }
        });

        // Remove user from their current reaction if it exists
        if (currentUserReaction != null) {
          reactions[currentUserReaction]!.remove(user.uid);
          if (reactions[currentUserReaction]!.isEmpty) {
            reactions.remove(currentUserReaction);
          }
        }

        // If clicking the same emoji they already reacted with, just remove it (toggle off)
        // If clicking a different emoji, add the new reaction
        if (currentUserReaction != emoji) {
          if (reactions[emoji] == null) {
            reactions[emoji] = [];
          }
          reactions[emoji]!.add(user.uid);
        }

        // Use timestamp to ensure change detection
        final updatedData = {
          'reactions': reactions,
          'lastReactionUpdate': FieldValue.serverTimestamp(),
        };
        
        transaction.update(messageRef, updatedData);
      });
    } catch (e) {
      _showSnackBar('Failed to add reaction', backgroundColor: Colors.red[600]);
    }
  }

  // Search users for invitations
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Use current state instead of widget data for real-time updates
      final participants = currentParticipants;
      final invitedUsers = currentInvitedUsers;
      final excludeIds = {...participants, ...invitedUsers, user.uid};

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final queryLower = query.toLowerCase();

      final results = usersSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final firstName = (data['firstName'] ?? '').toString().toLowerCase();
            final lastName = (data['lastName'] ?? '').toString().toLowerCase();
            final fullName = '$firstName $lastName';
            final phoneNumber = data['phoneNumber']?.toString() ?? '';

            return !excludeIds.contains(doc.id) &&
                   (firstName.contains(queryLower) || 
                    lastName.contains(queryLower) ||
                    fullName.contains(queryLower) ||
                    phoneNumber.contains(query));
          })
          .map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'firstName': data['firstName'] ?? '',
              'lastName': data['lastName'] ?? '',
              'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
              'phoneNumber': data['phoneNumber'],
              'photoUrl': data['photoUrl'],
            };
          })
          .take(10)
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  Future<void> _searchUsersInModal(String query, StateSetter setModalState, Set<String> modalInvitedUsers) async {
    if (query.trim().isEmpty) {
      setModalState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setModalState(() => _isSearching = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Use current state instead of widget data for real-time updates
      final participants = currentParticipants;
      final excludeIds = {...participants, ...modalInvitedUsers, user.uid};

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final queryLower = query.toLowerCase();

      final results = usersSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final firstName = (data['firstName'] ?? '').toString().toLowerCase();
            final lastName = (data['lastName'] ?? '').toString().toLowerCase();
            final fullName = '$firstName $lastName';
            final phoneNumber = data['phoneNumber']?.toString() ?? '';

            return !excludeIds.contains(doc.id) &&
                   (firstName.contains(queryLower) || 
                    lastName.contains(queryLower) ||
                    fullName.contains(queryLower) ||
                    phoneNumber.contains(query));
          })
          .map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'firstName': data['firstName'] ?? '',
              'lastName': data['lastName'] ?? '',
              'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
              'phoneNumber': data['phoneNumber'],
              'photoUrl': data['photoUrl'],
            };
          })
          .take(10)
          .toList();

      setModalState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setModalState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  // Invite user to event
  Future<void> _inviteUser(Map<String, dynamic> userData) async {
    try {
      if (!currentInvitedUsers.contains(userData['uid'])) {
        // Update local state immediately
        setState(() {
          _currentInvitedUsers = List<String>.from(currentInvitedUsers)..add(userData['uid']);
        });

        // Update Firestore in background
        final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
        await eventRef.update({'invitedUsers': currentInvitedUsers});

        // Get current user's profile data for the notification
        final currentUser = FirebaseAuth.instance.currentUser;
        String? inviterPhotoUrl;
        String inviterFirstName = 'Someone';
        String inviterFullName = 'Someone';
        
        if (currentUser != null) {
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          final currentUserData = currentUserDoc.data() ?? {};
          inviterPhotoUrl = currentUserData['photoUrl'];
          final firstName = currentUserData['firstName'] ?? '';
          final lastName = currentUserData['lastName'] ?? '';
          inviterFirstName = firstName.isNotEmpty ? firstName : 'Someone';
          inviterFullName = '$firstName $lastName'.trim();
          if (inviterFullName.isEmpty) inviterFullName = 'Someone';
        }
        
        // Create notification with simplified format
        final notificationMessage = '$inviterFirstName invited you to ${widget.eventData['eventName']}';
        print('DEBUG: Creating invitation notification with message: $notificationMessage');
        
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userData['uid'],
          'type': 'event_invitation',
          'title': 'Event Invitation',
          'message': notificationMessage,
          'data': {
            'eventId': widget.eventId,
            'eventName': widget.eventData['eventName'],
            'fromUserId': currentUser?.uid,
            'fromUserName': inviterFullName,
            'fromUserPhotoUrl': inviterPhotoUrl,
          },
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _showSnackBar('Invited ${userData['name']} ✉️');
      }
    } catch (e) {
      // Revert local state on error
      setState(() {
        _currentInvitedUsers = List<String>.from(widget.eventData['invitedUsers'] ?? []);
      });
      _showSnackBar('Failed to send invitation', backgroundColor: Colors.red[600]);
    }
  }

  // Remove invitation
  Future<void> _removeInvitation(String userId, String userName) async {
    try {
      // Update local state immediately
      setState(() {
        _currentInvitedUsers = List<String>.from(currentInvitedUsers)..remove(userId);
      });

      // Update Firestore in background
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      await eventRef.update({'invitedUsers': currentInvitedUsers});

      _showSnackBar('Removed invitation for $userName');
    } catch (e) {
      // Revert local state on error
      setState(() {
        _currentInvitedUsers = List<String>.from(widget.eventData['invitedUsers'] ?? []);
      });
      _showSnackBar('Failed to remove invitation', backgroundColor: Colors.red[600]);
    }
  }

  // Remove participant
  Future<void> _removeParticipant(String userId, String userName) async {
    try {
      // Update local state immediately
      setState(() {
        _currentParticipants = List<String>.from(currentParticipants)..remove(userId);
        _currentParticipantsData = List<Map<String, dynamic>>.from(currentParticipantsData)
          ..removeWhere((p) => p['uid'] == userId);
      });

      // Update Firestore in background
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      await eventRef.update({
        'participants': currentParticipants,
        'participantsData': currentParticipantsData,
      });

      _showSnackBar('Removed $userName from event');
    } catch (e) {
      // Revert local state on error
      setState(() {
        _currentParticipants = List<String>.from(widget.eventData['participants'] ?? []);
        _currentParticipantsData = List<Map<String, dynamic>>.from(widget.eventData['participantsData'] ?? []);
      });
      _showSnackBar('Failed to remove participant', backgroundColor: Colors.red[600]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          // Get the current event data from StreamBuilder or fallback to widget.eventData
          Map<String, dynamic> currentEventData = widget.eventData;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final streamEventData = snapshot.data!.data() as Map<String, dynamic>?;
            if (streamEventData != null) {
              // Use stream data if available, otherwise fallback to widget.eventData
              currentEventData = streamEventData;
              
              // Update the instance variable for use in getter
              if (_currentEventData != streamEventData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _currentEventData = streamEventData;
                    });
                  }
                });
              }
              
              // Update local state when we receive real-time updates from Firestore
              // Only update if we don't have local changes pending
              // This prevents overriding optimistic updates while they're in progress
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  final newParticipants = List<String>.from(streamEventData['participants'] ?? []);
                  final newParticipantsData = List<Map<String, dynamic>>.from(streamEventData['participantsData'] ?? []);
                  final newInvitedUsers = List<String>.from(streamEventData['invitedUsers'] ?? []);
                  
                  // Update state if there are actual changes
                  bool hasChanges = false;
                  if (_currentParticipants != null && 
                      !_listEquals(_currentParticipants!, newParticipants)) {
                    hasChanges = true;
                  }
                  if (_currentParticipantsData != null && 
                      !_listEquals(_currentParticipantsData!.map((e) => e['uid']).toList(), 
                                   newParticipantsData.map((e) => e['uid']).toList())) {
                    hasChanges = true;
                  }
                  if (_currentInvitedUsers != null && 
                      !_listEquals(_currentInvitedUsers!, newInvitedUsers)) {
                    hasChanges = true;
                  }
                  
                  if (hasChanges) {
                    setState(() {
                      _currentParticipants = newParticipants;
                      _currentParticipantsData = newParticipantsData;
                      _currentInvitedUsers = newInvitedUsers;
                    });
                  }
                }
              });
            }
          }
          
          // Show loading if we don't have essential event data and are still loading
          if ((currentEventData.isEmpty || !currentEventData.containsKey('creatorId')) && 
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Show loading if snapshot has no data yet
          if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Show error if event doesn't exist
          if (snapshot.hasData && !snapshot.data!.exists) {
            return const Scaffold(
              body: Center(
                child: Text('Event not found'),
              ),
            );
          }
          
          final isOwnEvent = currentEventData['creatorId'] == user?.uid;
          final isParticipant = currentParticipants.contains(user?.uid);
          
          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: _buildAppBar(isOwnEvent),
            body: SingleChildScrollView(
            child: Column(
              children: [
                // Event Header Card
                _buildEventHeader(),
                
                const SizedBox(height: 16),
                
                // Event Details Card
                _buildEventDetails(),
                
                const SizedBox(height: 16),
                
                // Participants Section
                _buildParticipantsSection(isOwnEvent),
                
                const SizedBox(height: 16),
                
                // Messages Section
                _buildMessagesSection(),
                
                const SizedBox(height: 100), // Space for FAB
              ],
            ),
            ),
            floatingActionButton: _buildFloatingActionButton(isOwnEvent, isParticipant),
          );
        },
      ),
    );
  }
  
  // Helper method to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  PreferredSizeWidget _buildAppBar(bool isOwnEvent) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (isOwnEvent)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CreateEventPage(
                    isEdit: true,
                    eventId: widget.eventId,
                    initialEventData: widget.eventData,
                  ),
                ),
              );
              
              // If the event was updated, refresh the page
              if (result == true && mounted) {
                // Refresh the event data
                final updatedDoc = await FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.eventId)
                    .get();
                
                if (updatedDoc.exists && mounted) {
                  // Update the widget's event data
                  setState(() {
                    // Create a new event detail page with updated data
                  });
                  
                  // Pop and push the updated page
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => EventDetailPage(
                        eventId: widget.eventId,
                        eventData: updatedDoc.data()!,
                      ),
                    ),
                  );
                }
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.black),
          onPressed: () {
            Share.share('Check out this event: ${eventData['eventName']}');
          },
        ),
      ],
    );
  }

  Widget _buildEventHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and Title inline
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: eventData['eventType'] == 'run' 
                        ? Colors.orange[100] 
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    eventData['eventType'] == 'run' 
                        ? Icons.directions_run 
                        : Icons.directions_bike,
                    color: eventData['eventType'] == 'run' 
                        ? Colors.orange[700] 
                        : Colors.green[700],
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Title
                Expanded(
                  child: Text(
                    eventData['eventName'] ?? 'Event',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Organized by
            Row(
              children: [
                Builder(
                  builder: (context) {
                    // Try to get creator photo from event data first, then from participants data
                    String? creatorPhotoUrl = eventData['creatorPhotoUrl'];
                    
                    if (creatorPhotoUrl == null) {
                      // Fallback: get from participants data
                      final participantsData = List<Map<String, dynamic>>.from(widget.eventData['participantsData'] ?? []);
                      final creatorId = widget.eventData['creatorId'];
                      final creator = participantsData.firstWhere(
                        (participant) => participant['uid'] == creatorId,
                        orElse: () => <String, dynamic>{},
                      );
                      creatorPhotoUrl = creator['photoUrl'];
                    }
                    
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: creatorPhotoUrl != null && creatorPhotoUrl.isNotEmpty
                          ? NetworkImage(creatorPhotoUrl)
                          : null,
                      child: creatorPhotoUrl == null || creatorPhotoUrl.isEmpty
                          ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: 'Organized by ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextSpan(
                          text: eventData['creatorName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // When info - simple and bold
            Text(
              '${_formatEventDate(eventData['date'])}${eventData['startTime'] != null ? ' at ${eventData['startTime']}' : ''}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (eventData['description']?.isNotEmpty == true) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              eventData['description'],
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Event Details Grid
          _buildDetailItem(
            icon: Icons.location_on,
            label: 'Location',
            value: eventData['address'] ?? 'Not specified',
            color: Colors.red,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailItem(
            icon: eventData['eventType'] == 'run' 
                ? Icons.directions_run 
                : Icons.directions_bike,
            label: 'Type',
            value: _getEventTypeLabel(eventData),
            color: eventData['eventType'] == 'run' 
                ? Colors.orange 
                : Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailItem(
            icon: Icons.speed,
            label: 'Pace',
            value: _getPaceLabel(eventData['pace'] ?? ''),
            color: Colors.orange,
          ),
          
          if (eventData['distance'] != null) ...[
            const SizedBox(height: 16),
            _buildDetailItem(
              icon: Icons.straighten,
              label: 'Distance',
              value: '${eventData['distance']} ${eventData['distanceUnit'] ?? 'mi'}',
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color[700], size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection(bool isOwnEvent) {
    final participants = currentParticipantsData;
    final invitedUserIds = currentInvitedUsers;
    final participantCount = participants.length; // Only count participants, not invited

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Attendees',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Participants badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$participantCount',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Show invitees badge only for hosts
                  if (isOwnEvent && invitedUserIds.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${invitedUserIds.length}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (isOwnEvent)
                ShadButton(
                  onPressed: () => _showInviteModal(),
                  backgroundColor: Colors.black,
                  child: const Icon(Icons.person_add, color: Colors.white, size: 16),
                )
              else if (!currentParticipants.contains(FirebaseAuth.instance.currentUser?.uid))
                GestureDetector(
                  onTap: _toggleParticipation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Join',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (participantCount == 0)
            Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No participants yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            _buildParticipantAvatars(participants, invitedUserIds, isOwnEvent),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatars(
    List<Map<String, dynamic>> participants,
    List<String> invitedUserIds,
    bool isOwnEvent,
  ) {
    const maxVisibleAvatars = 6;
    final hasInvitedUsers = invitedUserIds.isNotEmpty;
    final totalPeople = participants.length + invitedUserIds.length;
    
    return Column(
      children: [
        // Avatar grid
        if (participants.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
              ...participants.take(maxVisibleAvatars).map((participant) {
                final photoUrl = participant['photoUrl'] as String?;
                
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green[300]!, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Icon(Icons.person, size: 22, color: Colors.grey[600])
                        : null,
                  ),
                );
              }),
              
              // Show overflow count if there are more participants
              if (participants.length > maxVisibleAvatars)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '+${participants.length - maxVisibleAvatars}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Show all button
        if (totalPeople > 0) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () => _showPeopleModal(participants, invitedUserIds, isOwnEvent),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Show all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonItem(
    Map<String, dynamic> person,
    {required bool isParticipant, required bool isOwnEvent}
  ) {
    final photoUrl = person['photoUrl'] as String?;
    final name = person['name'] ?? 'Unknown User';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = person['uid'] == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isParticipant ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isParticipant ? Colors.green[200]! : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isCurrentUser ? null : () => _showPublicProfileModal(person),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isParticipant ? Colors.green[500] : Colors.orange[500],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isCurrentUser ? null : () => _showPublicProfileModal(person),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isParticipant ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isParticipant ? 'Participant' : 'Invited',
                    style: TextStyle(
                      color: isParticipant ? Colors.green[700] : Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Friend badge for non-current users
          if (!isCurrentUser)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                bool isFriend = false;
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final currentUserData = snapshot.data!.data() as Map<String, dynamic>?;
                  final friends = List<Map<String, dynamic>>.from(currentUserData?['friends'] ?? []);
                  isFriend = friends.any((friend) => friend['uid'] == person['uid']);
                }
                
                if (isFriend) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 10,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Friend',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          if (isOwnEvent && !isCurrentUser)
            IconButton(
              onPressed: () {
                if (isParticipant) {
                  _removeParticipant(person['uid'], name);
                } else {
                  _removeInvitation(person['uid'], name);
                }
              },
              icon: Icon(
                Icons.close,
                color: Colors.red[600],
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chat Header (moved from inside StreamBuilder)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                const Text(
                  'Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                // Message count will be added via StreamBuilder
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.eventId)
                      .collection('messages')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final totalCount = snapshot.data?.docs.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[300]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble, size: 12, color: Colors.blue[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$totalCount',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Message Input (moved to top)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildMessageInput(),
          ),
          
          // Messages List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // Handle connection states more specifically
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Show loading only for initial load
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                        const SizedBox(height: 12),
                        const Text('Error loading messages'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // For active connection, show empty state if no messages
              if (snapshot.connectionState == ConnectionState.active && 
                  snapshot.hasData && 
                  snapshot.data!.docs.isEmpty) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Default fallback for any other case without data
              if (!snapshot.hasData || snapshot.data == null) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final allMessages = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isPlaceholder'] != true;
              }).toList();
              final totalCount = allMessages.length;
              // Messages are already ordered newest first, just take first N
              final displayedMessages = _showAllMessages ? allMessages : allMessages.take(3).toList();
              
              return Column(
                children: [
                  // Messages content
                  if (totalCount == 0)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ...displayedMessages.map((message) {
                          final data = message.data() as Map<String, dynamic>;
                          return _buildMessageItem(message.id, data);
                        }),
                        
                        // Expand/Collapse button when there are more messages
                        if (totalCount > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showAllMessages = !_showAllMessages;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_showAllMessages) ...[
                                      Icon(Icons.add, color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Show ${totalCount - 3} more message${totalCount - 3 == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ] else ...[
                                      Icon(Icons.remove, color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Show less',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(String messageId, Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = data['userId'] as String?;
    final userName = data['userName'] ?? 'Unknown User';
    final text = data['text'] as String?;
    final timestamp = data['timestamp'] as Timestamp?;
    final reactions = Map<String, List<dynamic>>.from(data['reactions'] ?? {});
    final isOwnMessage = user?.uid == userId;
    final photoUrl = data['photoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar - using photo from message data first, then cached user data
          _buildMessageAvatar(userId, photoUrl),
          
          const SizedBox(width: 12),
          
          // Message Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      isOwnMessage ? '$userName (you)' : userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (timestamp != null)
                      Text(
                        _formatMessageTime(timestamp.toDate()),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    const Spacer(),
                    if (isOwnMessage)
                      GestureDetector(
                        onTap: () => _showMessageOptions(messageId),
                        child: Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Message Content (Text, GIF, or Photo)
                if (text?.isNotEmpty == true)
                  Text(
                    text!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                
                // GIF Content
                if (data['type'] == 'gif' && data['gifUrl'] != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(
                      maxWidth: 200,
                      maxHeight: 200,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildGifImage(data),
                        ),
                        
                        // Upload indicator overlay
                        if (data['uploading'] == true)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ),
                          
                        // Upload failed indicator
                        if (data['uploadFailed'] == true)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.white, size: 32),
                                    SizedBox(height: 8),
                                    Text(
                                      'Upload Failed',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                
                // Photo Content
                if (data['type'] == 'photo' && data['photoUrl'] != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(
                      maxWidth: 250,
                      maxHeight: 300,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        data['photoUrl'],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.error),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Reactions and Quick React Button
                Wrap(
                  spacing: 6,
                  children: [
                    // Existing reactions
                    ...reactions.entries.map((entry) {
                      final emoji = entry.key;
                      final users = entry.value;
                      final hasReacted = users.contains(user?.uid);
                      
                      return GestureDetector(
                        onTap: () {
                          if (hasReacted) {
                            // If user has reacted, allow them to toggle it off
                            _toggleReaction(messageId, emoji);
                          } else if (users.isNotEmpty) {
                            // If others have reacted but not the user, show details modal
                            _showReactionDetails(messageId, reactions);
                          } else {
                            // This shouldn't happen, but fallback to toggle
                            _toggleReaction(messageId, emoji);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasReacted ? Colors.blue[100] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: hasReacted 
                                ? Border.all(color: Colors.blue[300]!)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                '${users.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: hasReacted ? Colors.blue[700] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    
                    // Quick React Button
                    GestureDetector(
                      onTap: () => _showReactionPicker(messageId),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Icon(Icons.mood, size: 14, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.black),
          onPressed: () => _showPhotoOptions(),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Ensure focus and keyboard appear
              if (!_messageFocusNode.hasFocus) {
                FocusScope.of(context).requestFocus(_messageFocusNode);
              }
            },
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              onSubmitted: (_) => _postMessage(),
              onTap: () {
                // Additional tap handling to ensure keyboard appears
                if (!_messageFocusNode.hasFocus) {
                  _messageFocusNode.requestFocus();
                }
              },
              contentInsertionConfiguration: ContentInsertionConfiguration(
                onContentInserted: (KeyboardInsertedContent data) {
                  _handleKeyboardMediaInsertion(data);
                },
                allowedMimeTypes: const ['image/gif', 'image/png', 'image/jpeg', 'image/webp'],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: _isPosting ? null : _postMessage,
            icon: _isPosting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(bool isOwnEvent, bool isParticipant) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    if (isOwnEvent) {
      // Show invite button for event owners
      if (!_shimmerInitialized) {
        // Fallback to regular black button if shimmer controller isn't ready
        return FloatingActionButton.extended(
          onPressed: () => _showInviteModal(),
          backgroundColor: Colors.black,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'Invite',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        );
      }
      
      return AnimatedGradientBorder(
        borderSize: 2,
        glowSize: 0,
        gradientColors: [
          Colors.blue[300]!,
          Colors.purple[300]!,
          Colors.blue[300]!,
        ],
        borderRadius: BorderRadius.circular(24),
        animationProgress: null, // Use built-in indefinite animation
        child: FloatingActionButton.extended(
          onPressed: () => _showInviteModal(),
          backgroundColor: Colors.black,
          elevation: 0,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'Invite',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } else {
      // Show join/leave button for other users
      if (isParticipant) {
        return ScaleTransition(
          scale: _fabAnimation,
          child: FloatingActionButton.extended(
            onPressed: _toggleParticipation,
            backgroundColor: Colors.black,
            icon: const Icon(
              Icons.exit_to_app,
              color: Colors.white,
            ),
            label: const Text(
              'Leave Event',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      } else {
        if (!_shimmerInitialized) {
          // Fallback to regular black button if shimmer controller isn't ready
          return FloatingActionButton.extended(
            onPressed: _toggleParticipation,
            backgroundColor: Colors.black,
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
            label: const Text(
              'Join Event',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          );
        }
        
        return AnimatedGradientBorder(
          borderSize: 2,
          glowSize: 0,
          gradientColors: [
            Colors.blue[300]!,
            Colors.purple[300]!,
            Colors.blue[300]!,
          ],
          borderRadius: BorderRadius.circular(24),
          animationProgress: null, // Use built-in indefinite animation
          child: FloatingActionButton.extended(
            onPressed: _toggleParticipation,
            backgroundColor: Colors.black,
            elevation: 0,
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
            label: const Text(
              'Join Event',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    }
  }

  void _showInviteModal() {
    Set<String> modalInvitedUsers = Set<String>.from(currentInvitedUsers);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
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
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Invite',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    onChanged: (query) => _searchUsersInModal(query, setModalState, modalInvitedUsers),
                  ),
                ],
              ),
            ),
            
            // Search Results
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty && _searchController.text.isNotEmpty
                      ? const Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : _searchController.text.isEmpty
                          ? const Center(
                              child: Text(
                                'Start typing to search for people',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final userData = _searchResults[index];
                                return Container(
                                  margin: EdgeInsets.fromLTRB(20, index == 0 ? 20 : 0, 20, 12),
                                  padding: const EdgeInsets.all(16),
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
                                        backgroundImage: userData['photoUrl'] != null && userData['photoUrl'].isNotEmpty
                                            ? NetworkImage(userData['photoUrl'])
                                            : null,
                                        child: userData['photoUrl'] == null || userData['photoUrl'].isEmpty
                                            ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userData['name'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (userData['phoneNumber'] != null)
                                              Text(
                                                userData['phoneNumber'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      ShadButton(
                                        onPressed: modalInvitedUsers.contains(userData['uid']) ? null : () {
                                          // Update local state immediately
                                          setModalState(() {
                                            modalInvitedUsers.add(userData['uid']);
                                          });
                                          // Then update backend
                                          _inviteUser(userData);
                                        },
                                        backgroundColor: modalInvitedUsers.contains(userData['uid']) 
                                            ? Colors.grey[400] 
                                            : Colors.black,
                                        child: Text(
                                          modalInvitedUsers.contains(userData['uid']) ? 'Invited' : 'Invite',
                                          style: TextStyle(
                                            color: modalInvitedUsers.contains(userData['uid']) 
                                                ? Colors.grey[600] 
                                                : Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showPeopleModal(
    List<Map<String, dynamic>> participants,
    List<String> invitedUserIds,
    bool isOwnEvent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          // Use real-time data from the stream
          List<Map<String, dynamic>> modalParticipants = currentParticipantsData;
          List<String> modalInvitedUsers = currentInvitedUsers;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final eventData = snapshot.data!.data() as Map<String, dynamic>?;
            if (eventData != null) {
              modalParticipants = List<Map<String, dynamic>>.from(eventData['participantsData'] ?? []);
              modalInvitedUsers = List<String>.from(eventData['invitedUsers'] ?? []);
            }
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
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
                      Text(
                        'Attendees (${isOwnEvent ? modalParticipants.length + modalInvitedUsers.length : modalParticipants.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
            
                // People List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Participants Section
                      if (modalParticipants.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Participants',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        ...modalParticipants.map((participant) => _buildPersonItem(
                          participant,
                          isParticipant: true,
                          isOwnEvent: isOwnEvent,
                        )),
                        if (modalInvitedUsers.isNotEmpty && isOwnEvent) const SizedBox(height: 24),
                      ],
                      
                      // Invited Users Section - only show to hosts
                      if (modalInvitedUsers.isNotEmpty && isOwnEvent) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Invited',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        ...modalInvitedUsers.map((userId) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 20, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                                SizedBox(width: 16),
                                Expanded(child: Text('Loading...')),
                              ],
                            ),
                          );
                        }
                        
                        final userData = snapshot.data?.data() as Map<String, dynamic>?;
                        final personData = {
                          'uid': userId,
                          'name': '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'.trim(),
                          'photoUrl': userData?['photoUrl'],
                        };
                        
                        return _buildPersonItem(
                          personData,
                          isParticipant: false,
                          isOwnEvent: isOwnEvent,
                        );
                      },
                    )),
                  ],
                  
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPublicProfileModal(Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userData['uid']).get(),
        builder: (context, snapshot) {
          Map<String, dynamic> fullUserData = userData;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final firestoreData = snapshot.data!.data() as Map<String, dynamic>?;
            if (firestoreData != null) {
              fullUserData = {
                ...userData,
                ...firestoreData,
                'name': fullUserData['name'] ?? '${firestoreData['firstName'] ?? ''} ${firestoreData['lastName'] ?? ''}'.trim(),
              };
            }
          }
          
          return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            
            // Profile Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Profile Picture and Name
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: fullUserData['photoUrl'] != null && fullUserData['photoUrl'].isNotEmpty
                              ? NetworkImage(fullUserData['photoUrl'])
                              : null,
                          child: fullUserData['photoUrl'] == null || fullUserData['photoUrl'].isEmpty
                              ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          fullUserData['name'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    
                    // Public Profile Info
                    if (fullUserData['eventsAttended'] != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue[600]!, Colors.purple[600]!],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Events Attended',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${fullUserData['eventsAttended'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const Spacer(),
                    
                    // Friend/Invite Actions
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .get(),
                      builder: (context, currentUserSnapshot) {
                        bool isFriend = false;
                        
                        if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                          final currentUserData = currentUserSnapshot.data!.data() as Map<String, dynamic>?;
                          final friends = List<Map<String, dynamic>>.from(currentUserData?['friends'] ?? []);
                          isFriend = friends.any((friend) => friend['uid'] == fullUserData['uid']);
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              // Friend/Invite Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isFriend ? null : () {
                                    // Handle friend request logic here
                                    _sendFriendRequest(fullUserData);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFriend ? Colors.grey[400] : Colors.blue[600],
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isFriend ? Icons.check : Icons.person_add,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isFriend ? 'Friends' : 'Send Friend Request',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Close Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Close',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
          );
        },
      ),
    );
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> userData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final currentUserData = currentUserDoc.data() ?? {};
      final senderName = '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}'.trim();
      
      // Create friend request notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userData['uid'],
        'type': 'friend_request',
        'title': 'Friend Request',
        'message': '$senderName sent you a friend request',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'fromUserId': currentUser.uid,
          'fromUserName': senderName,
          'fromUserPhotoUrl': currentUserData['photoUrl'],
        },
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${userData['name'] ?? 'user'}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Close the modal
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessageOptions(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Message Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ShadButton.outline(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Delete Message',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(String messageId) {
    final emojis = ['😂', '❤️', '👍', '🔥', '🚀', '😭', '👋', '🙏', '🤙', '💀'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'React to Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              children: emojis.map((emoji) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _toggleReaction(messageId, emoji);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showReactionDetails(String messageId, Map<String, List<dynamic>> reactions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
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
                  const Text(
                    'Reactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            
            // Reactions List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: reactions.entries.map((entry) {
                  final emoji = entry.key;
                  final userIds = entry.value;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Text(
                              '${userIds.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Users who reacted with this emoji
                      ...userIds.map((userId) => FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              child: const Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading...'),
                                ],
                              ),
                            );
                          }
                          
                          final userData = snapshot.data?.data() as Map<String, dynamic>?;
                          final name = userData != null 
                              ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim()
                              : 'Unknown User';
                          final photoUrl = userData?['photoUrl'] as String?;
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                          final isCurrentUser = userId == currentUserId;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null || photoUrl.isEmpty
                                      ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name.isNotEmpty ? name : 'Unknown User',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isCurrentUser)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      )),
                      
                      if (entry != reactions.entries.last)
                        const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date == null) return 'Not specified';
    
    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(date);
    } else if (date is String) {
      dateTime = DateTime.tryParse(date) ?? DateTime.now();
    } else {
      return date.toString();
    }
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _getPaceLabel(String value) {
    switch (value) {
      case 'social':
        return 'Social pace';
      case 'fitness':
        return 'Fitness pace';
      case 'competitive':
        return 'Competitive';
      default:
        return value.isNotEmpty ? value : 'Social pace';
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  String _getEventTypeLabel(Map<String, dynamic> eventData) {
    final eventType = eventData['eventType'] ?? '';
    final type = eventData['type'] ?? '';
    
    if (eventType == 'run') {
      switch (type) {
        case 'road':
          return 'Road Run';
        case 'trail':
          return 'Trail Run';
        case 'track':
          return 'Track Run';
        default:
          return 'Run';
      }
    } else if (eventType == 'ride') {
      switch (type) {
        case 'road':
          return 'Road Ride';
        case 'gravel':
          return 'Gravel Ride';
        case 'mountain':
          return 'Mountain Bike';
        default:
          return 'Ride';
      }
    }
    return eventType.isNotEmpty ? eventType[0].toUpperCase() + eventType.substring(1) : 'Event';
  }
  
  
  // Image compression helper
  Future<File?> _compressImage(File imageFile) async {
    try {
      final dir = Directory.systemTemp;
      final fileName = path.basename(imageFile.path);
      final targetPath = '${dir.path}/compressed_$fileName';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 800,
        minHeight: 600,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      }
      return null;
    } catch (e) {
      return imageFile; // Return original if compression fails
    }
  }
  
  // Photo options modal
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text(
              'Add Media',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _capturePhoto(ImageSource.camera);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt, size: 32, color: Colors.grey[700]),
                          const SizedBox(height: 8),
                          Text(
                            'Camera',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _capturePhoto(ImageSource.gallery);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.photo_library, size: 32, color: Colors.grey[700]),
                          const SizedBox(height: 8),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Capture and upload photo
  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        
        // Compress the image
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile == null) {
          _showSnackBar('Failed to process image', backgroundColor: Colors.red[600]);
          return;
        }
        
        // Upload to Firebase Storage
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('event_messages')
            .child(widget.eventId)
            .child(fileName);
        
        final uploadTask = await ref.putFile(compressedFile);
        final photoUrl = await uploadTask.ref.getDownloadURL();
        
        // Clean up temporary file
        try {
          await compressedFile.delete();
        } catch (e) {
          // Ignore cleanup errors
        }
        
        // Post message with photo
        await _postMessage(photoUrl: photoUrl);
      }
    } catch (e) {
      _showSnackBar('Failed to upload photo', backgroundColor: Colors.red[600]);
    }
  }

  // Optimized avatar widget using cached user data
  Widget _buildMessageAvatar(String? userId, String? messagePhotoUrl) {
    if (userId == null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, size: 18, color: Colors.grey[600]),
      );
    }

    // Use photo URL from message data first, then fall back to cached user data
    String? photoUrl = messagePhotoUrl;
    if (photoUrl == null || photoUrl.isEmpty) {
      final userData = _getUserDataFromCache(userId);
      photoUrl = userData?['photoUrl'] as String?;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[300],
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Icon(Icons.person, size: 18, color: Colors.grey[600])
          : null,
    );
  }
}

