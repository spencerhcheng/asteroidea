import 'package:flutter/material.dart';

class OnboardingHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color>? gradientColors;

  const OnboardingHeader({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors ?? [Colors.blue[100]!, Colors.purple[100]!],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}