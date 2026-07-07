import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/project.dart';
import '../../models/payment.dart';
import '../../models/deletion_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/deletion_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/project_status_badge.dart';
import '../../widgets/payment_status_badge.dart';
import '../../widgets/approval_indicator.dart';
import '../../animations/page_transitions.dart';
import '../payments/payment_detail_screen.dart';
import '../payments/create_payment_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _isRequestingDeletion = false;
  bool _isUpdatingCompletion = false;
  double? _pendingCompletion;
  double _titleOpacity = 0.0;
  final ScrollController _scrollController = ScrollController();

  // Computed in build() based on device status bar height
  double _expandedHeight = 148.0;
  double _fadeStart = 148.0 - kToolbarHeight - 30;
  double _fadeEnd = 148.0 - kToolbarHeight;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      double opacity = 0.0;
      if (offset >= _fadeEnd) {
        opacity = 1.0;
      } else if (offset > _fadeStart) {
        opacity = (offset - _fadeStart) / (_fadeEnd - _fadeStart);
      }
      if (opacity != _titleOpacity) {
        setState(() => _titleOpacity = opacity);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 24),
            const SizedBox(width: 10),
            Text(
              'Delete Project',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'This will create a deletion request that requires approval from all 3 roles (Developer, Boss, Accountant) before the project and all its payments are permanently deleted.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Request Deletion',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRequestingDeletion = true);

    try {
      await ref.read(deletionsProvider.notifier).createDeletionRequest(
            targetType: 'project',
            targetId: widget.project.id,
          );

      if (!mounted) return;
      setState(() => _isRequestingDeletion = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Deletion request created',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequestingDeletion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed: $e',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  bool _isRequestingMilestoneDeletion = false;

  Future<void> _requestMilestoneDeletion(String milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppTheme.errorColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Milestone',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Request deletion of "$milestone"? All 3 roles must approve before it is removed.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Request Deletion',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || _isRequestingMilestoneDeletion) return;

    setState(() => _isRequestingMilestoneDeletion = true);
    try {
      await ref.read(deletionsProvider.notifier).createDeletionRequest(
            targetType: 'milestone',
            targetId: widget.project.id,
            milestoneName: milestone,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Deletion request sent for "$milestone"',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed: $e',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequestingMilestoneDeletion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectsProvider).firstWhere(
          (p) => p.id == widget.project.id,
          orElse: () => widget.project,
        );
    final currentUser = ref.watch(currentUserProvider);
    final allPayments = ref.watch(paymentsProvider);
    final projectPayments = allPayments
        .where((p) =>
            p.projectId == project.id &&
            p.status != PaymentStatus.rejected)
        .toList();
    final canAddPayment = currentUser != null &&
        (currentUser.role == UserRole.developer ||
            currentUser.role == UserRole.accountant ||
            currentUser.role == UserRole.boss);
    final progress = project.progressPercentage / 100;

    // Check for active deletion request
    final deletions = ref.watch(deletionsProvider);
    final activeDeletion = deletions.where((d) =>
        d.targetType == DeletionTargetType.project &&
        d.targetId == project.id &&
        (d.status == PaymentStatus.pending ||
            d.status == PaymentStatus.partiallyApproved)).firstOrNull;
    final hasActiveDeletion = activeDeletion != null;

    // Normalise total header height across devices (same logic as dashboard)
    final statusBarHeight = MediaQuery.of(context).padding.top;
    _expandedHeight = (202.0 - statusBarHeight).clamp(100.0, 170.0);
    _fadeStart = _expandedHeight - kToolbarHeight - 30;
    _fadeEnd = _expandedHeight - kToolbarHeight;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Sliver AppBar
          SliverAppBar(
            expandedHeight: _expandedHeight,
            pinned: true,
            stretch: true,
            title: Transform.translate(
              offset: Offset(0, (1.0 - _titleOpacity) * 12),
              child: Opacity(
                opacity: _titleOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.8), size: 11),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            project.clientName,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time_rounded,
                            color: Colors.white.withValues(alpha: 0.7), size: 11),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            Formatters.dateTime(project.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ProjectStatusBadge(status: project.status, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          project.name,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideX(
                              begin: -0.1,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.75), size: 14),
                            const SizedBox(width: 5),
                            Text(
                              project.clientName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.access_time_rounded,
                                color: Colors.white.withValues(alpha: 0.65), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              Formatters.dateTime(project.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ProjectStatusBadge(status: project.status),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Deletion request banner
                if (hasActiveDeletion)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: AppTheme.errorColor, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Deletion Requested',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                            Text(
                              '${activeDeletion.approvals.approvalCount}/3 approved',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ApprovalIndicator(
                            approvals: activeDeletion.approvals, compact: true),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.05, curve: Curves.easeOutCubic),

                // Financial Summary Card
                _buildFinancialCard(progress, project)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.1,
                      delay: 100.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 16),

                // Completion Card
                _buildCompletionCard(project, currentUser)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.1,
                      delay: 150.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 16),

                // Timeline Card
                _buildTimelineCard(project)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.1,
                      delay: 200.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),

                // Milestones Card
                if (project.milestones.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.flag_circle_rounded,
                                color: AppTheme.successColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Milestones',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${project.milestones.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...project.milestones.asMap().entries.map((entry) {
                          final milestoneName = entry.value;
                          final isPaid = projectPayments.any((p) =>
                              p.module == milestoneName &&
                              p.status == PaymentStatus.approved);
                          // Check if there's a pending deletion request for this milestone
                          final milestoneDeletion = deletions.where((d) =>
                              d.targetType == DeletionTargetType.milestone &&
                              d.targetId == project.id &&
                              d.targetName == milestoneName &&
                              (d.status == PaymentStatus.pending ||
                                  d.status == PaymentStatus.partiallyApproved)).firstOrNull;
                          final hasPendingDeletion = milestoneDeletion != null;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key <
                                      project.milestones.length - 1
                                  ? 8
                                  : 0,
                            ),
                            child: GestureDetector(
                              onLongPress: hasPendingDeletion
                                  ? null
                                  : () => _requestMilestoneDeletion(milestoneName),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: hasPendingDeletion
                                      ? AppTheme.errorColor.withValues(alpha: 0.04)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? AppTheme.successColor
                                                .withValues(alpha: 0.1)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: isPaid
                                            ? Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: AppTheme.successColor,
                                              )
                                            : Text(
                                                '${entry.key + 1}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        milestoneName,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isPaid
                                              ? AppTheme.primaryDark
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    if (isPaid && !hasPendingDeletion)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Paid',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.successColor,
                                          ),
                                        ),
                                      ),
                                    if (hasPendingDeletion)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.errorColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Deletion Pending',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.errorColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms)
                      .slideY(
                        begin: 0.1,
                        delay: 250.ms,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ],

                const SizedBox(height: 24),

                // Payment History Header
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Payment History',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${projectPayments.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.1,
                      delay: 300.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: 12),

                // Payment List or Empty State
                if (projectPayments.isEmpty)
                  _buildEmptyPayments()
                      .animate()
                      .fadeIn(delay: 350.ms, duration: 400.ms)
                else
                  ...projectPayments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final payment = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PaymentCard(payment: payment),
                    )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 350 + (index * 80)),
                          duration: 400.ms,
                        )
                        .slideY(
                          begin: 0.1,
                          delay: Duration(milliseconds: 350 + (index * 80)),
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        );
                  }),

                // Request Deletion Button
                if (!hasActiveDeletion && currentUser != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isRequestingDeletion ? null : _requestDeletion,
                      icon: _isRequestingDeletion
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 20),
                      label: Text(
                        'Request Deletion',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(
                          color: AppTheme.errorColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(
                          milliseconds:
                              400 + (projectPayments.length * 80),
                        ),
                        duration: 400.ms,
                      )
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                ],
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: canAddPayment
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  SmoothPageRoute(
                    page: CreatePaymentScreen(projectId: project.id),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Payment'),
            )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                delay: 400.ms,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(delay: 400.ms, duration: 300.ms)
          : null,
    );
  }

  Widget _buildFinancialCard(double progress, Project project) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Financial Summary',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _FinancialColumn(
                label: 'Total Cost',
                value: Formatters.currency(project.totalCost),
                color: AppTheme.primaryColor,
                icon: Icons.account_balance_rounded,
              ),
              _FinancialColumn(
                label: 'Paid',
                value: Formatters.currency(project.totalPaid),
                color: AppTheme.successColor,
                icon: Icons.check_circle_outline_rounded,
              ),
              _FinancialColumn(
                label: 'Remaining',
                value: Formatters.currency(project.remainingBalance),
                color: AppTheme.warningColor,
                icon: Icons.pending_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _progressColor(value),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Formatters.percentage(project.progressPercentage),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _progressColor(progress),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(Project project, AppUser? currentUser) {
    final isDeveloper = currentUser?.role == UserRole.developer;
    final currentVal = _pendingCompletion ?? project.completionPercentage;
    final displayVal = currentVal.clamp(0.0, 100.0);
    final barColor = displayVal >= 100
        ? AppTheme.successColor
        : displayVal >= 50
            ? AppTheme.primaryColor
            : Colors.blueGrey;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, isDeveloper ? 24 : 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.donut_large_rounded, color: barColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Project Completion',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              Text(
                '${displayVal.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: displayVal / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: barColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          if (isDeveloper) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.edit_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Update Completion',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${displayVal.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: barColor,
                inactiveTrackColor: barColor.withValues(alpha: 0.15),
                thumbColor: barColor,
                overlayColor: barColor.withValues(alpha: 0.15),
                trackHeight: 4,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: displayVal,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _pendingCompletion = v),
                onChangeEnd: (_) {},
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isUpdatingCompletion
                    ? null
                    : () async {
                        setState(() => _isUpdatingCompletion = true);
                        try {
                          await ref
                              .read(projectsProvider.notifier)
                              .updateCompletionPercentage(
                                  project.id, displayVal);
                          setState(() => _pendingCompletion = null);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Completion updated to ${displayVal.toStringAsFixed(0)}%',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppTheme.successColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: AppTheme.errorColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUpdatingCompletion = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: barColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUpdatingCompletion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save Completion',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Only developers can update completion',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Project project) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Timeline',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TimelineItem(
                  label: 'Start Date',
                  value: Formatters.date(project.startDate),
                  icon: Icons.play_circle_outline_rounded,
                  color: AppTheme.accentColor,
                ),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.grey.shade300,
                  size: 20,
                ),
              ),
              Expanded(
                child: _TimelineItem(
                  label: 'End Date',
                  value: Formatters.date(project.expectedCompletionDate),
                  icon: Icons.flag_rounded,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPayments() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No payments yet',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the first payment for this project',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _progressColor(double progress) {
    if (progress >= 1.0) return AppTheme.successColor;
    if (progress >= 0.5) return AppTheme.accentColor;
    return AppTheme.warningColor;
  }
}

class _FinancialColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _FinancialColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
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

class _TimelineItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimelineItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Payment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            SmoothPageRoute(
              page: PaymentDetailScreen(paymentId: payment.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title, amount
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.payment_rounded,
                      color: AppTheme.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.date(payment.date),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.currency(payment.amount),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bottom row: status badge + approval indicator
              Row(
                children: [
                  PaymentStatusBadge(status: payment.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ApprovalIndicator(
                      approvals: payment.approvals,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
