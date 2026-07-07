import 'payment.dart';
import 'project.dart';

class ProjectRequest {
  final String id;
  final String name;
  final String clientName;
  final double totalCost;
  final double initialPayment;
  final List<String> milestones;
  final DateTime startDate;
  final DateTime expectedCompletionDate;
  final ProjectStatus projectStatus;
  final String requestedBy;
  final String requestedByName;
  final PaymentApproval approvals;
  final PaymentStatus status;
  final String? projectId;
  final String? proofPath;
  final DateTime createdAt;

  ProjectRequest({
    required this.id,
    required this.name,
    required this.clientName,
    required this.totalCost,
    required this.initialPayment,
    required this.milestones,
    required this.startDate,
    required this.expectedCompletionDate,
    required this.projectStatus,
    required this.requestedBy,
    this.requestedByName = '',
    required this.approvals,
    required this.status,
    this.projectId,
    this.proofPath,
    required this.createdAt,
  });

  factory ProjectRequest.fromMap(Map<dynamic, dynamic> map) {
    final approvals = PaymentApproval.fromMap(
      (map['approvals'] as Map<dynamic, dynamic>?) ?? {},
    );
    return ProjectRequest(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      clientName: map['clientName'] ?? '',
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      initialPayment: (map['initialPayment'] as num?)?.toDouble() ?? 0.0,
      milestones: (map['milestones'] as List<dynamic>?)
              ?.map((m) => m.toString())
              .toList() ??
          [],
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? '') ??
          DateTime.now(),
      expectedCompletionDate:
          DateTime.tryParse(map['expectedCompletionDate']?.toString() ?? '') ??
              DateTime.now(),
      projectStatus: _parseProjectStatus(map['projectStatus']?.toString()),
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      approvals: approvals,
      status: _computeStatus(approvals),
      projectId: map['projectId'] as String?,
      proofPath: map['proofPath'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static ProjectStatus _parseProjectStatus(String? s) {
    switch (s) {
      case 'inProgress':
        return ProjectStatus.inProgress;
      case 'completed':
        return ProjectStatus.completed;
      default:
        return ProjectStatus.planned;
    }
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
        return 'Approved';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }
}
