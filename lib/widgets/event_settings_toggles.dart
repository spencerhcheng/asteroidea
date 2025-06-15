import 'package:flutter/material.dart';

class EventSettingsToggles extends StatelessWidget {
  final bool isPublic;
  final bool womenOnly;
  final Function(bool) onPublicChanged;
  final Function(bool) onWomenOnlyChanged;

  const EventSettingsToggles({
    super.key,
    required this.isPublic,
    required this.womenOnly,
    required this.onPublicChanged,
    required this.onWomenOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('Public', style: TextStyle(color: Colors.black87)),
            const SizedBox(width: 8),
            Switch(
              value: isPublic,
              onChanged: onPublicChanged,
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
              value: womenOnly,
              onChanged: onWomenOnlyChanged,
            ),
          ],
        ),
      ],
    );
  }
}