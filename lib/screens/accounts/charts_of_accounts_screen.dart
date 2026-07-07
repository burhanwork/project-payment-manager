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
import '../../widgets/approval_indicator.dart';
import 'create_account_screen.dart';
import 'account_detail_screen.dart';

class ChartsOfAccountsScreen extends ConsumerWidget {
  const ChartsOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(bankAccountsProvider);
    final requests = ref.watch(accountRequestsProvider);
    final currentUser = ref.watch(currentUserProvider);

    final visible = accounts.where((a) => a.status != BankAccountStatus.inactive).toList();
    final totalBalance = accounts
        .where((a) => a.status == BankAccountStatus.active)
        .fold(0.0, (sum, a) => sum + a.currentBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts of Accounts'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      floatingActionButton: currentUser?.role == UserRole.accountant
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
              ),
              icon: const Icon(Icons.add),
              label: Text('Add Account', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(bankAccountsProvider.notifier).refresh();
          ref.read(accountRequestsProvider.notifier).refresh();
        },
        child: visible.isEmpty
            ? _buildEmpty()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTotalCard(totalBalance, accounts.where((a) => a.status == BankAccountStatus.active).length),
                  const SizedBox(height: 16),
                  ...visible.asMap().entries.map((e) {
                    final account = e.value;
                    // Find pending request for this account
                    final pendingRequest = requests.where((r) =>
                        r.accountId == account.id &&
                        (r.status == PaymentStatus.pending || r.status == PaymentStatus.partiallyApproved)).firstOrNull;
                    return _buildAccountCard(context, account, pendingRequest, currentUser, ref, e.key)
                        .animate()
                        .fadeIn(duration: 300.ms, delay: (e.key * 60).ms)
                        .slideY(begin: 0.08, end: 0, duration: 300.ms, delay: (e.key * 60).ms, curve: Curves.easeOutCubic);
                  }),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No bank accounts yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Tap + to add a bank account', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildTotalCard(double totalBalance, int activeCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Available Balance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('\$${totalBalance.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Across $activeCount active account${activeCount == 1 ? '' : 's'}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, BankAccount account, AccountRequest? pendingRequest,
      AppUser? currentUser, WidgetRef ref, int index) {
    Color statusColor;
    IconData statusIcon;
    switch (account.status) {
      case BankAccountStatus.active:
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_rounded;
        break;
      case BankAccountStatus.pending:
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case BankAccountStatus.inactive:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AccountDetailScreen(accountId: account.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                        Text(account.bankName,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(account.statusDisplayName,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Balance', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Text('\$${account.currentBalance.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800,
                                color: account.currentBalance >= 0 ? AppTheme.successColor : AppTheme.errorColor)),
                      ],
                    ),
                    if (account.accountNumber != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Account No.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(height: 2),
                          Text('••••${account.accountNumber}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        ],
                      ),
                  ],
                ),
              ),
              if (pendingRequest != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pending_actions_rounded, size: 14, color: AppTheme.warningColor),
                          const SizedBox(width: 6),
                          Text('${pendingRequest.requestTypeDisplayName} — Awaiting Approval',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warningColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ApprovalIndicator(approvals: pendingRequest.approvals, showAccountant: false),
                    ],
                  ),
                ),
              ],
              if (account.status == BankAccountStatus.active && currentUser?.role == UserRole.accountant) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateBalanceDialog(context, account, ref),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text('Update Balance', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirm(context, account, ref),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: Text('Remove', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: AppTheme.errorColor,
                          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateBalanceDialog(BuildContext context, BankAccount account, WidgetRef ref) {
    final controller = TextEditingController(text: account.currentBalance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Balance', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${account.bankName} – ${account.name}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Balance',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text('This change requires approval from all 3 roles.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val == null) return;
              Navigator.pop(ctx);
              try {
                await ref.read(bankAccountsProvider.notifier).requestUpdateBalance(account.id, val);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Balance update request submitted for approval.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, BankAccount account, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Account', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request removal of "${account.name}"?', style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 8),
            Text('This requires approval from all 3 roles before the account is closed.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(bankAccountsProvider.notifier).requestDelete(account.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Removal request submitted for approval.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
            child: const Text('Request Removal'),
          ),
        ],
      ),
    );
  }
}
