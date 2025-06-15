import 'package:flutter/material.dart';

class OnboardingProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;
  final String? backLabel;

  const OnboardingProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    this.onBack,
    this.backLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button or step text
              GestureDetector(
                onTap: onBack,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      backLabel ?? (currentStep > 0 ? 'Back' : 'Back to Login'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${((currentStep + 1) / totalSteps * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented progress bar
          Row(
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < totalSteps - 1 ? 4 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.grey[200],
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isCompleted || isCurrent ? Colors.blue[600] : Colors.grey[200],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}