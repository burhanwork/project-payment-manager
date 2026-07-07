import 'package:flutter/material.dart';
import '../models/project.dart';
import '../utils/theme.dart';

class ProjectStatusBadge extends StatelessWidget {
  final ProjectStatus status;
  final bool compact;
  const ProjectStatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _color.withValues(alpha: compact ? 0.25 : 0.15),
            _color.withValues(alpha: compact ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: compact ? 0.5 : 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: compact ? Colors.white : _color, size: compact ? 10 : 14),
          const SizedBox(width: 3),
          Text(
            _label,
            style: TextStyle(
              color: compact ? Colors.white : _color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (status) {
      case ProjectStatus.planned:
        return AppTheme.warningColor;
      case ProjectStatus.inProgress:
        return AppTheme.accentColor;
      case ProjectStatus.completed:
        return AppTheme.successColor;
    }
  }

  IconData get _icon {
    switch (status) {
      case ProjectStatus.planned:
        return Icons.schedule;
      case ProjectStatus.inProgress:
        return Icons.trending_up;
      case ProjectStatus.completed:
        return Icons.check_circle;
    }
  }

  String get _label {
    switch (status) {
      case ProjectStatus.planned:
        return 'Planned';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }
}
