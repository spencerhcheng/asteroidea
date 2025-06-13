import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'event_detail_page.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class CreateEventPage extends StatefulWidget {
  final bool isModal;
  final bool isEdit;
  final String? eventId;
  final Map<String, dynamic>? initialEventData;
  final String? initialEventType;
  
  const CreateEventPage({
    super.key, 
    this.isModal = false,
    this.isEdit = false,
    this.eventId,
    this.initialEventData,
    this.initialEventType,
  });
  
  @override
  State<CreateEventPage> createState() => CreateEventPageState();
}

class CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  bool _showValidation = false;
  String _eventType = 'run';
  bool _isPublic = true;
  bool _womenOnly = false;
  String _runType = 'road';
  String _rideType = 'road';
  String _eventName = '';
  String _description = '';
  DateTime? _date;
  TimeOfDay? _startTime;
  String _address = '';
  double? _distance;
  String _distanceUnit = 'mi';
  String _pace = 'social';
  int? _groupSize;
  bool _isDescriptionExpanded = false;

  final List<String> _runTypes = ['road', 'trail'];
  final List<String> _rideTypes = ['road', 'gravel', 'mountain'];
  final List<String> _paceOptions = ['social', 'fitness', 'competitive'];

  bool _hasUnsavedChanges = false;
  final Map<String, dynamic> _initialValues = {};

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.initialEventData != null) {
      _populateFormFromEventData(widget.initialEventData!);
    } else if (widget.initialEventType != null) {
      // Set initial event type from modal selection
      _eventType = widget.initialEventType!;
    }
    _saveInitialValues();
  }

  void _populateFormFromEventData(Map<String, dynamic> eventData) {
    setState(() {
      _eventType = eventData['eventType'] ?? 'run';
      _isPublic = eventData['isPublic'] ?? true;
      _womenOnly = eventData['womenOnly'] ?? false;
      _eventName = eventData['eventName'] ?? '';
      _description = eventData['description'] ?? '';
      _address = eventData['address'] ?? '';
      _distance = eventData['distance']?.toDouble();
      _pace = eventData['pace'] ?? 'social';
      _groupSize = eventData['groupSize'];
      
      // Handle date conversion - standardized to Timestamp
      if (eventData['date'] != null) {
        if (eventData['date'] is Timestamp) {
          _date = (eventData['date'] as Timestamp).toDate();
        } else if (eventData['date'] is int) {
          // Legacy support for milliseconds
          _date = DateTime.fromMillisecondsSinceEpoch(eventData['date']);
        } else if (eventData['date'] is String) {
          _date = DateTime.tryParse(eventData['date']);
        }
      }
      
      // Handle time conversion
      if (eventData['startTime'] != null && eventData['startTime'].isNotEmpty) {
        final timeParts = eventData['startTime'].split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]);
          final minute = int.tryParse(timeParts[1]);
          if (hour != null && minute != null) {
            _startTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
      
      // Handle type field
      final typeValue = eventData['type'] ?? '';
      if (_eventType == 'run' && _runTypes.contains(typeValue)) {
        _runType = typeValue;
      } else if (_eventType == 'ride' && _rideTypes.contains(typeValue)) {
        _rideType = typeValue;
      }
    });
  }

  void _saveInitialValues() {
    _initialValues.clear();
    _initialValues.addAll({
      'eventType': _eventType,
      'isPublic': _isPublic,
      'womenOnly': _womenOnly,
      'runType': _runType,
      'rideType': _rideType,
      'eventName': _eventName,
      'description': _description,
      'date': _date,
      'startTime': _startTime,
      'address': _address,
      'distance': _distance,
      'distanceUnit': _distanceUnit,
      'pace': _pace,
      'groupSize': _groupSize,
    });
  }

  bool get hasUnsavedChanges {
    if (!_hasUnsavedChanges) return false;

    // Check if any field has been modified from its initial value
    return _eventType != _initialValues['eventType'] ||
        _isPublic != _initialValues['isPublic'] ||
        _womenOnly != _initialValues['womenOnly'] ||
        _runType != _initialValues['runType'] ||
        _rideType != _initialValues['rideType'] ||
        _eventName != _initialValues['eventName'] ||
        _description != _initialValues['description'] ||
        _date != _initialValues['date'] ||
        _startTime != _initialValues['startTime'] ||
        _address != _initialValues['address'] ||
        _distance != _initialValues['distance'] ||
        _distanceUnit != _initialValues['distanceUnit'] ||
        _pace != _initialValues['pace'] ||
        _groupSize != _initialValues['groupSize'];
  }

  void resetForm() {
    setState(() {
      _eventType = 'run';
      _isPublic = true;
      _womenOnly = false;
      _runType = 'road';
      _rideType = 'road';
      _eventName = '';
      _description = '';
      _date = null;
      _startTime = null;
      _address = '';
      _distance = null;
      _distanceUnit = 'mi';
      _pace = 'social';
      _groupSize = null;
      _isDescriptionExpanded = false;
      _hasUnsavedChanges = false;
      _showValidation = false;
      _formKey.currentState?.reset();
      _saveInitialValues();
    });
  }

  void _onEdit() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  String _getPaceLabel(String value) {
    switch (value) {
      case 'social':
        return 'Social (no drop)';
      case 'fitness':
        return 'Fitness';
      case 'competitive':
        return 'Competitive';
      default:
        return value;
    }
  }

  void _showSnackBar(SnackBar snackBar) {
    if (!mounted) return;
    // Clear any existing snackbars before showing the new one
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _saveEvent() async {
    setState(() => _showValidation = true);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Validate date and time are selected
    if (_date == null) {
      _showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_startTime == null) {
      _showSnackBar(
        const SnackBar(content: Text('Please select a start time')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String typeValue = _eventType == 'run' ? _runType : _rideType;
      if (_eventType == 'run' && typeValue != 'road' && typeValue != 'trail') {
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
        print('Error fetching creator name: $e');
      }
      
      // Create standardized event data with Timestamp
      final eventData = <String, dynamic>{
        'eventType': _eventType,
        'eventName': _eventName,
        'description': _description,
        'address': _address,
        'pace': _pace,
        'isPublic': _isPublic,
        'womenOnly': _womenOnly,
        'type': typeValue,
      };
      
      // Add date as Timestamp if set
      if (_date != null) {
        eventData['date'] = Timestamp.fromDate(_date!);
      }
      
      // Add start time if set
      if (_startTime != null) {
        eventData['startTime'] = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      }
      
      // Add optional numeric fields
      if (_distance != null) {
        eventData['distance'] = _distance;
        eventData['distanceUnit'] = _distanceUnit;
      }
      
      if (_groupSize != null) {
        eventData['groupSize'] = _groupSize;
      }
      
      if (widget.isEdit && widget.eventId != null) {
        // Update existing event - include updated creator name and photo in case they changed
        eventData['updatedAt'] = FieldValue.serverTimestamp();
        eventData['creatorName'] = creatorName;
        
        // Also update creator photo URL
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data() ?? {};
        eventData['creatorPhotoUrl'] = userData['photoUrl'];
        
        // Ensure organizer is still a participant (in case they were removed)
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId!)
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
            .doc(widget.eventId)
            .update(eventData);
        
        // Notify participants about the event changes
        await _notifyParticipantsOfChanges(widget.eventId!, eventDoc.data()!);
        
        if (!mounted) return;
        _showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        
        // Return true to indicate successful update
        Navigator.of(context).pop(true);
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
        
        if (!mounted) return;
        
        // Navigate to event detail page instead of showing snackbar and going back
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EventDetailPage(
              eventId: docRef.id,
              eventData: eventData,
            ),
          ),
        );
        return;
      }
    }
  }

  List<String> _getChanges(Map<String, dynamic> originalData) {
    List<String> changes = [];

    // Check event name
    if (_eventName != _initialValues['eventName']) {
      changes.add('Event name changed to "$_eventName"');
    }

    // Check date
    if (_date != _initialValues['date']) {
      if (_date != null) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final dateStr = '${months[_date!.month - 1]} ${_date!.day}, ${_date!.year}';
        changes.add('Date changed to $dateStr');
      }
    }

    // Check time
    if (_startTime != _initialValues['startTime']) {
      if (_startTime != null) {
        final hour = _startTime!.hour > 12 ? _startTime!.hour - 12 : _startTime!.hour == 0 ? 12 : _startTime!.hour;
        final minute = _startTime!.minute.toString().padLeft(2, '0');
        final period = _startTime!.hour >= 12 ? 'PM' : 'AM';
        changes.add('Time changed to $hour:$minute $period');
      }
    }

    // Check location
    if (_address != _initialValues['address']) {
      changes.add('Location changed to "$_address"');
    }

    // Check distance
    if (_distance != _initialValues['distance']) {
      if (_distance != null) {
        changes.add('Distance changed to $_distance $_distanceUnit');
      }
    }

    // Check pace
    if (_pace != _initialValues['pace']) {
      final paceLabels = {
        'social': 'Social',
        'fitness': 'Fitness',
        'competitive': 'Competitive'
      };
      changes.add('Pace changed to ${paceLabels[_pace] ?? _pace}');
    }

    // Check group size
    if (_groupSize != _initialValues['groupSize']) {
      if (_groupSize != null) {
        changes.add('Group size limit changed to $_groupSize');
      } else {
        changes.add('Group size limit removed');
      }
    }

    // Check privacy
    if (_isPublic != _initialValues['isPublic']) {
      changes.add(_isPublic ? 'Event made public' : 'Event made private');
    }

    // Check event type/category
    final currentType = _eventType == 'run' ? _runType : _rideType;
    final initialType = _eventType == 'run' ? _initialValues['runType'] : _initialValues['rideType'];
    if (currentType != initialType) {
      final typeLabels = {
        'road': _eventType == 'run' ? 'Road Run' : 'Road Ride',
        'trail': 'Trail Run',
        'track': 'Track Run',
        'gravel': 'Gravel Ride',
        'mountain': 'Mountain Bike',
      };
      changes.add('Type changed to ${typeLabels[currentType] ?? currentType}');
    }

    return changes;
  }

  Future<void> _notifyParticipantsOfChanges(String eventId, Map<String, dynamic> originalEventData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get the list of changes
    final changes = _getChanges(originalEventData);
    if (changes.isEmpty) return; // No meaningful changes to notify about

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
      if (participantId != user.uid) { // Don't notify the host
        final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
        
        // Create a summary of changes (limit to first 3 for brevity)
        final changesSummary = changes.take(3).join(', ');
        final additionalChanges = changes.length > 3 ? ' and ${changes.length - 3} more changes' : '';
        
        batch.set(notificationRef, {
          'userId': participantId,
          'type': 'event_update',
          'title': 'Event Updated',
          'message': '$hostName updated "${eventData['eventName'] ?? 'the event'}": $changesSummary$additionalChanges',
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

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${_eventName.isNotEmpty ? _eventName : 'this event'}"?\n\nThis action cannot be undone and any users signed up will be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.eventId != null) {
      try {
        await FirebaseFirestore.instance.collection('events').doc(widget.eventId).delete();
        if (!mounted) return;
        _showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
        Navigator.of(context).pop(); // Close the edit page
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(
          const SnackBar(content: Text('Failed to delete event')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleNavigation('back'),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.isEdit ? 'Edit Event' : 'Create Event'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: widget.isEdit 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () async {
                    if (hasUnsavedChanges) {
                      final discard = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Discard changes?'),
                          content: const Text(
                            'You have unsaved changes. Are you sure you want to leave?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                resetForm();
                                Navigator.of(context).pop(true);
                              },
                              child: const Text('Leave'),
                            ),
                          ],
                        ),
                      );
                      if (discard == true) {
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    } else {
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                )
              : null,
          actions: widget.isModal
              ? [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    tooltip: 'Cancel',
                    onPressed: () async {
                      if (hasUnsavedChanges) {
                        final discard = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Discard changes?'),
                            content: const Text(
                              'You have unsaved changes. Are you sure you want to leave?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  resetForm();
                                  Navigator.of(context).pop(true);
                                },
                                child: const Text('Leave'),
                              ),
                            ],
                          ),
                        );
                        if (discard == true) {
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      } else {
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ]
              : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: _showValidation
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Event Type Selector
                Row(
                  children: [
                    Expanded(
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
                                  color: _eventType == 'run'
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Run',
                                  style: TextStyle(
                                    color: _eventType == 'run'
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
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
                                  color: _eventType == 'ride'
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ride',
                                  style: TextStyle(
                                    color: _eventType == 'ride'
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        selected: {_eventType},
                        showSelectedIcon: false,
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _eventType = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>((
                                Set<MaterialState> states,
                              ) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.black;
                                }
                                return Colors.grey[200]!;
                              }),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Type dropdown
                DropdownButtonFormField<String>(
                  value: _eventType == 'run' ? _runType : _rideType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: (_eventType == 'run' ? _runTypes : _rideTypes)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.capitalize()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    if (_eventType == 'run') _runType = v ?? 'road';
                    if (_eventType == 'ride') _rideType = v ?? 'road';
                  }),
                  validator: (v) {
                    if (_eventType == 'run' && (v != 'road' && v != 'trail')) {
                      return 'Type must be Road or Trail';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _eventName,
                  decoration: const InputDecoration(labelText: 'Event Name *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Event name is required'
                      : null,
                  onChanged: (v) {
                    _eventName = v;
                    _onEdit();
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  initialValue: _description,
                  onChanged: (v) {
                    _description = v;
                    _onEdit();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                        ),
                        label: Text(
                          _date == null
                              ? 'Pick Date *'
                              : '${_date!.month}/${_date!.day}/${_date!.year}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: (_showValidation && _date == null) 
                              ? Colors.red[600] 
                              : Colors.black,
                          foregroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            _date = picked;
                            _onEdit();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.access_time,
                          color: Colors.white,
                        ),
                        label: Text(
                          _startTime == null
                              ? 'Start Time *'
                              : _startTime!.format(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: (_showValidation && _startTime == null) 
                              ? Colors.red[600] 
                              : Colors.black,
                          foregroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            _startTime = picked;
                            _onEdit();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: _address,
                        decoration: const InputDecoration(
                          labelText: 'Meeting location *',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Meeting location is required'
                            : null,
                        onChanged: (v) {
                          _address = v;
                          _onEdit();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_eventType == 'run' || _eventType == 'ride') ...[
                  TextFormField(
                    initialValue: _distance?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Distance *',
                      hintText: 'Enter approximate distance in miles',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Distance is required'
                        : null,
                    onChanged: (v) {
                      _distance = double.tryParse(v);
                      _onEdit();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Route Link (e.g. Strava, MapMyRun)',
                  ),
                  onChanged: (v) {
                    _onEdit();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _pace,
                  decoration: const InputDecoration(labelText: 'Pace/Speed *'),
                  items: _paceOptions
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(_getPaceLabel(p)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _pace = v ?? _paceOptions[0];
                      _onEdit();
                    });
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pace/Speed is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _groupSize?.toString() ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Group Size Limit (leave empty for no limit)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    _groupSize = int.tryParse(v);
                    _onEdit();
                  },
                ),
                const SizedBox(height: 24),
                // Toggles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Public', style: TextStyle(color: Colors.black87)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isPublic,
                          onChanged: (value) {
                            setState(() => _isPublic = value);
                            _onEdit();
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Women Only',
                          style: TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _womenOnly,
                          onChanged: (value) {
                            setState(() => _womenOnly = value);
                            _onEdit();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ShadButton(
                  onPressed: _saveEvent,
                  backgroundColor: const Color(
                    0xFFFFD600,
                  ), // Mustardy orange-yellow
                  child: Text(
                    widget.isEdit ? 'Update Event' : 'Launch Event',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Delete button - only show when editing
                if (widget.isEdit) ...[
                  const SizedBox(height: 16),
                  ShadButton.outline(
                    onPressed: _deleteEvent,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Delete Event',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }

  Future<bool> _handleNavigation(String destination) async {
    if (!_hasUnsavedChanges) {
      resetForm();
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (result ?? false) {
      resetForm();
      return true;
    }
    return false;
  }
}
