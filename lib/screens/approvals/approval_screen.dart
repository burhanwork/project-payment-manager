import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/payment.dart';
import '../../models/deletion_request.dart';
import '../../models/account_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/deletion_provider.dart';
import '../../providers/account_request_provider.dart';
import '../../providers/bank_account_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/payment_status_badge.dart';
import '../../widgets/approval_indicator.dart';
import '../payments/payment_detail_screen.dart';
import '../accounts/account_detail_screen.dart';

class ApprovalScreen extends ConsumerStatefulWidget {
  const ApprovalScreen({super.key});

  @override
  ConsumerState<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends ConsumerState<ApprovalScreen> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    ref.read(paymentsProvider.notifier).refresh();
    ref.read(projectsProvider.notifier).refresh();
    ref.read(deletionsProvider.notifier).refresh();
    ref.read(accountRequestsProvider.notifier).refresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  bool? _getApprovalForRole(PaymentApproval approvals, UserRole role) {
    switch (role) {
      case UserRole.developer:
        return approvals.developer;
      case UserRole.boss:
        return approvals.boss;
      case UserRole.accountant:
        return approvals.accountant;
    }
  }

  String _getProjectName(String projectId) {
    final projects = ref.read(projectsProvider);
    final match = projects.where((p) => p.id == projectId);
    if (match.isNotEmpty) return match.first.name;
    return 'Unknown Project';
  }

  Future<void> _approvePayment(String paymentId, AppUser user) async {
    try {
      await ref.read(paymentsProvider.notifier).approvePayment(
            paymentId: paymentId,
            role: user.role,
            userId: user.uid,
          );
      ref.read(projectsProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectPayment(String paymentId, AppUser user) async {
    try {
      await ref.read(paymentsProvider.notifier).rejectPayment(
            paymentId: paymentId,
            role: user.role,
            userId: user.uid,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _approveDeletion(String deletionId, AppUser user) async {
    try {
      await ref.read(deletionsProvider.notifier).approveDeletion(
            deletionId: deletionId,
            role: user.role,
            userId: user.uid,
          );
      ref.read(projectsProvider.notifier).refresh();
      ref.read(paymentsProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve deletion: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectDeletion(String deletionId, AppUser user) async {
    try {
      await ref.read(deletionsProvider.notifier).rejectDeletion(
            deletionId: deletionId,
            role: user.role,
            userId: user.uid,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject deletion: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final payments = ref.watch(paymentsProvider);
    final accountRequests = ref.watch(accountRequestsProvider);
    ref.watch(projectsProvider);
    final deletions = ref.watch(deletionsProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    final needsAction = payments.where((p) {
      final roleApproval = _getApprovalForRole(p.approvals, currentUser.role);
      return roleApproval == null &&
          p.status != PaymentStatus.rejected &&
          p.status != PaymentStatus.approved;
    }).toList();

    final yourVotes = payments.where((p) {
      final roleApproval = _getApprovalForRole(p.approvals, currentUser.role);
      return roleApproval != null &&
          p.status != PaymentStatus.approved &&
          p.status != PaymentStatus.rejected;
    }).toList();

    // Deletion requests needing current user's action
    final deletionNeedsAction = deletions.where((d) {
      final roleApproval = _getApprovalForRole(d.approvals, currentUser.role);
      return roleApproval == null &&
          d.status != PaymentStatus.rejected &&
          d.status != PaymentStatus.approved;
    }).toList();

    final deletionYourVotes = deletions.where((d) {
      final roleApproval = _getApprovalForRole(d.approvals, currentUser.role);
      return roleApproval != null &&
          d.status != PaymentStatus.approved &&
          d.status != PaymentStatus.rejected;
    }).toList();

    // Account requests needing current user's action
    final accountRequestNeedsAction = accountRequests.where((r) {
      final roleApproval = _getApprovalForRole(r.approvals, currentUser.role);
      return roleApproval == null &&
          r.status != PaymentStatus.rejected &&
          r.status != PaymentStatus.approved;
    }).toList();

    final accountRequestYourVotes = accountRequests.where((r) {
      final roleApproval = _getApprovalForRole(r.approvals, currentUser.role);
      return roleApproval != null &&
          r.status != PaymentStatus.approved &&
          r.status != PaymentStatus.rejected;
    }).toList();

    final pendingCount = needsAction.length + deletionNeedsAction.length + accountRequestNeedsAction.length;

    // "All Caught Up!" only when nothing is in-flight for any user
    final totalInFlight = pendingCount +
        yourVotes.length +
        deletionYourVotes.length +
        accountRequestYourVotes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Card
            _buildSummaryCard(pendingCount, totalInFlight)
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            const SizedBox(height: 24),

            // Needs Your Action Section
            _buildSectionHeader(
              'Needs Your Action',
              Icons.pending_actions_rounded,
              AppTheme.warningColor,
              needsAction.length + deletionNeedsAction.length + accountRequestNeedsAction.length,
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .slideX(begin: -0.05, curve: Curves.easeOut),
            const SizedBox(height: 12),

            if (needsAction.isEmpty && deletionNeedsAction.isEmpty && accountRequestNeedsAction.isEmpty)
              _buildEmptyState(
                'No pending approvals',
                'You\'re all caught up!',
                Icons.check_circle_outline_rounded,
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    curve: Curves.easeOut,
                  ),

            ...needsAction.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final payment = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPaymentCard(
                  payment: payment,
                  currentUser: currentUser,
                  showActions: true,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 150 + (index * 80)),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      delay: Duration(milliseconds: 150 + (index * 80)),
                      curve: Curves.easeOutCubic,
                    ),
              );
            }),

            ...deletionNeedsAction.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final deletion = entry.value;
              final offset = needsAction.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDeletionCard(
                  deletion: deletion,
                  currentUser: currentUser,
                  showActions: true,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 150 + ((offset + index) * 80)),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      delay: Duration(milliseconds: 150 + ((offset + index) * 80)),
                      curve: Curves.easeOutCubic,
                    ),
              );
            }),

            ...accountRequestNeedsAction.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final request = entry.value;
              final offset = needsAction.length + deletionNeedsAction.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAccountRequestCard(
                  request: request,
                  currentUser: currentUser,
                  showActions: true,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 150 + ((offset + index) * 80)),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      delay: Duration(milliseconds: 150 + ((offset + index) * 80)),
                      curve: Curves.easeOutCubic,
                    ),
              );
            }),

            const SizedBox(height: 24),

            // Your Votes Section
            _buildSectionHeader(
              'Your Votes',
              Icons.how_to_vote_rounded,
              AppTheme.primaryLight,
              yourVotes.length + deletionYourVotes.length + accountRequestYourVotes.length,
            )
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 200 + (pendingCount * 80)),
                  duration: 400.ms,
                )
                .slideX(begin: -0.05, curve: Curves.easeOut),
            const SizedBox(height: 12),

