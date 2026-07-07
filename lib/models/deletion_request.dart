import 'payment.dart';

enum DeletionTargetType { project, payment, milestone }

class DeletionRequest {
  final String id;
  final DeletionTargetType targetType;
  final String targetId;
  final String targetName;
  final String requestedBy;
  final String requestedByName;
  final PaymentApproval approvals;
  final PaymentStatus status;
  final DateTime createdAt;

  DeletionRequest({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.requestedBy,
    this.requestedByName = '',
    required this.approvals,
    required this.status,
    required this.createdAt,
  });

  factory DeletionRequest.fromMap(Map<dynamic, dynamic> map) {
    final approvals = PaymentApproval.fromMap(
      (map['approvals'] as Map<dynamic, dynamic>?) ?? {},
    );
    return DeletionRequest(
      id: map['id'] ?? '',
      targetType: map['targetType'] == 'project'
          ? DeletionTargetType.project
          : map['targetType'] == 'milestone'
              ? DeletionTargetType.milestone
              : DeletionTargetType.payment,
      targetId: map['targetId'] ?? '',
      targetName: map['targetName'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      approvals: approvals,
      status: _computeStatus(approvals),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static PaymentStatus _computeStatus(PaymentApproval approvals) {
    if (approvals.isRejected) return PaymentStatus.rejected;
    if (approvals.isFullyApproved) return PaymentStatus.approved;
    if (approvals.hasAnyApproval) return PaymentStatus.partiallyApproved;
    return PaymentStatus.pending;
  }

  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending Approval';
      case PaymentStatus.partiallyApproved:
        return 'Partially Approved';
      case PaymentStatus.approved:
        return 'Approved (Deleted)';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  String get targetTypeDisplayName {
    switch (targetType) {
      case DeletionTargetType.project:
        return 'Project';
      case DeletionTargetType.payment:
        return 'Payment';
      case DeletionTargetType.milestone:
        return 'Milestone';
    }
  }
}
