import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'widgets/event_type_selector.dart';
import 'widgets/date_time_picker.dart';
import 'widgets/event_settings_toggles.dart';
import 'services/event_service.dart';
import 'services/group_service.dart';
import 'event_detail.dart';


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
  
  // Group-related fields
  String _postAs = 'personal'; // 'personal' or groupId
  List<Map<String, dynamic>> _userGroups = [];
  bool _isLoadingGroups = false;

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
    _loadUserGroups();
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

    try {
      final eventId = await EventService.saveEvent(
        eventType: _eventType,
        eventName: _eventName,
        description: _description,
        date: _date!,
        startTime: _startTime!,
        address: _address,
        pace: _pace,
        isPublic: _isPublic,
        womenOnly: _womenOnly,
        runType: _runType,
        rideType: _rideType,
        distance: _distance,
        distanceUnit: _distanceUnit,
        groupSize: _groupSize,
        eventId: widget.isEdit ? widget.eventId : null,
      );

      if (!mounted) return;

      if (widget.isEdit) {
        _showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        Navigator.of(context).pop(true);
      } else {
        // Navigate to event detail page for new events
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EventDetailPage(
              eventId: eventId,
              eventData: {
                'eventType': _eventType,
                'eventName': _eventName,
                'description': _description,
                'address': _address,
                'pace': _pace,
                'isPublic': _isPublic,
                'womenOnly': _womenOnly,
                'distance': _distance,
                'groupSize': _groupSize,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        SnackBar(content: Text('Error saving event: $e')),
      );
    }
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
        await EventService.deleteEvent(widget.eventId!);
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _handleNavigation('back');
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
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
                EventTypeSelector(
                  selectedEventType: _eventType,
                  runType: _runType,
                  rideType: _rideType,
                  runTypes: _runTypes,
                  rideTypes: _rideTypes,
                  onEventTypeChanged: (newType) {
                    setState(() {
                      _eventType = newType;
                    });
                    _onEdit();
                  },
                  onRunTypeChanged: (newType) {
                    setState(() {
                      _runType = newType;
                    });
                    _onEdit();
                  },
                  onRideTypeChanged: (newType) {
                    setState(() {
                      _rideType = newType;
                    });
                    _onEdit();
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
                DateTimePicker(
                  selectedDate: _date,
                  selectedTime: _startTime,
                  showValidation: _showValidation,
                  onDateChanged: (newDate) {
                    setState(() {
                      _date = newDate;
                    });
                    _onEdit();
                  },
                  onTimeChanged: (newTime) {
                    setState(() {
                      _startTime = newTime;
                    });
                    _onEdit();
                  },
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
                EventSettingsToggles(
                  isPublic: _isPublic,
                  womenOnly: _womenOnly,
                  onPublicChanged: (value) {
                    setState(() => _isPublic = value);
                    _onEdit();
                  },
                  onWomenOnlyChanged: (value) {
                    setState(() => _womenOnly = value);
                    _onEdit();
                  },
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
