import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../models/app_user.dart';
import '../../models/payment.dart';
import '../../models/deletion_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/deletion_provider.dart';
import '../../providers/bank_account_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/payment_status_badge.dart';
import '../../widgets/approval_indicator.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  final String paymentId;

  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  ConsumerState<PaymentDetailScreen> createState() =>
      _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  bool _isProcessing = false;
  bool _isRequestingDeletion = false;
  bool _isDownloading = false;
  bool _isUploadingReceipt = false;

  Future<void> _downloadReceipt(String proofPath, String paymentTitle) async {
    setState(() => _isDownloading = true);
    try {
      final sourceFile = File(proofPath);
      if (!await sourceFile.exists()) throw Exception('File not found');
      final bytes = await sourceFile.readAsBytes();

      final ext = proofPath.contains('.') ? proofPath.split('.').last.toLowerCase() : 'jpg';
      final fileName = '${paymentTitle.replaceAll(' ', '_')}_receipt.$ext';

      // Save to temp file first
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'heic', 'heif', 'webp'].contains(ext);

      if (isImage) {
        // Save image directly to Photos library
        await Gal.putImage(file.path, album: 'Project Payment Manager');
        if (!mounted) return;
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Receipt saved to Photos', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        // For PDFs and other files, use share sheet so user can save to Files
        setState(() => _isDownloading = false);
        await Share.shareXFiles([XFile(file.path)], text: 'Payment Receipt');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Download failed: $e',
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

  Future<void> _pickAndUploadReceipt(String paymentId) async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('Upload Receipt', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor),
                ),
                title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () async {
                  final f = await picker.pickImage(source: ImageSource.camera);
                  if (ctx.mounted) Navigator.pop(ctx, f);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.photo_library_rounded, color: AppTheme.accentColor),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () async {
                  final f = await picker.pickImage(source: ImageSource.gallery);
                  if (ctx.mounted) Navigator.pop(ctx, f);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _isUploadingReceipt = true);
    try {
      await ref.read(paymentsProvider.notifier).uploadReceipt(paymentId, picked.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Receipt uploaded successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload receipt: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingReceipt = false);
    }
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
              'Delete Payment',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'This will create a deletion request that requires approval from all 3 roles (Developer, Boss, Accountant) before this payment is permanently deleted.',
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
            targetType: 'payment',
            targetId: widget.paymentId,
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

  LinearGradient _statusGradient(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return AppTheme.warningGradient;
      case PaymentStatus.partiallyApproved:
        return AppTheme.accentGradient;
      case PaymentStatus.approved:
        return AppTheme.successGradient;
      case PaymentStatus.rejected:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
        );
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

  DateTime? _timestampForRole(PaymentApproval approvals, UserRole role) {
    switch (role) {
      case UserRole.developer:
        return approvals.developerAt;
      case UserRole.boss:
        return approvals.bossAt;
      case UserRole.accountant:
        return approvals.accountantAt;
    }
  }

  String _roleName(UserRole role) {
    switch (role) {
      case UserRole.developer:
        return 'Developer';
      case UserRole.boss:
        return 'Boss';
      case UserRole.accountant:
        return 'Accountant';
    }
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

  Future<void> _approvePayment(AppUser currentUser) async {
    setState(() => _isProcessing = true);

    try {
      await ref.read(paymentsProvider.notifier).approvePayment(
            paymentId: widget.paymentId,
            role: currentUser.role,
            userId: currentUser.uid,
          );

      ref.read(projectsProvider.notifier).refresh();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Payment approved successfully!',
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
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to approve: $e',
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

  Future<void> _rejectPayment(AppUser currentUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 24),
            const SizedBox(width: 10),
            Text(
              'Reject Payment',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to reject this payment? This action cannot be undone.',
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
              'Reject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await ref.read(paymentsProvider.notifier).rejectPayment(
            paymentId: widget.paymentId,
            role: currentUser.role,
            userId: currentUser.uid,
          );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Payment rejected',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to reject: $e',
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

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsProvider);
    final payment = payments.where((p) => p.id == widget.paymentId).firstOrNull;

    if (payment == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment Details'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Payment not found',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final projects = ref.watch(projectsProvider);
    final project =
        projects.where((p) => p.id == payment.projectId).firstOrNull;
    final projectName = project?.name ?? 'Unknown Project';
    final currentUser = ref.watch(currentUserProvider);

    // Check if user has already voted
    bool? userVote;
    if (currentUser != null) {
      userVote = _approvalForRole(payment.approvals, currentUser.role);
    }
    final hasVoted = userVote != null;
    final canAct = currentUser != null &&
        !hasVoted &&
        payment.status != PaymentStatus.approved &&
        payment.status != PaymentStatus.rejected;

    // Check for active deletion request
    final deletions = ref.watch(deletionsProvider);
    final activeDeletion = deletions.where((d) =>
        d.targetType == DeletionTargetType.payment &&
        d.targetId == widget.paymentId &&
        (d.status == PaymentStatus.pending ||
            d.status == PaymentStatus.partiallyApproved)).firstOrNull;
    final hasActiveDeletion = activeDeletion != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: _statusGradient(payment.status),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _statusGradient(payment.status)
                      .colors
                      .first
                      .withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  Formatters.currency(payment.amount),
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                PaymentStatusBadge(status: payment.status, large: true),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutCubic),

          const SizedBox(height: 20),


          // Payment Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Payment Information',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.title_rounded, 'Title', payment.title),
                  if (payment.module != null && payment.module!.isNotEmpty) ...[
                    _buildDivider(),
                    _buildInfoRow(
                        Icons.view_module_rounded, 'Module', payment.module!),
                  ],
                  _buildDivider(),
                  _buildInfoRow(
                      Icons.folder_outlined, 'Project', projectName),
                  _buildDivider(),
                  _buildInfoRow(Icons.calendar_today_rounded, 'Date',
                      Formatters.date(payment.date)),
                  _buildDivider(),
                  _buildInfoRow(Icons.payment_rounded, 'Method',
                      payment.methodDisplayName),
                  if (payment.bankAccountId != null) ...[
                    _buildDivider(),
                    Builder(builder: (ctx) {
                      final accounts = ref.watch(bankAccountsProvider);
                      final acct = accounts.where((a) => a.id == payment.bankAccountId).firstOrNull;
                      return _buildInfoRow(
                        Icons.account_balance_rounded,
                        'Deducted From',
                        acct != null ? '${acct.bankName} – ${acct.name}' : 'Bank Account',
                      );
                    }),
                  ],
                  _buildDivider(),
                  _buildInfoRow(Icons.person_outline_rounded, 'Added By',
                      payment.addedByName.isEmpty ? 'Unknown' : payment.addedByName),
                  if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                    _buildDivider(),
                    _buildInfoRow(
                        Icons.notes_rounded, 'Notes', payment.notes!),
                  ],
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 150.ms)
              .slideY(
                  begin: 0.08,
                  end: 0,
                  duration: 400.ms,
                  delay: 150.ms,
                  curve: Curves.easeOutCubic),

          // Receipt Image Card — always visible
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.successGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Transaction Receipt',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (payment.proofPath != null && payment.proofPath!.isNotEmpty) ...[
                    // Receipt image preview
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: InteractiveViewer(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(payment.proofPath!),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      padding: const EdgeInsets.all(20),
                                      color: Colors.white,
                                      child: const Text('Could not load image'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(payment.proofPath!),
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 32),
                                const SizedBox(height: 8),
                                Text('Could not load receipt',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Tap image to view full size',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading
                            ? null
                            : () => _downloadReceipt(payment.proofPath!, payment.title),
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _isDownloading ? 'Downloading...' : 'Download Receipt',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else if (payment.status == PaymentStatus.rejected ||
                      payment.status == PaymentStatus.approved)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 36, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text(
                            'No receipt uploaded',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _isUploadingReceipt
                          ? null
                          : () => _pickAndUploadReceipt(payment.id),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _isUploadingReceipt
                                ? const SizedBox(
                                    width: 28, height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.upload_rounded,
                                    size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              _isUploadingReceipt
                                  ? 'Uploading receipt...'
                                  : 'Tap to upload receipt',
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
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(
                  begin: 0.08,
                  end: 0,
                  duration: 400.ms,
                  delay: 200.ms,
                  curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // Approval Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.how_to_vote_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Approval Status',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Text(
                        '${payment.approvals.approvalCount}/3',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: payment.approvals.approvalCount / 3.0,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        payment.approvals.approvalCount == 3
                            ? AppTheme.successColor
                            : AppTheme.accentColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Approval Indicator
                  ApprovalIndicator(approvals: payment.approvals),

                  const SizedBox(height: 20),

                  // Detailed role statuses
                  ...UserRole.values.map((role) {
                    final approval =
                        _approvalForRole(payment.approvals, role);
                    final timestamp =
                        _timestampForRole(payment.approvals, role);

                    Color statusColor;
                    IconData statusIcon;
                    String statusText;

                    if (approval == true) {
                      statusColor = AppTheme.successColor;
                      statusIcon = Icons.check_circle_rounded;
                      statusText = 'Approved';
                    } else if (approval == false) {
                      statusColor = AppTheme.errorColor;
                      statusIcon = Icons.cancel_rounded;
                      statusText = 'Rejected';
                    } else if (payment.status == PaymentStatus.rejected) {
                      statusColor = Colors.grey.shade300;
                      statusIcon = Icons.remove_circle_outline_rounded;
                      statusText = 'N/A';
                    } else {
                      statusColor = Colors.grey.shade400;
                      statusIcon = Icons.hourglass_empty_rounded;
                      statusText = 'Pending';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(_roleIcon(role),
                              size: 18, color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _roleName(role),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (timestamp != null)
                                  Text(
                                    Formatters.timeAgo(timestamp),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(statusIcon, size: 18, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 250.ms)
              .slideY(
                  begin: 0.08,
                  end: 0,
                  duration: 400.ms,
                  delay: 250.ms,
                  curve: Curves.easeOutCubic),

          const SizedBox(height: 20),

          // Action Buttons
          if (canAct)
            Column(
              children: [
                // Approve Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.successGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _approvePayment(currentUser),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        'Approve Payment',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Reject Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _rejectPayment(currentUser),
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    label: Text(
                      'Reject Payment',
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
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms)
                .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 400.ms,
                    delay: 350.ms,
                    curve: Curves.easeOutCubic),

          // Show confirmed approved state (no reject option)
          if (!canAct && userVote == true &&
              payment.status != PaymentStatus.approved &&
              payment.status != PaymentStatus.rejected)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppTheme.successColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'You Approved This Payment',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms)
                .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 400.ms,
                    delay: 350.ms,
                    curve: Curves.easeOutCubic),

          const SizedBox(height: 20),

          // Deletion request banner
          if (hasActiveDeletion)
            Container(
              padding: const EdgeInsets.all(14),
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
                .fadeIn(duration: 400.ms, delay: 400.ms)
                .slideY(begin: 0.05, curve: Curves.easeOutCubic),

          // Request Deletion Button
          if (!hasActiveDeletion && currentUser != null && payment.status == PaymentStatus.approved) ...[
            const SizedBox(height: 12),
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
                .fadeIn(duration: 400.ms, delay: 400.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey.shade100,
    );
  }
}
