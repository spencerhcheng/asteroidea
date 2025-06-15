import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'event_detail.dart';
import 'widgets/notifications_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedFilter = 'browse';
  String _selectedSport = 'run'; // 'run' or 'ride'
  String _selectedEventType = 'all'; // 'all', 'road', 'trail', 'track', 'gravel', 'mountain'
  bool _loadingPrefs = true;
  
  // Cache for expensive operations
  late DateTime _today;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadUserActivityPrefs();
  }

  Future<void> _loadUserActivityPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final prefs = List<String>.from(
        doc.data()?['activities'] ?? ['run', 'ride'],
      );
      // Set default sport based on user's first preference
      if (mounted) {
        setState(() {
          _selectedSport = prefs.contains('run') ? 'run' : 'ride';
          _loadingPrefs = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedSport = 'run';
          _loadingPrefs = false;
        });
      }
    }
  }

  void _selectSport(String sport) {
    setState(() {
      _selectedSport = sport;
      _selectedEventType = 'all'; // Reset event type when switching sports
    });
  }

  void _selectEventType(String eventType) {
    setState(() {
      _selectedEventType = eventType;
    });
  }

  List<Map<String, String>> _getEventTypeFilters() {
    if (_selectedSport == 'run') {
      return [
        {'key': 'all', 'label': 'All Runs'},
        {'key': 'road', 'label': 'Road'},
        {'key': 'trail', 'label': 'Trail'},
        {'key': 'track', 'label': 'Track'},
      ];
    } else {
      return [
        {'key': 'all', 'label': 'All Rides'},
        {'key': 'road', 'label': 'Road'},
        {'key': 'gravel', 'label': 'Gravel'},
        {'key': 'mountain', 'label': 'Mountain'},
      ];
    }
  }


  Widget _buildCompactContextTab(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    bottom: BorderSide(
                      color: Colors.blue[600]!,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.blue[600] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactEventChip(String key, String label, bool isSelected) {
    final sportColor = _selectedSport == 'run' ? Colors.orange[600] : Colors.green[600];
    
    return GestureDetector(
      onTap: () => _selectEventType(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? sportColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  String _getOrganizerName(Map<String, dynamic> eventData) {
    final creatorName = eventData['creatorName'];
    if (creatorName != null && creatorName.toString().isNotEmpty) {
      return creatorName;
    }
    return 'Unknown';
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
    return eventType.isNotEmpty ? eventType[0].toUpperCase() + eventType.substring(1) : '';
  }

  int _getParticipantCount(Map<String, dynamic> eventData) {
    final participants = eventData['participants'];
    if (participants is List) {
      return participants.length;
    }
    return 0;
  }

  Widget _buildMessageCountWidget(String eventId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .snapshots(),
      builder: (context, snapshot) {
        final messageCount = snapshot.data?.docs.length ?? 0;
        
        if (messageCount == 0) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                '$messageCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrganizerAvatar(Map<String, dynamic> eventData) {
    // Get creator photo URL from participantsData array
    final participantsData = eventData['participantsData'] as List<dynamic>? ?? [];
    final creatorId = eventData['creatorId'] as String?;
    
    String? creatorPhotoUrl;
    if (creatorId != null) {
      // Find the creator in participantsData
      for (final participant in participantsData) {
        if (participant is Map<String, dynamic> && participant['uid'] == creatorId) {
          creatorPhotoUrl = participant['photoUrl'] as String?;
          break;
        }
      }
    }
    
    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.grey[300],
      backgroundImage: creatorPhotoUrl != null && creatorPhotoUrl.isNotEmpty
          ? NetworkImage(creatorPhotoUrl)
          : null,
      child: creatorPhotoUrl == null || creatorPhotoUrl.isEmpty
          ? Icon(Icons.person, size: 12, color: Colors.grey[600])
          : null,
    );
  }

  Stream<int> _getUnreadNotificationCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsModal(),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date == null) return '';
    
    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is int) {
      // Legacy support for milliseconds
      dateTime = DateTime.fromMillisecondsSinceEpoch(date);
    } else if (date is String) {
      dateTime = DateTime.tryParse(date) ?? DateTime.now();
    } else {
      return date.toString();
    }
    
    // Format as day abbreviation and M/d
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[dateTime.weekday % 7]} ${dateTime.month}/${dateTime.day}';
  }

  String _formatStartTime(String? startTime) {
    if (startTime == null || startTime.isEmpty) return '';
    
    try {
      // Parse the time string (assuming format like "17:30" or "5:30 PM")
      if (startTime.contains('AM') || startTime.contains('PM')) {
        // Already in 12-hour format, just return as is
        return startTime.toLowerCase().replaceAll(' ', '');
      }
      
      // Convert from 24-hour format
      final parts = startTime.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        
        String period = hour >= 12 ? 'pm' : 'am';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        
        String minuteStr = minute.toString().padLeft(2, '0');
        return '$hour:${minuteStr}$period';
      }
    } catch (e) {
      // If parsing fails, return original
      return startTime;
    }
    
    return startTime;
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return '';
    
    // Convert to double if it's not already
    double? distanceValue;
    if (distance is String) {
      distanceValue = double.tryParse(distance);
    } else if (distance is num) {
      distanceValue = distance.toDouble();
    }
    
    if (distanceValue == null) return distance.toString();
    
    // If it's a whole number, show without decimals
    if (distanceValue == distanceValue.truncate()) {
      return distanceValue.truncate().toString();
    } else {
      // Otherwise show with decimals, but remove trailing zeros
      return distanceValue.toString().replaceAll(RegExp(r'\.?0*$'), '');
    }
  }

  // Optimized date check - extracted to avoid repeated DateTime parsing
  bool _isEventOnOrAfterToday(dynamic eventDate) {
    if (eventDate == null) return true;
    
    DateTime? eventDateTime;
    if (eventDate is Timestamp) {
      eventDateTime = eventDate.toDate();
    } else if (eventDate is int) {
      eventDateTime = DateTime.fromMillisecondsSinceEpoch(eventDate);
    }
    
    if (eventDateTime == null) return true;
    
    final eventDay = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
    return eventDay.isAfter(_today) || eventDay.isAtSameMomentAs(_today);
  }

  bool _isEventBeforeToday(dynamic eventDate) {
    if (eventDate == null) return false;
    
    DateTime? eventDateTime;
    if (eventDate is Timestamp) {
      eventDateTime = eventDate.toDate();
    } else if (eventDate is int) {
      eventDateTime = DateTime.fromMillisecondsSinceEpoch(eventDate);
    }
    
    if (eventDateTime == null) return false;
    
    final eventDay = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
    return eventDay.isBefore(_today);
  }

  bool _isUserParticipating(Map<String, dynamic> eventData) {
    if (_currentUserId == null) return false;
    
    final participants = List<String>.from(eventData['participants'] ?? []);
    final isCreator = eventData['creatorId'] == _currentUserId;
    final isParticipant = participants.contains(_currentUserId);
    
    return isCreator || isParticipant;
  }

  // Optimized filtering method
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    return events.where((e) {
      final eventData = e.data();
      final eventType = eventData['eventType'] ?? '';
      final eventSubType = eventData['type'] ?? '';
      
      // Quick sport filter
      if (eventType != _selectedSport) return false;
      
      // Quick event type filter
      if (_selectedEventType != 'all' && eventSubType != _selectedEventType) {
        return false;
      }
      
      // Filter by tab with optimized date checking
      switch (_selectedFilter) {
        case 'my_events':
          return _isEventOnOrAfterToday(eventData['date']) && 
                 _isUserParticipating(eventData);
                 
        case 'past_events':
          return _isEventBeforeToday(eventData['date']) && 
                 _isUserParticipating(eventData);
                 
        default: // browse
          if (!_isEventOnOrAfterToday(eventData['date'])) return false;
          
          // Show public events
          if (eventData['isPublic'] == true) return true;
          
          // Show private events user is invited to
          if (_currentUserId != null) {
            final invitedUsers = List<String>.from(eventData['invitedUsers'] ?? []);
            return invitedUsers.contains(_currentUserId);
          }
          
          return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Events',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showNotificationsModal(),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Colors.black,
                      size: 28,
                    ),
                    // Notification badge
                    Positioned(
                      right: -4,
                      top: -4,
                      child: StreamBuilder<int>(
                        stream: _getUnreadNotificationCount(),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          
                          return IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compact Filter System
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            // Sport Selection Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<String>(
                                    segments: [
                                      ButtonSegment<String>(
                                        value: 'run',
                                        label: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.directions_run,
                                              size: 18,
                                              color: _selectedSport == 'run'
                                                  ? Colors.white
                                                  : Colors.grey[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Run',
                                              style: TextStyle(
                                                color: _selectedSport == 'run'
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'ride',
                                        label: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.directions_bike,
                                              size: 18,
                                              color: _selectedSport == 'ride'
                                                  ? Colors.white
                                                  : Colors.grey[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Ride',
                                              style: TextStyle(
                                                color: _selectedSport == 'ride'
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    selected: {_selectedSport},
                                    showSelectedIcon: false,
                                    onSelectionChanged: (Set<String> newSelection) {
                                      _selectSport(newSelection.first);
                                    },
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.resolveWith<Color>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (states.contains(WidgetState.selected)) {
                                          return Colors.black;
                                        }
                                        return Colors.grey[200]!;
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Context Tabs Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  _buildCompactContextTab('browse', 'Browse'),
                                  _buildCompactContextTab('my_events', 'My Events'),
                                  _buildCompactContextTab('past_events', 'Past'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              key: ValueKey(_selectedSport),
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: _getEventTypeFilters().map((filter) {
                                  final isSelected = _selectedEventType == filter['key'];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _buildCompactEventChip(
                                      filter['key']!,
                                      filter['label']!,
                                      isSelected,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .orderBy('date')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final events = snapshot.data?.docs ?? [];
                      if (events.isEmpty) {
                        return const Center(child: Text('No events yet.'));
                      }
                      // Use optimized filtering
                      final filteredEvents = _filterEvents(events);
                      if (filteredEvents.isEmpty) {
                        String emptyMessage;
                        final sportName = _selectedSport == 'run' ? 'running' : 'cycling';
                        final eventTypeName = _selectedEventType == 'all' ? sportName : '${_selectedEventType} ${_selectedSport == 'run' ? 'running' : 'cycling'}';
                        
                        switch (_selectedFilter) {
                          case 'my_events':
                            emptyMessage = 'No upcoming $eventTypeName events you\'re participating in.';
                            break;
                          case 'browse':
                            emptyMessage = 'No $eventTypeName events or invitations available.';
                            break;
                          case 'past_events':
                            emptyMessage = 'No past $eventTypeName events found.';
                            break;
                          default:
                            emptyMessage = 'No $eventTypeName events found.';
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 40,
                            ),
                            child: Text(
                              emptyMessage,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        itemCount: filteredEvents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final doc = filteredEvents[i];
                          final e = doc.data();
                          return _buildEventCard(doc.id, doc, e, i);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventCard(String eventId, QueryDocumentSnapshot<Map<String, dynamic>> doc, Map<String, dynamic> e, int index) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwnEvent = e['creatorId'] == user?.uid;
                          
    return GestureDetector(
      key: ValueKey(eventId),
      onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EventDetailPage(
                                    eventId: doc.id,
                                    eventData: e,
                                  ),
                                ),
                              );
                              // Refresh the page after returning from event detail
                              if (mounted) {
                                setState(() {});
                              }
                            },
                            child: Stack(
                              children: [
                                Material(
                                  color: Colors.grey[900],
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          e['eventType'] == 'run'
                                              ? Icons.directions_run
                                              : Icons.directions_bike,
                                          color: Colors.blue[300],
                                          size: 28,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e['eventName'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Organized by ',
                                                    style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Flexible(
                                                    child: Text(
                                                      _getOrganizerName(e),
                                                      style: TextStyle(
                                                        color: Colors.grey[400],
                                                        fontSize: 14,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  _buildOrganizerAvatar(e),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: e['eventType'] == 'run' 
                                                          ? Colors.orange[600]
                                                          : Colors.green[600],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      _getEventTypeLabel(e),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
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
                                                          '${_getParticipantCount(e)}',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildMessageCountWidget(doc.id),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Public/Private indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: e['isPublic'] == true 
                                                ? Colors.green[600]!.withValues(alpha: 0.9)
                                                : Colors.orange[600]!.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                e['isPublic'] == true ? Icons.public : Icons.lock,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                e['isPublic'] == true ? 'Public' : 'Private',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  if ((e['description'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      e['description'],
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.blue[300],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        () {
                                          final dateStr = e['date'] != null ? _formatEventDate(e['date']) : '';
                                          final timeStr = _formatStartTime(e['startTime']);
                                          if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
                                            return '$dateStr $timeStr';
                                          } else if (dateStr.isNotEmpty) {
                                            return dateStr;
                                          } else if (timeStr.isNotEmpty) {
                                            return timeStr;
                                          }
                                          return '';
                                        }(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.orange[300],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          e['address'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (e['eventType'] == 'ride' &&
                                      e['distance'] != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.straighten,
                                          color: Colors.orange[300],
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_formatDistance(e['distance'])} ${e['distanceUnit']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if ((e['routeLink'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.link,
                                          color: Colors.blue[300],
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            e['routeLink'],
                                            style: TextStyle(
                                              color: Colors.blue[300],
                                              fontSize: 15,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.speed,
                                        color: Colors.orange[300],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        e['pace'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (e['groupSize'] != null) ...[
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.group,
                                          color: Colors.blue[300],
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Limit: ${e['groupSize']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  ],
                                ),
                              ),
                            ),
                                
                                // Host Badge Overlay
                                if (isOwnEvent)
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange[600]!.withValues(alpha: 0.9),
                                            Colors.red[600]!.withValues(alpha: 0.9),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'HOST',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
  }
}
