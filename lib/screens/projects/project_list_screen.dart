import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/project.dart';
import '../../models/deletion_request.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/deletion_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/project_status_badge.dart';
import '../../animations/page_transitions.dart';
import 'project_detail_screen.dart';
import 'create_project_screen.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final canCreate = currentUser != null &&
        (currentUser.role == UserRole.developer ||
            currentUser.role == UserRole.accountant ||
            currentUser.role == UserRole.boss);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(projectsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: projects.isNotEmpty
          ? _buildProjectList(context, projects)
          : _buildEmptyState(context),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  SmoothPageRoute(page: const CreateProjectScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Project'),
            )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                delay: 300.ms,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(delay: 300.ms, duration: 300.ms)
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Projects Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first project to get started',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          duration: 500.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildProjectList(BuildContext context, List<Project> projects) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          ...projects.asMap().entries.map((entry) {
            final project = entry.value;
            return _ProjectCard(project: project)
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: entry.key * 80),
                  duration: 400.ms,
                )
                .slideY(
                  begin: 0.15,
                  delay: Duration(milliseconds: entry.key * 80),
                  duration: 400.ms,
                  curve: Curves.easeOutCubic,
                );
          }),
        ],
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final Project project;

  const _ProjectCard({required this.project});

  void _showDeleteOption(BuildContext context, WidgetRef ref) {
    final deletions = ref.read(deletionsProvider);
    final existingRequest = deletions.where((d) =>
        d.targetType == DeletionTargetType.project &&
        d.targetId == project.id &&
        (d.status == PaymentStatus.pending ||
            d.status == PaymentStatus.partiallyApproved)).toList();

    if (existingRequest.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'A deletion request for this project is already ${existingRequest.first.statusDisplayName.toLowerCase()}'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                project.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Colors.red.shade600),
                ),
                title: Text(
                  'Request Deletion',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                subtitle: Text(
                  'Requires approval from all roles',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletion(context, ref);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletion(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Request Project Deletion',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
        content: Text(
          'Are you sure you want to request deletion of "${project.name}"? This will require approval from all roles before the project is deleted.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(deletionsProvider.notifier).createDeletionRequest(
                      targetType: 'project',
                      targetId: project.id,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deletion request submitted for approval'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to request deletion: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = project.progressPercentage / 100;
    final initial = project.name.isNotEmpty ? project.name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              SmoothPageRoute(
                page: ProjectDetailScreen(project: project),
              ),
            );
          },
          onLongPress: () => _showDeleteOption(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar, name, status
                Row(
                  children: [
                    // Project initial avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name & client
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            project.clientName,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, yyyy – hh:mm a').format(project.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ProjectStatusBadge(status: project.status),
                  ],
                ),
                const SizedBox(height: 16),
                // Financial summary
                Row(
                  children: [
                    _FinancialItem(
                      label: 'Total',
                      value: Formatters.currency(project.totalCost),
                      color: AppTheme.primaryColor,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.grey.shade200,
                    ),
                    _FinancialItem(
                      label: 'Paid',
                      value: Formatters.currency(project.totalPaid),
                      color: AppTheme.successColor,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.grey.shade200,
                    ),
                    _FinancialItem(
                      label: 'Remaining',
                      value: Formatters.currency(project.remainingBalance),
                      color: AppTheme.warningColor,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Payment progress bar
                _ProgressRow(
                  label: 'Payment',
                  percentage: project.progressPercentage,
                  color: _progressColor(progress),
                ),
                const SizedBox(height: 8),
                // Completion progress bar
                _ProgressRow(
                  label: 'Completion',
                  percentage: project.completionPercentage,
                  color: _completionColor(project.completionPercentage / 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _progressColor(double progress) {
    if (progress >= 1.0) return AppTheme.successColor;
    if (progress >= 0.5) return AppTheme.accentColor;
    return AppTheme.warningColor;
  }

  Color _completionColor(double progress) {
    if (progress >= 1.0) return AppTheme.successColor;
    if (progress >= 0.5) return AppTheme.primaryColor;
    return Colors.blueGrey;
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = (percentage / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _FinancialItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FinancialItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
