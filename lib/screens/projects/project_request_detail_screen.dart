import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../models/project_request.dart';
import '../../models/payment.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';

class ProjectRequestDetailScreen extends StatefulWidget {
  final ProjectRequest request;

  const ProjectRequestDetailScreen({super.key, required this.request});

  @override
  State<ProjectRequestDetailScreen> createState() =>
      _ProjectRequestDetailScreenState();
}

class _ProjectRequestDetailScreenState
    extends State<ProjectRequestDetailScreen> {
  static const _imageBase = 'http://localhost:3003';
  bool _isDownloading = false;

  ProjectRequest get request => widget.request;

  Future<void> _downloadReceipt() async {
    if (request.proofPath == null) return;
    setState(() => _isDownloading = true);
    try {
      final url = '$_imageBase${request.proofPath}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Failed to download');

      final ext = request.proofPath!.contains('.')
          ? request.proofPath!.split('.').last.toLowerCase()
          : 'jpg';
      final fileName = '${request.name.replaceAll(' ', '_')}_receipt.$ext';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;

      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'heic', 'heif', 'webp'].contains(ext);
      if (isImage) {
        await Gal.putImage(file.path, album: 'Project Payment Manager');
        if (!mounted) return;
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text('Receipt saved to Photos', style: TextStyle(color: Colors.white)),
            ]),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        setState(() => _isDownloading = false);
        await Share.shareXFiles([XFile(file.path)], text: 'Payment Receipt');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Failed to download receipt', style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Request Details'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status banner
            _buildStatusBanner(),
            const SizedBox(height: 16),

            // Project Info
            _buildCard(
              icon: Icons.business_center_rounded,
              title: 'Project Information',
              child: Column(
                children: [
                  _buildRow(Icons.folder_rounded, 'Project Name', request.name),
                  _divider(),
                  _buildRow(Icons.person_rounded, 'Client', request.clientName),
                  _divider(),
                  _buildRow(Icons.account_circle_rounded, 'Requested By',
                      request.requestedByName),
                  _divider(),
                  _buildRow(Icons.attach_money_rounded, 'Total Cost',
                      Formatters.currency(request.totalCost)),
                  if (request.initialPayment > 0) ...[
                    _divider(),
                    _buildRow(Icons.payments_rounded, 'Initial Payment',
                        Formatters.currency(request.initialPayment)),
                  ],
                  _divider(),
                  _buildRow(Icons.flag_rounded, 'Project Status',
                      _projectStatusLabel(request.projectStatus)),
                  _divider(),
                  _buildRow(Icons.calendar_today_rounded, 'Submitted',
                      Formatters.dateTime(request.createdAt)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline
            _buildCard(
              icon: Icons.calendar_month_rounded,
              title: 'Timeline',
              child: Row(
                children: [
                  Expanded(
                    child: _buildDateBox(
                      label: 'Start Date',
                      value: Formatters.date(request.startDate),
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.grey),
                  ),
                  Expanded(
                    child: _buildDateBox(
                      label: 'End Date',
                      value: Formatters.date(request.expectedCompletionDate),
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Milestones
            if (request.milestones.isNotEmpty)
              _buildCard(
                icon: Icons.flag_circle_rounded,
                title: 'Milestones',
                child: Column(
                  children: request.milestones.asMap().entries.map((e) {
                    final isLast = e.key == request.milestones.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(color: Colors.grey.shade100, height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),

            // Approval Status
            _buildCard(
              icon: Icons.how_to_vote_rounded,
              title: 'Approval Status',
              trailing: Text(
                _approvalFraction(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              child: Column(
                children: [
                  _buildApprovalProgress(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildApprovalChip(
                              'Dev', request.approvals.developer)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildApprovalChip(
                              'Boss', request.approvals.boss)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildApprovalChip(
                              'Acct', request.approvals.accountant)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildApprovalDetail('Developer', request.approvals.developer,
                      request.approvals.developerAt),
                  _divider(),
                  _buildApprovalDetail(
                      'Boss', request.approvals.boss, request.approvals.bossAt),
                  _divider(),
                  _buildApprovalDetail('Accountant',
                      request.approvals.accountant, request.approvals.accountantAt),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transaction Receipt
            _buildCard(
              icon: Icons.receipt_long_rounded,
              title: 'Transaction Receipt',
              child: request.proofPath != null
                  ? Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            '$_imageBase${request.proofPath}',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _noReceiptPlaceholder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading ? null : _downloadReceipt,
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              _isDownloading
                                  ? 'Downloading...'
                                  : 'Download Receipt',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _noReceiptPlaceholder(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isRejected = request.status == PaymentStatus.rejected;
    final color = isRejected ? const Color(0xFFFF1744) : AppTheme.successColor;
    final icon = isRejected ? Icons.cancel_rounded : Icons.check_circle_rounded;
    final label = isRejected ? 'Project Request Rejected' : 'Project Approved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.shade100, height: 1);

  Widget _buildDateBox(
      {required String label,
      required String value,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark)),
        ],
      ),
    );
  }

  String _approvalFraction() {
    int count = 0;
    if (request.approvals.developer == true) count++;
    if (request.approvals.boss == true) count++;
    if (request.approvals.accountant == true) count++;
    return '$count/3';
  }

  Widget _buildApprovalProgress() {
    int approved = 0;
    if (request.approvals.developer == true) approved++;
    if (request.approvals.boss == true) approved++;
    if (request.approvals.accountant == true) approved++;
    final color = request.status == PaymentStatus.rejected
        ? const Color(0xFFFF1744)
        : AppTheme.successColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: approved / 3,
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildApprovalChip(String label, bool? vote) {
    Color bg, fg;
    IconData icon;
    final isRejected = request.status == PaymentStatus.rejected;
    if (vote == true) {
      bg = AppTheme.successColor.withValues(alpha: 0.12);
      fg = AppTheme.successColor;
      icon = Icons.check_circle_rounded;
    } else if (vote == false) {
      bg = const Color(0xFFFF1744).withValues(alpha: 0.12);
      fg = const Color(0xFFFF1744);
      icon = Icons.cancel_rounded;
    } else if (isRejected) {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade300;
      icon = Icons.remove_rounded;
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade400;
      icon = Icons.radio_button_unchecked_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }

  Widget _buildApprovalDetail(
      String roleName, bool? vote, DateTime? votedAt) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    final isRejected = request.status == PaymentStatus.rejected;

    if (vote == true) {
      statusText = 'Approved';
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle_rounded;
    } else if (vote == false) {
      statusText = 'Rejected';
      statusColor = const Color(0xFFFF1744);
      statusIcon = Icons.cancel_rounded;
    } else if (isRejected) {
      // Request was rejected by someone else — this role didn't get to vote
      statusText = 'N/A';
      statusColor = Colors.grey.shade300;
      statusIcon = Icons.remove_circle_outline_rounded;
    } else {
      statusText = 'Pending';
      statusColor = Colors.grey.shade400;
      statusIcon = Icons.hourglass_empty_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded,
              size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleName,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark)),
                if (votedAt != null)
                  Text(Formatters.timeAgo(votedAt),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(statusText,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noReceiptPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text('No receipt attached',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _projectStatusLabel(dynamic status) {
    switch (status.toString()) {
      case 'ProjectStatus.inProgress':
        return 'In Progress';
      case 'ProjectStatus.completed':
        return 'Completed';
      default:
        return 'Planned';
    }
  }
}
