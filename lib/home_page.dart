import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedFilter = 'upcoming';
  Set<String> _selectedActivities = {};
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
      setState(() {
        _selectedActivities = prefs.toSet();
        _loadingPrefs = false;
      });
    } else {
      setState(() {
        _selectedActivities = {'run', 'ride'};
        _loadingPrefs = false;
      });
    }
  }

  void _toggleActivity(String activity) {
    setState(() {
      if (_selectedActivities.contains(activity)) {
        if (_selectedActivities.length > 1) {
          _selectedActivities.remove(activity);
        }
      } else {
        _selectedActivities.add(activity);
      }
    });
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = 'upcoming'),
                              child: ShadBadge(
                                backgroundColor: _selectedFilter == 'upcoming'
                                    ? Colors.blue
                                    : Colors.grey[200],
                                child: Text(
                                  'Upcoming',
                                  style: TextStyle(
                                    color: _selectedFilter == 'upcoming'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = 'hosting'),
                              child: ShadBadge(
                                backgroundColor: _selectedFilter == 'hosting'
                                    ? Colors.blue
                                    : Colors.grey[200],
                                child: Text(
                                  'Hosting',
                                  style: TextStyle(
                                    color: _selectedFilter == 'hosting'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = 'open'),
                              child: ShadBadge(
                                backgroundColor: _selectedFilter == 'open'
                                    ? Colors.blue
                                    : Colors.grey[200],
                                child: Text(
                                  'Open Invite',
                                  style: TextStyle(
                                    color: _selectedFilter == 'open'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ShadButton(
                                onPressed: () => _toggleActivity('run'),
                                backgroundColor:
                                    _selectedActivities.contains('run')
                                    ? Colors.black
                                    : Colors.white,
                                foregroundColor:
                                    _selectedActivities.contains('run')
                                    ? Colors.white
                                    : Colors.black87,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_run,
                                      color: _selectedActivities.contains('run')
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Running',
                                      style: TextStyle(
                                        color:
                                            _selectedActivities.contains('run')
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedActivities.contains('run'))
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ShadButton(
                                onPressed: () => _toggleActivity('ride'),
                                backgroundColor:
                                    _selectedActivities.contains('ride')
                                    ? Colors.black
                                    : Colors.white,
                                foregroundColor:
                                    _selectedActivities.contains('ride')
                                    ? Colors.white
                                    : Colors.black87,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_bike,
                                      color:
                                          _selectedActivities.contains('ride')
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cycling',
                                      style: TextStyle(
                                        color:
                                            _selectedActivities.contains('ride')
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedActivities.contains('ride'))
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                      // Filter events by selected activities
                      final filteredEvents = events.where((e) {
                        final type = e['eventType'] ?? '';
                        return _selectedActivities.contains(type);
                      }).toList();
                      if (filteredEvents.isEmpty) {
                        return const Center(
                          child: Text('No events for selected activities.'),
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
                          final e = filteredEvents[i].data();
                          return Material(
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
                                            Text(
                                              'Organized by ${e['organizerName'] ?? 'Unknown'}',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (e['isPublic'] == false)
                                        const Icon(
                                          Icons.lock,
                                          color: Colors.white70,
                                          size: 20,
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
                                        Icons.calendar_today,
                                        color: Colors.blue[300],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        e['date'] != null
                                            ? e['date'].toString().substring(
                                                0,
                                                10,
                                              )
                                            : '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.blue[300],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        e['startTime'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
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
                                          '${e['distance']} ${e['distanceUnit']}',
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
