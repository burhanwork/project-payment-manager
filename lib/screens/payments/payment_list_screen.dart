import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/payment.dart';
import '../../models/project.dart';
import '../../providers/payment_provider.dart';
import '../../providers/project_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/payment_status_badge.dart';
import '../../animations/page_transitions.dart';
import 'payment_detail_screen.dart';

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _expandedProjects = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Payment> _approvedPayments(List<Payment> payments) =>
      payments.where((p) => p.status == PaymentStatus.approved).toList();

  List<Payment> _rejectedPayments(List<Payment> payments) =>
      payments.where((p) => p.status == PaymentStatus.rejected).toList();


  // Build accordion groups for approved payments (grouped by project)
  List<_ProjectGroup> _buildPaymentGroups(
    List<Payment> filteredPayments,
    List<Project> projects,
  ) {
    final projectMap = {for (final p in projects) p.id: p};
    final Map<String, List<Payment>> grouped = {};
    for (final payment in filteredPayments) {
      grouped.putIfAbsent(payment.projectId, () => []).add(payment);
    }
    final groups = grouped.entries.map((e) {
      final project = projectMap[e.key];
      return _ProjectGroup(
        projectId: e.key,
        projectName: project?.name ?? 'Unknown Project',
        projectCreatedAt: project?.createdAt ?? DateTime(0),
        payments: e.value
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );
    }).toList();
    groups.sort((a, b) => a.projectCreatedAt.compareTo(b.projectCreatedAt));
    return groups;
  }

  IconData _paymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_rounded;
      case PaymentMethod.cash:
        return Icons.payments_rounded;
      case PaymentMethod.check:
        return Icons.receipt_long_rounded;
      case PaymentMethod.creditCard:
        return Icons.credit_card_rounded;
      case PaymentMethod.online:
        return Icons.language_rounded;
      case PaymentMethod.other:
        return Icons.payment_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsProvider);
    final projects = ref.watch(projectsProvider);

    final approvedCount = _approvedPayments(payments).length;
    final rejectedPayments = _rejectedPayments(payments);
    final rejectedCount = rejectedPayments.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'Approved ($approvedCount)'),
            Tab(text: 'Rejected ($rejectedCount)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Approved tab ──
          _buildApprovedTab(payments, projects),

          // ── Rejected tab ──
          _buildRejectedTab(rejectedPayments, projects),
        ],
      ),
    );
  }

  // Approved tab: payments grouped by project accordion
  Widget _buildApprovedTab(List<Payment> payments, List<Project> projects) {
    final approved = _approvedPayments(payments);
    final groups = _buildPaymentGroups(approved, projects);

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.read(paymentsProvider.notifier).refresh();
        ref.read(projectsProvider.notifier).refresh();
      },
      child: groups.isEmpty
          ? _buildEmptyState(Icons.check_circle_outline_rounded, 'approved payments')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: groups.length,
              itemBuilder: (context, index) =>
                  _buildProjectGroup(groups[index], index),
            ),
    );
  }

  // Rejected tab: rejected project requests (standalone) + rejected payments (grouped)
  Widget _buildRejectedTab(
    List<Payment> rejectedPayments,
    List<Project> projects,
  ) {
    final paymentGroups = _buildPaymentGroups(rejectedPayments, projects);
    final isEmpty = paymentGroups.isEmpty;

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.read(paymentsProvider.notifier).refresh();
        ref.read(projectsProvider.notifier).refresh();
      },
      child: isEmpty
          ? _buildEmptyState(Icons.cancel_outlined, 'rejected records')
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (paymentGroups.isNotEmpty) ...[
                  _buildSectionLabel('Rejected Payments'),
                  ...paymentGroups.asMap().entries.map(
                        (e) => _buildProjectGroup(e.value, e.key),
                      ),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // Card for a rejected project request (no project was created)
  Widget _buildProjectGroup(_ProjectGroup group, int groupIndex) {
    final isExpanded = _expandedProjects.contains(group.projectId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedProjects.remove(group.projectId);
                  } else {
                    _expandedProjects.add(group.projectId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.projectName,
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
                            '${group.payments.length} payment${group.payments.length == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primaryColor, size: 24),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                      height: 1,
                      color: Colors.grey.shade100,
                      indent: 16,
                      endIndent: 16),
                  ...group.payments.asMap().entries.map((entry) =>
                      _buildPaymentRow(
                          entry.value, entry.key, group.payments.length)),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
            duration: 400.ms,
            delay: Duration(milliseconds: 60 * groupIndex))
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: Duration(milliseconds: 60 * groupIndex),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildPaymentRow(Payment payment, int index, int total) {
    final isLast = index == total - 1;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          SmoothPageRoute(page: PaymentDetailScreen(paymentId: payment.id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: !isLast
              ? Border(bottom: BorderSide(color: Colors.grey.shade100))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor(payment.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _paymentMethodIcon(payment.method),
                color: _statusColor(payment.status),
                size: 18,
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
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.date(payment.date),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.currency(payment.amount),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                PaymentStatusBadge(status: payment.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return AppTheme.warningColor;
      case PaymentStatus.partiallyApproved:
        return AppTheme.accentColor;
      case PaymentStatus.approved:
        return AppTheme.successColor;
      case PaymentStatus.rejected:
        return const Color(0xFFFF1744);
    }
  }

  Widget _buildEmptyState(IconData icon, String label) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 56,
                        color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No $label',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectGroup {
  final String projectId;
  final String projectName;
  final DateTime projectCreatedAt;
  final List<Payment> payments;

  _ProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.projectCreatedAt,
    required this.payments,
  });
}
