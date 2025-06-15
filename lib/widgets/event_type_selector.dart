import 'package:flutter/material.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class EventTypeSelector extends StatelessWidget {
  final String selectedEventType;
  final String runType;
  final String rideType;
  final List<String> runTypes;
  final List<String> rideTypes;
  final Function(String) onEventTypeChanged;
  final Function(String) onRunTypeChanged;
  final Function(String) onRideTypeChanged;

  const EventTypeSelector({
    super.key,
    required this.selectedEventType,
    required this.runType,
    required this.rideType,
    required this.runTypes,
    required this.rideTypes,
    required this.onEventTypeChanged,
    required this.onRunTypeChanged,
    required this.onRideTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                          color: selectedEventType == 'run'
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Run',
                          style: TextStyle(
                            color: selectedEventType == 'run'
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
                          color: selectedEventType == 'ride'
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ride',
                          style: TextStyle(
                            color: selectedEventType == 'ride'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                selected: {selectedEventType},
                showSelectedIcon: false,
                onSelectionChanged: (Set<String> newSelection) {
                  onEventTypeChanged(newSelection.first);
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
          ],
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: selectedEventType == 'run' ? runType : rideType,
          decoration: const InputDecoration(labelText: 'Type'),
          items: (selectedEventType == 'run' ? runTypes : rideTypes)
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.capitalize()),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (selectedEventType == 'run') {
              onRunTypeChanged(v ?? 'road');
            } else {
              onRideTypeChanged(v ?? 'road');
            }
          },
          validator: (v) {
            if (selectedEventType == 'run' && (v != 'road' && v != 'trail')) {
              return 'Type must be Road or Trail';
            }
            return null;
          },
        ),
      ],
    );
  }
}