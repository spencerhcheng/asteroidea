import 'package:flutter/material.dart';

class DateTimePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final Function(DateTime?) onDateChanged;
  final Function(TimeOfDay?) onTimeChanged;
  final bool showValidation;

  const DateTimePicker({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.showValidation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(
              Icons.calendar_today,
              color: Colors.white,
            ),
            label: Text(
              selectedDate == null
                  ? 'Pick Date *'
                  : '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}',
              style: const TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: (showValidation && selectedDate == null) 
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
                onDateChanged(picked);
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
              selectedTime == null
                  ? 'Start Time *'
                  : selectedTime!.format(context),
              style: const TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: (showValidation && selectedTime == null) 
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
                onTimeChanged(picked);
              }
            },
          ),
        ),
      ],
    );
  }
}