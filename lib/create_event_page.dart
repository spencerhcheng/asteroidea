import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class CreateEventPage extends StatefulWidget {
  final bool isModal;
  const CreateEventPage({super.key, this.isModal = false});
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
    _saveInitialValues();
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

  Future<void> _saveEvent() async {
    setState(() => _showValidation = true);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String typeValue = _eventType == 'run' ? _runType : _rideType;
      if (_eventType == 'run' && typeValue != 'road' && typeValue != 'trail') {
        typeValue = 'road';
      }
      final event = {
        'eventType': _eventType,
        'creatorId': user.uid,
        'eventName': _eventName,
        'description': _description,
        'date': _date?.millisecondsSinceEpoch,
        'startTime': _startTime != null
            ? '${_startTime!.hour}:${_startTime!.minute}'
            : null,
        'address': _address,
        'distance': _distance,
        'pace': _pace,
        'groupSize': _groupSize,
        'isPublic': _isPublic,
        'womenOnly': _womenOnly,
        'type': typeValue,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('events').add(event);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event created!')));
      resetForm();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleNavigation('back'),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Create Event'),
          backgroundColor: Colors.white,
          elevation: 0,
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
                // Expandable Description Field
                ExpansionTile(
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isDescriptionExpanded = expanded;
                    });
                  },
                  initiallyExpanded: _isDescriptionExpanded,
                  title: Text(
                    _description.isEmpty ? 'Add Description' : 'Description',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: _description.isEmpty
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  children: _isDescriptionExpanded
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: null,
                                  textInputAction: TextInputAction.done,
                                  initialValue: _description,
                                  onChanged: (v) {
                                    _description = v;
                                    _onEdit();
                                  },
                                  onEditingComplete: () {
                                    FocusScope.of(context).unfocus();
                                    setState(
                                      () => _isDescriptionExpanded = false,
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                ShadButton(
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() {
                                      _isDescriptionExpanded = false;
                                    });
                                  },
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : [],
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
                              ? 'Pick Date'
                              : '${_date!.month}/${_date!.day}/${_date!.year}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black,
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
                              ? 'Start Time'
                              : _startTime!.format(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black,
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
                  decoration: const InputDecoration(
                    labelText: 'Group Size Limit',
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
                  child: const Text(
                    'Create Event',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
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
