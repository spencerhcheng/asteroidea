import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'create_event_page.dart';
import 'event_detail_page.dart';

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

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _selectedSport = prefs.contains('run') ? 'run' : 'ride';
        _loadingPrefs = false;
      });
    } else {
      setState(() {
        _selectedSport = 'run';
        _loadingPrefs = false;
      });
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
                      // Filter events by selected activities and filter type
                      final user = FirebaseAuth.instance.currentUser;
                      final filteredEvents = events.where((e) {
                        final eventType = e['eventType'] ?? '';
                        final eventSubType = e['type'] ?? '';
                        
                        // First filter by selected sport
                        if (eventType != _selectedSport) {
                          return false;
                        }
                        
                        // Then filter by event type if not 'all'
                        if (_selectedEventType != 'all' && eventSubType != _selectedEventType) {
                          return false;
                        }
                        
                        // Then filter by selected filter tab
                        switch (_selectedFilter) {
                          case 'my_events':
                            // Show events user is participating in or hosting (upcoming only)
                            final eventDate = e['date'];
                            bool isFutureEvent = true;
                            if (eventDate != null) {
                              DateTime? eventDateTime;
                              if (eventDate is Timestamp) {
                                eventDateTime = eventDate.toDate();
                              } else if (eventDate is int) {
                                eventDateTime = DateTime.fromMillisecondsSinceEpoch(eventDate);
                              }
                              if (eventDateTime != null) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final eventDay = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
                                isFutureEvent = eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
                              }
                            }
                            if (!isFutureEvent) return false;
                            
                            final participants = List<String>.from(e['participants'] ?? []);
                            final isCreator = e['creatorId'] == user?.uid;
                            final isParticipant = participants.contains(user?.uid);
                            return isCreator || isParticipant;
                          case 'past_events':
                            // Show past events user participated in or hosted
                            final eventDate = e['date'];
                            bool isPastEvent = false;
                            if (eventDate != null) {
                              DateTime? eventDateTime;
                              if (eventDate is Timestamp) {
                                eventDateTime = eventDate.toDate();
                              } else if (eventDate is int) {
                                eventDateTime = DateTime.fromMillisecondsSinceEpoch(eventDate);
                              }
                              if (eventDateTime != null) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final eventDay = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
                                isPastEvent = eventDay.isBefore(today);
                              }
                            }
                            if (!isPastEvent) return false;
                            
                            final participants = List<String>.from(e['participants'] ?? []);
                            final isCreator = e['creatorId'] == user?.uid;
                            final isParticipant = participants.contains(user?.uid);
                            return isCreator || isParticipant;
                          default:
                            // Browse mode: shows public events + private events user is invited to
                            final eventDate = e['date'];
                            bool isFutureEvent = true;
                            if (eventDate != null) {
                              DateTime? eventDateTime;
                              if (eventDate is Timestamp) {
                                eventDateTime = eventDate.toDate();
                              } else if (eventDate is int) {
                                eventDateTime = DateTime.fromMillisecondsSinceEpoch(eventDate);
                              }
                              if (eventDateTime != null) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final eventDay = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
                                isFutureEvent = eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
                              }
                            }
                            if (!isFutureEvent) return false;
                            
                            // Show public events
                            if (e['isPublic'] == true) return true;
                            
                            // Show private events user is invited to
                            final invitedUsers = List<String>.from(e['invitedUsers'] ?? []);
                            return invitedUsers.contains(user?.uid);
                        }
                      }).toList();
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
                          final user = FirebaseAuth.instance.currentUser;
                          final isOwnEvent = e['creatorId'] == user?.uid;
                          
                          return GestureDetector(
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
                              setState(() {});
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

class NotificationsModal extends StatefulWidget {
  const NotificationsModal({super.key});

  @override
  State<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends State<NotificationsModal> {
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
    
    // Format as readable date
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
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
                      onPressed: () => _markAllAsRead(),
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
          
          // Notifications List
          Expanded(
            child: user == null 
                ? const Center(
                    child: Text('Please sign in to view notifications'),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('timestamp', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        // Error will be handled in the UI below
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red[600], size: 64),
                              const SizedBox(height: 16),
                              Text('Error loading notifications: ${snapshot.error}'),
                            ],
                          ),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
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
                                'We\'ll notify you about events and activities',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildGroupedNotifications(snapshot.data!.docs),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String notificationId, Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final createdAt = notification['timestamp'] as Timestamp?;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    
    // Get user info for different notification types
    String? userPhotoUrl;
    String? userName;
    String? eventName;
    String? eventType;
    
    if (type == 'event_invitation') {
      userPhotoUrl = data['fromUserPhotoUrl'];
      userName = data['fromUserName'];
      eventName = data['eventName'];
      eventType = data['eventType'];
    } else if (type == 'new_participant' || type == 'participant_left') {
      userPhotoUrl = data['participantPhotoUrl'];
      userName = data['participantName'];
      eventName = data['eventName'];
      eventType = data['eventType'];
    } else if (type == 'event_message') {
      userPhotoUrl = data['posterPhotoUrl'];
      userName = data['posterName'];
      eventName = data['eventName'];
      eventType = data['eventType'];
    } else if (type == 'event_update') {
      userPhotoUrl = data['hostPhotoUrl'];
      userName = data['hostName'];
      eventName = data['eventName'];
      eventType = data['eventType'];
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notificationId, notification),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar or icon with notification type badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main avatar/icon
                  if ((type == 'event_invitation' || type == 'new_participant' || type == 'participant_left' || type == 'event_message' || type == 'event_update') && userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: eventType == 'run' ? Colors.orange[300]! : Colors.green[300]!,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: NetworkImage(userPhotoUrl),
                        onBackgroundImageError: (_, __) {},
                        child: null,
                      ),
                    )
                  else if (type == 'event_invitation' || type == 'new_participant' || type == 'participant_left' || type == 'event_message' || type == 'event_update')
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: eventType == 'run' ? Colors.orange[100] : Colors.green[100],
                        border: Border.all(
                          color: eventType == 'run' ? Colors.orange[300]! : Colors.green[300]!,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        eventType == 'run' ? Icons.directions_run : Icons.directions_bike,
                        color: eventType == 'run' ? Colors.orange[700] : Colors.green[700],
                        size: 24,
                      ),
                    )
                  else
                    _getNotificationIcon(type),
                  
                  // Notification type badge overlay
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: _getNotificationTypeBadge(type),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with enhanced styling for event invitations and new participants
                    if (type == 'event_invitation' && userName != null && eventName != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(text: userName),
                            TextSpan(
                              text: ' invited you to ',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.grey[700],
                              ),
                            ),
                            TextSpan(
                              text: eventName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (type == 'new_participant' && userName != null && eventName != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(text: userName),
                            TextSpan(
                              text: ' joined your event ',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.grey[700],
                              ),
                            ),
                            TextSpan(
                              text: eventName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (type == 'participant_left' && userName != null && eventName != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(text: userName),
                            TextSpan(
                              text: ' left your event ',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.grey[700],
                              ),
                            ),
                            TextSpan(
                              text: eventName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (type == 'event_message' && userName != null && eventName != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(text: userName),
                            TextSpan(
                              text: ' posted a message in ',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.grey[700],
                              ),
                            ),
                            TextSpan(
                              text: eventName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (type == 'event_update' && userName != null && eventName != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(text: userName),
                            TextSpan(
                              text: ' updated ',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.grey[700],
                              ),
                            ),
                            TextSpan(
                              text: eventName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    
                    const SizedBox(height: 4),
                    
                    // Event type badge for invitations and participant changes
                    if ((type == 'event_invitation' || type == 'new_participant' || type == 'participant_left' || type == 'event_message' || type == 'event_update') && eventType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: eventType == 'run' ? Colors.orange[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          eventType == 'run' ? 'Run Event' : 'Ride Event',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: eventType == 'run' ? Colors.orange[700] : Colors.green[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    
                    // Timestamp
                    if (createdAt != null)
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Unread indicator
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData iconData;
    Color color;
    
    switch (type) {
      case 'event_invitation':
        iconData = Icons.event;
        color = Colors.blue[600]!;
        break;
      case 'event_reminder':
        iconData = Icons.schedule;
        color = Colors.orange[600]!;
        break;
      case 'event_update':
        iconData = Icons.edit;
        color = Colors.purple[600]!;
        break;
      case 'new_participant':
        iconData = Icons.person_add;
        color = Colors.green[600]!;
        break;
      case 'participant_left':
        iconData = Icons.person_remove;
        color = Colors.orange[600]!;
        break;
      case 'friend_request':
        iconData = Icons.person_add;
        color = Colors.teal[600]!;
        break;
      case 'friend_accepted':
        iconData = Icons.check_circle;
        color = Colors.green[600]!;
        break;
      case 'event_message':
        iconData = Icons.message;
        color = Colors.blue[600]!;
        break;
      default:
        iconData = Icons.notifications;
        color = Colors.grey[600]!;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Widget _getNotificationTypeBadge(String type) {
    IconData iconData;
    Color backgroundColor;
    Color iconColor;
    
    switch (type) {
      case 'event_invitation':
        iconData = Icons.mail;
        backgroundColor = Colors.blue[600]!;
        iconColor = Colors.white;
        break;
      case 'new_participant':
        iconData = Icons.person_add;
        backgroundColor = Colors.green[600]!;
        iconColor = Colors.white;
        break;
      case 'participant_left':
        iconData = Icons.person_remove;
        backgroundColor = Colors.orange[600]!;
        iconColor = Colors.white;
        break;
      case 'event_message':
        iconData = Icons.chat_bubble;
        backgroundColor = Colors.purple[600]!;
        iconColor = Colors.white;
        break;
      case 'event_update':
        iconData = Icons.edit;
        backgroundColor = Colors.indigo[600]!;
        iconColor = Colors.white;
        break;
      case 'event_reminder':
        iconData = Icons.access_time;
        backgroundColor = Colors.amber[600]!;
        iconColor = Colors.white;
        break;
      case 'friend_request':
        iconData = Icons.group_add;
        backgroundColor = Colors.teal[600]!;
        iconColor = Colors.white;
        break;
      case 'friend_accepted':
        iconData = Icons.check;
        backgroundColor = Colors.green[600]!;
        iconColor = Colors.white;
        break;
      default:
        iconData = Icons.notifications;
        backgroundColor = Colors.grey[600]!;
        iconColor = Colors.white;
    }
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 12,
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      // Error handling - could show user feedback if needed
    }
  }

  Future<void> _handleNotificationTap(String notificationId, Map<String, dynamic> notification) async {
    // Mark as read
    try {
      if (!(notification['isRead'] ?? false)) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});
      }
    } catch (e) {
      // Error handling - notification read status update failed
    }
    
    // Handle notification action based on type
    final type = notification['type'] ?? '';
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final eventId = data['eventId'] as String?;
    
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid notification data.'),
        ),
      );
      return;
    }
    
    if (['event_invitation', 'event_reminder', 'event_update', 'new_participant', 'participant_left', 'event_message'].contains(type)) {
      try {
        // Fetch event data from Firestore BEFORE closing modal
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .get();
        
        if (!eventDoc.exists) {
          // Close modal first
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This event is no longer available.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        final eventData = eventDoc.data() ?? {};
        
        // Close the notification modal
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Check if widget is still mounted after modal close
        if (!mounted) {
          return;
        }
        
        // Navigate to event detail page
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailPage(
              eventId: eventId,
              eventData: eventData,
            ),
          ),
        );
        
      } catch (e) {
        // Close modal on error
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Handle error fetching event data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to load event details. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }
  
  void _showEventInvitationDialog(String notificationId, Map<String, dynamic> notification) async {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final eventName = data['eventName'] ?? 'Event';
    final inviterName = data['fromUserName'] ?? 'Someone';
    final eventId = data['eventId'] as String?;
    final inviterPhotoUrl = data['fromUserPhotoUrl'] as String?;
    
    // Check if user has already joined the event
    bool hasJoined = false;
    bool eventExists = true;
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null && eventId != null) {
      try {
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .get();
        
        if (eventDoc.exists) {
          final participants = List<String>.from(eventDoc.data()?['participants'] ?? []);
          hasJoined = participants.contains(user.uid);
        } else {
          eventExists = false;
        }
      } catch (e) {
        // Error handling for event status check
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with dismiss button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    // Notification icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.purple[600]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Event Invitation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                              height: 1.2,
                            ),
                          ),
                          Text(
                            'You\'ve been invited!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dismiss button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inviter info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: inviterPhotoUrl != null && inviterPhotoUrl.isNotEmpty
                              ? NetworkImage(inviterPhotoUrl)
                              : null,
                          child: inviterPhotoUrl == null || inviterPhotoUrl.isEmpty
                              ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: inviterName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const TextSpan(text: ' invited you to join:'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Event details card
                    GestureDetector(
                      onTap: () async {
                        Navigator.of(context).pop(); // Dismiss the notification modal
                        if (eventId != null) {
                          try {
                            // Fetch event data from Firestore
                            final eventDoc = await FirebaseFirestore.instance
                                .collection('events')
                                .doc(eventId)
                                .get();
                            
                            if (eventDoc.exists && mounted) {
                              final eventData = eventDoc.data() ?? {};
                              
                              // Navigate to event detail page
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EventDetailPage(
                                    eventId: eventId,
                                    eventData: eventData,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            // Error handling for navigation
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (data['eventType'] == 'run' ? Colors.orange[50] : Colors.green[50])!,
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (data['eventType'] == 'run' ? Colors.orange[200] : Colors.green[200])!,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event name with type badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  eventName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (data['eventType'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: data['eventType'] == 'run' ? Colors.orange[100] : Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        data['eventType'] == 'run' ? Icons.directions_run : Icons.directions_bike,
                                        size: 14,
                                        color: data['eventType'] == 'run' ? Colors.orange[700] : Colors.green[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['eventType'] == 'run' ? 'Run' : 'Ride',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: data['eventType'] == 'run' ? Colors.orange[700] : Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Event details in a clean grid
                          if (data['eventDate'] != null || data['eventTime'] != null) ...[
                            _buildEventDetailRow(
                              icon: Icons.schedule,
                              label: 'When',
                              value: '${data['eventDate'] != null ? _formatEventDate(data['eventDate']) : ''}'
                                     '${data['eventTime'] != null ? ' at ${data['eventTime']}' : ''}',
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          if (data['eventAddress'] != null) ...[
                            _buildEventDetailRow(
                              icon: Icons.location_on,
                              label: 'Where',
                              value: data['eventAddress'],
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          if (data['eventDistance'] != null && data['eventPace'] != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEventDetailRow(
                                    icon: Icons.straighten,
                                    label: 'Distance',
                                    value: '${data['eventDistance']} ${data['eventDistanceUnit'] ?? 'mi'}',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildEventDetailRow(
                                    icon: Icons.speed,
                                    label: 'Pace',
                                    value: _getPaceLabel(data['eventPace']),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (data['eventDistance'] != null) ...[
                            _buildEventDetailRow(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value: '${data['eventDistance']} ${data['eventDistanceUnit'] ?? 'mi'}',
                            ),
                            const SizedBox(height: 12),
                          ] else if (data['eventPace'] != null) ...[
                            _buildEventDetailRow(
                              icon: Icons.speed,
                              label: 'Pace',
                              value: _getPaceLabel(data['eventPace']),
                            ),
                          ],
                        ],
                      ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    if (!eventExists) ...[
                      // Event no longer exists
                      Container(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _declineEventInvitation(notificationId);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red[300]!, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Event No Longer Available',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[600],
                            ),
                          ),
                        ),
                      ),
                    ] else if (hasJoined) ...[
                      // User has already joined
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _declineEventInvitation(notificationId);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: null, // Disabled
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Already Joined',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // User can still join
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _declineEventInvitation(notificationId);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Decline',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  if (eventId != null) {
                                    await _acceptEventInvitation(eventId, notificationId);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Join Event',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _acceptEventInvitation(String eventId, String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      
      // Get event data
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      
      if (!eventDoc.exists) {
        _showSnackBar('Event no longer exists');
        return;
      }
      
      final eventData = eventDoc.data() ?? {};
      final currentParticipants = List<String>.from(eventData['participants'] ?? []);
      final currentParticipantsData = List<Map<String, dynamic>>.from(eventData['participantsData'] ?? []);
      final currentInvitedUsers = List<String>.from(eventData['invitedUsers'] ?? []);
      
      // Check if already joined
      if (currentParticipants.contains(user.uid)) {
        _showSnackBar('You are already a participant in this event');
        return;
      }
      
      // Check capacity
      final groupSize = eventData['groupSize'] as int?;
      if (groupSize != null && currentParticipants.length >= groupSize) {
        _showSnackBar('Event is at capacity');
        return;
      }
      
      // Add user to event and remove from invited list
      final firstName = userData['firstName'] ?? '';
      final lastName = userData['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      
      currentParticipants.add(user.uid);
      currentParticipantsData.add({
        'uid': user.uid,
        'name': fullName.isNotEmpty ? fullName : 'User',
        'firstName': firstName,
        'lastName': lastName,
        'photoUrl': userData['photoUrl'],
      });
      
      // Remove from invited users list
      currentInvitedUsers.remove(user.uid);
      
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'participants': currentParticipants,
        'participantsData': currentParticipantsData,
        'invitedUsers': currentInvitedUsers,
      });
      
      // Create notification for the event organizer
      final creatorId = eventData['creatorId'] as String?;
      if (creatorId != null && creatorId != user.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': creatorId,
          'type': 'new_participant',
          'title': 'New Participant',
          'message': '$fullName joined your event "${eventData['eventName'] ?? 'event'}"',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'eventId': eventId,
            'eventName': eventData['eventName'],
            'eventType': eventData['eventType'],
            'participantName': fullName,
            'participantId': user.uid,
            'participantPhotoUrl': userData['photoUrl'],
          },
        });
      }
      
      // Delete the invitation notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      _showSnackBar('Successfully joined the event!');
    } catch (e) {
      _showSnackBar('Failed to join event: ${e.toString()}');
    }
  }
  
  Future<void> _declineEventInvitation(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Get the notification to find event details
      final notificationDoc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (notificationDoc.exists) {
        final notificationData = notificationDoc.data() as Map<String, dynamic>;
        final data = notificationData['data'] as Map<String, dynamic>? ?? {};
        final eventId = data['eventId'] as String?;
        
        if (eventId != null) {
          // Remove user from invited list in the event
          final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
          final eventDoc = await eventRef.get();
          
          if (eventDoc.exists) {
            final eventData = eventDoc.data() as Map<String, dynamic>;
            final invitedUsers = List<String>.from(eventData['invitedUsers'] ?? []);
            
            if (invitedUsers.contains(user.uid)) {
              invitedUsers.remove(user.uid);
              await eventRef.update({'invitedUsers': invitedUsers});
            }
          }
        }
      }
      
      // Delete the invitation notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      _showSnackBar('Event invitation declined');
    } catch (e) {
      _showSnackBar('Failed to decline invitation', backgroundColor: Colors.red[600]);
    }
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
  
  Widget _buildEventDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _getPaceLabel(String? pace) {
    if (pace == null || pace.isEmpty) return 'Not specified';
    
    switch (pace.toLowerCase()) {
      case 'social':
        return 'Social pace';
      case 'fitness':
        return 'Fitness pace';
      case 'competitive':
        return 'Competitive';
      default:
        return pace;
    }
  }
  
  String _getNotificationDayLabel(DateTime notificationDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDay = DateTime(notificationDate.year, notificationDate.month, notificationDate.day);
    
    if (notificationDay == today) {
      return 'Today';
    } else if (notificationDay == yesterday) {
      return 'Yesterday';
    } else {
      return 'Earlier';
    }
  }
  
  List<Widget> _buildGroupedNotifications(List<QueryDocumentSnapshot> notifications) {
    if (notifications.isEmpty) return [];
    
    final List<Widget> widgets = [];
    String? currentDayLabel;
    
    for (int i = 0; i < notifications.length; i++) {
      final doc = notifications[i];
      final notification = doc.data() as Map<String, dynamic>;
      final timestamp = notification['timestamp'] as Timestamp?;
      
      if (timestamp != null) {
        final notificationDate = timestamp.toDate();
        final dayLabel = _getNotificationDayLabel(notificationDate);
        
        // Add day header if this is a new day group
        if (currentDayLabel != dayLabel) {
          currentDayLabel = dayLabel;
          widgets.add(_buildNotificationDayHeader(dayLabel));
        }
      }
      
      widgets.add(_buildNotificationItem(doc.id, notification));
    }
    
    return widgets;
  }
  
  Widget _buildNotificationDayHeader(String dayLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Row(
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