            if (yourVotes.isEmpty && deletionYourVotes.isEmpty && accountRequestYourVotes.isEmpty)
              _buildEmptyState(
                'No votes yet',
                'Your approval history will appear here',
                Icons.how_to_vote_outlined,
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 300 + (pendingCount * 80)),
                    duration: 400.ms,
                  ),

            ...yourVotes.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final payment = entry.value;
              final baseDelay = 250 + (pendingCount * 80);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPaymentCard(
                  payment: payment,
                  currentUser: currentUser,
                  showActions: false,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: baseDelay + (index * 80)),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      delay: Duration(milliseconds: baseDelay + (index * 80)),
                      curve: Curves.easeOutCubic,
                    ),
              );
            }),

            ...deletionYourVotes.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final deletion = entry.value;
              final baseDelay = 250 + (pendingCount * 80) + (yourVotes.length * 80);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDeletionCard(
                  deletion: deletion,
                  currentUser: currentUser,
                  showActions: false,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: baseDelay + (index * 80)),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      delay: Duration(milliseconds: baseDelay + (index * 80)),
                      curve: Curves.easeOutCubic,
                    ),
              );
            }),

            ...accountRequestYourVotes.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final request = entry.value;
              final baseDelay = 250 + (pendingCount * 80) + ((yourVotes.length + deletionYourVotes.length) * 80);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAccountRequestCard(
                  request: request,
                  currentUser: currentUser,
                  showActions: false,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: baseDelay + (index * 80)),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      delay: Duration(milliseconds: baseDelay + (index * 80)),
                      curve: Curves.easeOutCubic,
                    ),
              );
            }),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int pendingCount, int totalInFlight) {
    final bool hasPending = pendingCount > 0;
    final bool allDone = totalInFlight == 0;
    final gradient = allDone ? AppTheme.successGradient : AppTheme.warningGradient;
    final icon = allDone
        ? Icons.check_circle_rounded
        : Icons.pending_actions_rounded;
    final title = allDone
        ? 'All Caught Up!'
        : hasPending
            ? '$pendingCount Pending'
            : 'Awaiting Others';
    final subtitle = allDone
        ? 'No items need your approval right now'
        : hasPending
            ? 'Item${pendingCount == 1 ? '' : 's'} waiting for your review'
            : 'You\'ve voted — waiting for other approvals';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (allDone ? AppTheme.successColor : AppTheme.warningColor)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required Payment payment,
    required AppUser currentUser,
    required bool showActions,
  }) {
    final projectName = _getProjectName(payment.projectId);
    final userVote = _getApprovalForRole(payment.approvals, currentUser.role);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaymentDetailScreen(paymentId: payment.id)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              projectName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (payment.module != null && payment.module!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.view_module_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                payment.module!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Formatters.currency(payment.amount),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status badge and date
            Row(
              children: [
                PaymentStatusBadge(status: payment.status),
                const Spacer(),
                Text(
                  Formatters.timeAgo(payment.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Approval indicator
            ApprovalIndicator(approvals: payment.approvals, compact: true),

            // Action buttons (only for pending votes)
            if (showActions) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      color: AppTheme.errorColor,
                      onTap: () => _rejectPayment(payment.id, currentUser),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      color: AppTheme.successColor,
                      filled: true,
                      onTap: () => _approvePayment(payment.id, currentUser),
                    ),
                  ),
                ],
              ),
            ],

            // Vote indicator for already-voted payments (no reject option)
            if (!showActions && userVote != null) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: userVote == true
                      ? AppTheme.successColor.withValues(alpha: 0.08)
                      : AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: userVote == true
                        ? AppTheme.successColor.withValues(alpha: 0.2)
                        : AppTheme.errorColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      userVote == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                      color: userVote == true
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      userVote == true ? 'You Approved' : 'You Rejected',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: userVote == true
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    bool filled = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: filled ? 1.0 : 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletionCard({
    required DeletionRequest deletion,
    required AppUser currentUser,
    required bool showActions,
  }) {
    final userVote = _getApprovalForRole(deletion.approvals, currentUser.role);
    final typeIcon = deletion.targetType == DeletionTargetType.project
        ? Icons.folder_outlined
        : deletion.targetType == DeletionTargetType.milestone
            ? Icons.flag_circle_rounded
            : Icons.payment_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deletion.targetName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(typeIcon, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${deletion.targetTypeDisplayName} Deletion',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.person_outline_rounded,
                            size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            deletion.requestedByName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status and time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deletion.statusDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                Formatters.timeAgo(deletion.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Approval indicator
          ApprovalIndicator(approvals: deletion.approvals, compact: true),

          // Action buttons
          if (showActions) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    color: AppTheme.errorColor,
                    onTap: () => _rejectDeletion(deletion.id, currentUser),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    color: AppTheme.successColor,
                    filled: true,
                    onTap: () => _approveDeletion(deletion.id, currentUser),
                  ),
                ),
              ],
            ),
          ],

          // Vote indicator for already-voted deletions
          if (!showActions && userVote != null) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: userVote == true
                    ? AppTheme.successColor.withValues(alpha: 0.08)
                    : AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: userVote == true
                      ? AppTheme.successColor.withValues(alpha: 0.2)
                      : AppTheme.errorColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    userVote == true
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 18,
                    color: userVote == true
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userVote == true ? 'You Approved' : 'You Rejected',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: userVote == true
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountRequestCard({
    required AccountRequest request,
    required AppUser currentUser,
    required bool showActions,
  }) {
    final userVote = _getApprovalForRole(request.approvals, currentUser.role);
    bool isProcessing = false;

    Color typeColor;
    IconData typeIcon;
    switch (request.requestType) {
      case AccountRequestType.create:
        typeColor = AppTheme.successColor;
        typeIcon = Icons.add_circle_outline_rounded;
        break;
      case AccountRequestType.updateBalance:
        typeColor = AppTheme.accentColor;
        typeIcon = Icons.edit_rounded;
        break;
      case AccountRequestType.delete:
        typeColor = AppTheme.errorColor;
        typeIcon = Icons.delete_outline_rounded;
        break;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AccountDetailScreen(accountId: request.accountId)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(typeIcon, size: 16, color: typeColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.requestTypeDisplayName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: typeColor)),
                        Text(request.accountName,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(request.statusDisplayName,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warningColor)),
                  ),
                ],
              ),
              if (request.requestType == AccountRequestType.updateBalance && request.newBalance != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text('\$${request.previousBalance?.toStringAsFixed(2) ?? 'N/A'}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text('\$${request.newBalance!.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('by ${request.requestedByName}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                  const Spacer(),
                  Text(Formatters.timeAgo(request.createdAt),
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
              const SizedBox(height: 12),
              ApprovalIndicator(approvals: request.approvals, showAccountant: false),
              if (showActions && userVote == null) ...[
                const SizedBox(height: 12),
                StatefulBuilder(builder: (ctx, setLocalState) {
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing ? null : () async {
                            setLocalState(() => isProcessing = true);
                            try {
                              await ref.read(accountRequestsProvider.notifier).rejectRequest(request.id);
                            } finally {
                              if (mounted) setLocalState(() => isProcessing = false);
                            }
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: Text('Reject', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : () async {
                            setLocalState(() => isProcessing = true);
                            try {
                              await ref.read(accountRequestsProvider.notifier).approveRequest(request.id);
                            } finally {
                              if (mounted) setLocalState(() => isProcessing = false);
                            }
                          },
                          icon: isProcessing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_rounded, size: 16),
                          label: Text('Approve', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ] else if (userVote != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: (userVote == true ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (userVote == true ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          userVote == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 16,
                          color: userVote == true ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userVote == true ? 'You Approved' : 'You Rejected',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: userVote == true ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
