import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bank_account.dart';
import '../../models/account_request.dart';
import '../../models/payment.dart';
import '../../models/app_user.dart';
import '../../providers/bank_account_provider.dart';
import '../../providers/account_request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/approval_indicator.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _isProcessing = false;

  Future<void> _approve(String requestId) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(accountRequestsProvider.notifier).approveRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Approved!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject(String requestId) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(accountRequestsProvider.notifier).rejectRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Rejected', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool? _approvalForRole(PaymentApproval approvals, UserRole role) {
    switch (role) {
      case UserRole.developer:
        return approvals.developer;
      case UserRole.boss:
        return approvals.boss;
      case UserRole.accountant:
        return approvals.accountant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(bankAccountsProvider);
    final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;
    final allRequests = ref.watch(accountRequestsProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account Details'),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.primaryGradient)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final requests = allRequests.where((r) => r.accountId == account.id).toList();
    final pendingRequest = requests.where((r) =>
        r.status == PaymentStatus.pending || r.status == PaymentStatus.partiallyApproved).firstOrNull;

    bool? userVote;
    if (currentUser != null && pendingRequest != null) {
      userVote = _approvalForRole(pendingRequest.approvals, currentUser.role);
    }
    final hasVoted = userVote != null;
    final canAct = currentUser != null && !hasVoted && pendingRequest != null;

    Color headerColor;
    switch (account.status) {
      case BankAccountStatus.active:
        headerColor = AppTheme.successColor;
        break;
      case BankAccountStatus.pending:
        headerColor = AppTheme.warningColor;
        break;
      case BankAccountStatus.inactive:
        headerColor = Colors.grey;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.primaryGradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Balance header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: headerColor.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              children: [
                Text('\$${account.currentBalance.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('● ${account.statusDisplayName}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // Account info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader(Icons.account_balance_rounded, 'Account Information', AppTheme.primaryGradient),
                  const SizedBox(height: 16),
                  _infoRow('Account Name', account.name),
                  _infoRow('Bank Name', account.bankName),
                  if (account.accountNumber != null) _infoRow('Account No.', '••••${account.accountNumber}'),
                  _infoRow('Currency', account.currency),
                  if (account.notes != null) _infoRow('Notes', account.notes!),
                  _infoRow('Added By', account.createdByName),
                  _infoRow('Created', Formatters.date(account.createdAt)),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 100.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // Active request card
          if (pendingRequest != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cardHeader(Icons.pending_actions_rounded, 'Pending: ${pendingRequest.requestTypeDisplayName}', AppTheme.warningGradient),
                    const SizedBox(height: 16),
                    if (pendingRequest.requestType == AccountRequestType.updateBalance) ...[
                      _infoRow('Current Balance', '\$${pendingRequest.previousBalance?.toStringAsFixed(2) ?? 'N/A'}'),
                      _infoRow('New Balance', '\$${pendingRequest.newBalance?.toStringAsFixed(2) ?? 'N/A'}'),
                    ],
                    _infoRow('Requested By', pendingRequest.requestedByName),
                    _infoRow('Submitted', Formatters.date(pendingRequest.createdAt)),
                    const SizedBox(height: 16),
                    ApprovalIndicator(approvals: pendingRequest.approvals, showAccountant: false),
                    if (canAct) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isProcessing ? null : () => _reject(pendingRequest.id),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : () => _approve(pendingRequest.id),
                              icon: _isProcessing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (!canAct && userVote == true && pendingRequest.status != PaymentStatus.approved) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 18),
                              const SizedBox(width: 8),
                              Text('You approved this request', style: GoogleFonts.inter(color: AppTheme.successColor, fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 150.ms, curve: Curves.easeOutCubic),

          // History
          if (requests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cardHeader(Icons.history_rounded, 'Request History', AppTheme.accentGradient),
                    const SizedBox(height: 16),
                    ...requests.map((r) => _buildHistoryTile(r)),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(AccountRequest r) {
    Color color;
    IconData icon;
    switch (r.status) {
      case PaymentStatus.approved:
        color = AppTheme.successColor;
        icon = Icons.check_circle_rounded;
        break;
      case PaymentStatus.rejected:
        color = AppTheme.errorColor;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppTheme.warningColor;
        icon = Icons.hourglass_empty_rounded;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.requestTypeDisplayName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                Text('${r.requestedByName} • ${Formatters.date(r.createdAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                if (r.requestType == AccountRequestType.updateBalance && r.newBalance != null)
                  Text('\$${r.previousBalance?.toStringAsFixed(2)} → \$${r.newBalance!.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(r.statusDisplayName, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _cardHeader(IconData icon, String title, LinearGradient gradient) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade800))),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }
}
