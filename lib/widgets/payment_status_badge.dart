import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../utils/theme.dart';

class PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;
  final bool large;

  const PaymentStatusBadge({
    super.key,
    required this.status,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _color.withValues(alpha: 0.15),
            _color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: large ? 13 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
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

  String get _label {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partiallyApproved:
        return 'Partial';
      case PaymentStatus.approved:
        return 'Approved';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }
}
