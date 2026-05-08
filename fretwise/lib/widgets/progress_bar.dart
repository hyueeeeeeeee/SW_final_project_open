import 'package:flutter/material.dart';
import '../theme.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  final AppTheme t;
  final double height;

  const ProgressBar({
    super.key,
    required this.progress,
    required this.t,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = progress >= 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: t.surfaceAlt,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: isComplete ? AppColors.green : null,
              gradient: isComplete
                  ? null
                  : LinearGradient(colors: [t.accent, t.accentMid]),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    );
  }
}
