import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:glowy_borders/glowy_borders.dart';

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
  bool _isPosting = false;
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
  }

  @override
  void dispose() {
    _messageController.dispose();
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

        transaction.update(messageRef, {'reactions': reactions});
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
        if (currentUser != null) {
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          final currentUserData = currentUserDoc.data() ?? {};
          inviterPhotoUrl = currentUserData['photoUrl'];
        }

        // Create notification with enhanced event details
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userData['uid'],
          'type': 'event_invitation',
          'title': 'Event Invitation',
          'message': 'You\'ve been invited to ${widget.eventData['eventName']}',
          'data': {
            'eventId': widget.eventId,
            'eventName': widget.eventData['eventName'],
            'eventType': widget.eventData['eventType'],
            'eventDate': widget.eventData['date'],
            'eventTime': widget.eventData['startTime'],
            'eventAddress': widget.eventData['address'],
            'eventPace': widget.eventData['pace'],
            'eventDistance': widget.eventData['distance'],
            'eventDistanceUnit': widget.eventData['distanceUnit'],
            'fromUserId': currentUser?.uid,
            'fromUserName': widget.eventData['creatorName'],
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
    final isOwnEvent = widget.eventData['creatorId'] == user?.uid;
    final isParticipant = currentParticipants.contains(user?.uid);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(isOwnEvent),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          // Update local state when we receive real-time updates from Firestore
          if (snapshot.hasData && snapshot.data!.exists) {
            final eventData = snapshot.data!.data() as Map<String, dynamic>?;
            if (eventData != null) {
              // Only update if we don't have local changes pending
              // This prevents overriding optimistic updates while they're in progress
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  final newParticipants = List<String>.from(eventData['participants'] ?? []);
                  final newParticipantsData = List<Map<String, dynamic>>.from(eventData['participantsData'] ?? []);
                  final newInvitedUsers = List<String>.from(eventData['invitedUsers'] ?? []);
                  
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
          
          return SingleChildScrollView(
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
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(isOwnEvent, isParticipant),
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
            onPressed: () {
              // Navigate to edit event page
            },
          ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.black),
          onPressed: () {
            Share.share('Check out this event: ${widget.eventData['eventName']}');
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
                    color: widget.eventData['eventType'] == 'run' 
                        ? Colors.orange[100] 
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.eventData['eventType'] == 'run' 
                        ? Icons.directions_run 
                        : Icons.directions_bike,
                    color: widget.eventData['eventType'] == 'run' 
                        ? Colors.orange[700] 
                        : Colors.green[700],
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Title
                Expanded(
                  child: Text(
                    widget.eventData['eventName'] ?? 'Event',
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
                    String? creatorPhotoUrl = widget.eventData['creatorPhotoUrl'];
                    
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
                          text: widget.eventData['creatorName'] ?? 'Unknown',
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
              '${_formatEventDate(widget.eventData['date'])}${widget.eventData['startTime'] != null ? ' at ${widget.eventData['startTime']}' : ''}',
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
          if (widget.eventData['description']?.isNotEmpty == true) ...[
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
              widget.eventData['description'],
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
            value: widget.eventData['address'] ?? 'Not specified',
            color: Colors.red,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailItem(
            icon: widget.eventData['eventType'] == 'run' 
                ? Icons.directions_run 
                : Icons.directions_bike,
            label: 'Type',
            value: _getEventTypeLabel(widget.eventData),
            color: widget.eventData['eventType'] == 'run' 
                ? Colors.orange 
                : Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailItem(
            icon: Icons.speed,
            label: 'Pace',
            value: _getPaceLabel(widget.eventData['pace'] ?? ''),
            color: Colors.orange,
          ),
          
          if (widget.eventData['distance'] != null) ...[
            const SizedBox(height: 16),
            _buildDetailItem(
              icon: Icons.straighten,
              label: 'Distance',
              value: '${widget.eventData['distance']} ${widget.eventData['distanceUnit'] ?? 'mi'}',
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
          Stack(
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
          // Messages List with Header
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Column(
                  children: [
                    // Chat Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Chat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }

              final allMessages = snapshot.data!.docs;
              final totalCount = allMessages.length;
              final displayedMessages = _showAllMessages ? allMessages : allMessages.take(3).toList();
              
              return Column(
                children: [
                  // Chat Header with count
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
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
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$totalCount',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
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
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                ],
              );
            },
          ),
          
          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: _buildMessageInput(),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          FutureBuilder<DocumentSnapshot>(
            future: userId != null
                ? FirebaseFirestore.instance.collection('users').doc(userId).get()
                : null,
            builder: (context, snapshot) {
              String? photoUrl;
              if (snapshot.hasData && snapshot.data?.exists == true) {
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
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
            },
          ),
          
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
                      userName,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        data['gifUrl'],
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
                      ),
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
          child: TextField(
            controller: _messageController,
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
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: IconButton(
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
                : const Icon(Icons.send, color: Colors.white, size: 20),
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
      return ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showInviteModal(),
          backgroundColor: Colors.black,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'Invite People',
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
          glowSize: 3,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                    'Invite People',
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
                    onChanged: _searchUsers,
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
                              padding: const EdgeInsets.all(20),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final userData = _searchResults[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
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
                                        onPressed: () {
                                          _inviteUser(userData);
                                        },
                                        backgroundColor: Colors.black,
                                        child: const Text(
                                          'Invite',
                                          style: TextStyle(
                                            color: Colors.white,
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
  
  void _showGifPicker() {
    // Popular GIF URLs for demonstration - in a real app, you'd integrate with Giphy API
    final popularGifs = [
      'https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif', // thumbs up
      'https://media.giphy.com/media/l3q2XhfQ8oCkm1Ts4/giphy.gif', // celebration
      'https://media.giphy.com/media/26u4lOMA8JKSnL9Uk/giphy.gif', // running
      'https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif', // cycling
      'https://media.giphy.com/media/3o7abldj0b3rxrZUxO/giphy.gif', // high five
      'https://media.giphy.com/media/kyLYXonQYYfwYDIeZl/giphy.gif', // workout
      'https://media.giphy.com/media/l1J9FiGxR61OcF2mI/giphy.gif', // yes
      'https://media.giphy.com/media/ZdlpVW7xjfIZmvVsms/giphy.gif', // perfect
      'https://media.giphy.com/media/l0HlHFRbmaZtBRhXG/giphy.gif', // excited
      'https://media.giphy.com/media/3oz8xIsloV7zOmt81G/giphy.gif', // amazing
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                    'Choose a GIF',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            
            // GIF Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: popularGifs.length,
                itemBuilder: (context, index) {
                  final gifUrl = popularGifs[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _postMessage(gifUrl: gifUrl);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          gifUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.error),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
      print('Error compressing image: $e');
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
              'Add Photo',
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
}