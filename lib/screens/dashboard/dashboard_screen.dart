import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/app_user.dart';
import '../../models/payment.dart';
import '../../models/deletion_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/deletion_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/payment_status_badge.dart';
import '../../widgets/approval_indicator.dart';
import '../../animations/page_transitions.dart';
import '../payments/payment_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final pendingCount = ref.watch(pendingPaymentsCountProvider);
    final recentPayments = ref.watch(recentPaymentsProvider);
    final allPayments = ref.watch(paymentsProvider);
    final allDeletions = ref.watch(deletionsProvider);

    // Payments needing current user's action
    final needsMyAction = user == null
        ? <Payment>[]
        : allPayments.where((p) {
            if (p.status == PaymentStatus.approved ||
                p.status == PaymentStatus.rejected) return false;
            bool? myVote;
            switch (user.role) {
              case UserRole.developer:
                myVote = p.approvals.developer;
              case UserRole.boss:
                myVote = p.approvals.boss;
              case UserRole.accountant:
                myVote = p.approvals.accountant;
            }
            return myVote == null;
          }).toList();

    // Deletions needing current user's action
    final deletionNeedsMyAction = user == null
        ? <DeletionRequest>[]
        : allDeletions.where((d) {
            if (d.status == PaymentStatus.approved ||
                d.status == PaymentStatus.rejected) return false;
            bool? myVote;
            switch (user.role) {
              case UserRole.developer:
                myVote = d.approvals.developer;
              case UserRole.boss:
                myVote = d.approvals.boss;
              case UserRole.accountant:
                myVote = d.approvals.accountant;
            }
            return myVote == null;
          }).toList();

    final totalNeedsAction = needsMyAction.length + deletionNeedsMyAction.length;
    final firstName = user?.name.split(' ').first ?? 'User';
    // Keep total gradient height (expandedHeight + statusBar) constant across all devices
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final sliverExpandedHeight = (194.0 - statusBarHeight).clamp(100.0, 160.0);

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          ref.read(projectsProvider.notifier).refresh();
          ref.read(paymentsProvider.notifier).refresh();
          ref.read(deletionsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Gradient AppBar
            SliverAppBar(
              expandedHeight: sliverExpandedHeight,
              floating: false,
              pinned: true,
              stretch: true,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              firstName,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                  ),
                ),
              ),
              actions: [
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _roleIcon(user.role),
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.roleDisplayName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Grid
                  _buildStatsGrid(stats, pendingCount),
                  const SizedBox(height: 24),

                  // Pending Approvals Section
                  if (totalNeedsAction > 0) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.pending_actions_rounded,
                              color: AppTheme.warningColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Needs Your Approval',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalNeedsAction',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 400.ms)
                        .slideX(begin: -0.05, curve: Curves.easeOut),
                    const SizedBox(height: 12),
                    ...needsMyAction.take(3).toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final payment = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PendingApprovalTile(payment: payment),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 400 + (index * 80)),
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.08,
                            curve: Curves.easeOutCubic,
                          );
                    }),
                    ...deletionNeedsMyAction.take(3).toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final deletion = entry.value;
                      final delayBase = 400 + (needsMyAction.take(3).length * 80);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PendingDeletionTile(deletion: deletion),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: delayBase + (index * 80)),
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.08,
                            curve: Curves.easeOutCubic,
                          );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Revenue Overview Card
                  _buildRevenueCard(stats)
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 500.ms)
                      .slideY(
                        begin: 0.1,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 24),

                  // Pie Chart
                  _buildPieChartCard(stats)
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 500.ms)
                      .slideY(
                        begin: 0.1,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 24),

                  // Recent Payments Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Payments',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        '${recentPayments.length} latest',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms),
                  const SizedBox(height: 12),

                  // Recent Payments List
                  if (recentPayments.isEmpty)
                    _buildEmptyPayments()
                        .animate()
                        .fadeIn(delay: 650.ms, duration: 400.ms)
                  else
                    ...recentPayments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final payment = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PaymentListTile(payment: payment),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 650 + (index * 80)),
                            duration: 400.ms,
                          )
                          .slideX(
                            begin: 0.05,
                            curve: Curves.easeOutCubic,
                          );
                    }),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats, int pendingCount) {
    final cards = [
      _StatsItem(
        title: 'Total Projects',
        value: stats.totalProjects.toString(),
        icon: Icons.folder_rounded,
        color: AppTheme.primaryColor,
      ),
      _StatsItem(
        title: 'Active',
        value: stats.activeProjects.toString(),
        icon: Icons.play_circle_rounded,
        color: AppTheme.accentColor,
      ),
      _StatsItem(
        title: 'Completed',
        value: stats.completedProjects.toString(),
        icon: Icons.check_circle_rounded,
        color: AppTheme.successColor,
      ),
      _StatsItem(
        title: 'Pending Approvals',
        value: pendingCount.toString(),
        icon: Icons.pending_actions_rounded,
        color: AppTheme.warningColor,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.45,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final item = cards[index];
        return StatCard(
          title: item.title,
          value: item.value,
          icon: item.icon,
          color: item.color,
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 100 + (index * 100)),
              duration: 500.ms,
            )
            .slideY(
              begin: 0.15,
              delay: Duration(milliseconds: 100 + (index * 100)),
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildRevenueCard(DashboardStats stats) {
    final progress = stats.totalRevenue > 0
        ? (stats.totalPaid / stats.totalRevenue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Revenue Overview',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Total Revenue
            Text(
              'Total Revenue',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.currency(stats.totalRevenue),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Collected vs Remaining
            Row(
              children: [
                Expanded(
                  child: _RevenueDetail(
                    label: 'Collected',
                    amount: Formatters.currency(stats.totalPaid),
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppTheme.successColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _RevenueDetail(
                    label: 'Remaining',
                    amount: Formatters.currency(stats.totalRemaining),
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard(DashboardStats stats) {
    final paid = stats.totalPaid;
    final remaining = stats.totalRemaining;
    final hasData = paid > 0 || remaining > 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Distribution',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: hasData
                ? Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(
                                value: paid,
                                color: AppTheme.successColor,
                                title: Formatters.compactCurrency(paid),
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                radius: 55,
                                titlePositionPercentageOffset: 0.55,
                              ),
                              PieChartSectionData(
                                value: remaining,
                                color: AppTheme.warningColor,
                                title: Formatters.compactCurrency(remaining),
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                radius: 55,
                                titlePositionPercentageOffset: 0.55,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendItem(
                              color: AppTheme.successColor,
                              label: 'Paid',
                              value: Formatters.compactCurrency(paid),
                            ),
                            const SizedBox(height: 16),
                            _LegendItem(
                              color: AppTheme.warningColor,
                              label: 'Remaining',
                              value: Formatters.compactCurrency(remaining),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No payment data yet',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPayments() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.payment_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent payments',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.developer:
        return Icons.code_rounded;
      case UserRole.boss:
        return Icons.person_rounded;
      case UserRole.accountant:
        return Icons.calculate_rounded;
    }
  }
}

// -- Private helper widgets --

class _StatsItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _RevenueDetail extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color iconColor;

  const _RevenueDetail({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentListTile extends ConsumerWidget {
  final Payment payment;

  const _PaymentListTile({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            SmoothPageRoute(
              page: PaymentDetailScreen(paymentId: payment.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(payment.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon(payment.status),
                  color: _statusColor(payment.status),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.timeAgo(payment.date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(payment.amount),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PaymentStatusBadge(status: payment.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return AppTheme.warningColor;
      case PaymentStatus.partiallyApproved:
        return Colors.orange.shade700;
      case PaymentStatus.approved:
        return AppTheme.successColor;
      case PaymentStatus.rejected:
        return AppTheme.errorColor;
    }
  }

  IconData _statusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Icons.schedule_rounded;
      case PaymentStatus.partiallyApproved:
        return Icons.hourglass_top_rounded;
      case PaymentStatus.approved:
        return Icons.check_circle_rounded;
      case PaymentStatus.rejected:
        return Icons.cancel_rounded;
    }
  }
}

class _PendingApprovalTile extends ConsumerWidget {
  final Payment payment;

  const _PendingApprovalTile({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            SmoothPageRoute(
              page: PaymentDetailScreen(paymentId: payment.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.warningColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.warningColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pending_actions_rounded,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.timeAgo(payment.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.currency(payment.amount),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ApprovalIndicator(approvals: payment.approvals, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDeletionTile extends StatelessWidget {
  final DeletionRequest deletion;

  const _PendingDeletionTile({required this.deletion});

  @override
  Widget build(BuildContext context) {
    final typeIcon = deletion.targetType == DeletionTargetType.project
        ? Icons.folder_outlined
        : Icons.payment_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deletion.targetName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(typeIcon, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${deletion.targetTypeDisplayName} Deletion',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.timeAgo(deletion.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ApprovalIndicator(approvals: deletion.approvals, compact: true),
        ],
      ),
    );
  }
}
