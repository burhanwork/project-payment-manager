import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../utils/theme.dart';

class ApprovalIndicator extends StatelessWidget {
  final PaymentApproval approvals;
  final bool compact;
  final bool showAccountant;

  const ApprovalIndicator({
    super.key,
    required this.approvals,
    this.compact = false,
    this.showAccountant = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip('Dev', Icons.code, approvals.developer),
        const SizedBox(width: 6),
        _buildChip('Boss', Icons.person, approvals.boss),
        if (showAccountant) ...[
          const SizedBox(width: 6),
          _buildChip('Acct', Icons.calculate, approvals.accountant),
        ],
      ],
    );
  }

  Widget _buildChip(String label, IconData icon, bool? approved) {
    Color bgColor;
    Color iconColor;
    IconData statusIcon;

    if (approved == true) {
      bgColor = AppTheme.successColor.withValues(alpha: 0.1);
      iconColor = AppTheme.successColor;
      statusIcon = Icons.check_circle_rounded;
    } else if (approved == false) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.1);
      iconColor = AppTheme.errorColor;
      statusIcon = Icons.cancel_rounded;
    } else {
      bgColor = Colors.grey.shade50;
      iconColor = Colors.grey.shade400;
      statusIcon = Icons.radio_button_unchecked;
    }

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(statusIcon, color: iconColor, size: compact ? 16 : 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: iconColor,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
