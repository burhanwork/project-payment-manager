import 'payment.dart';

enum AccountRequestType { create, updateBalance, delete }

class AccountRequest {
  final String id;
  final AccountRequestType requestType;
  final String accountId;
  final String accountName;
  final String requestedBy;
  final String requestedByName;
  final double? previousBalance;
  final double? newBalance;
  final PaymentApproval approvals;
  final PaymentStatus status;
  final DateTime createdAt;

  AccountRequest({
    required this.id,
    required this.requestType,
    required this.accountId,
    required this.accountName,
    required this.requestedBy,
    this.requestedByName = '',
    this.previousBalance,
    this.newBalance,
    required this.approvals,
    required this.status,
    required this.createdAt,
  });

  factory AccountRequest.fromMap(Map<dynamic, dynamic> map) {
    final approvals = PaymentApproval.fromMap(
      (map['approvals'] as Map<dynamic, dynamic>?) ?? {},
    );
    return AccountRequest(
      id: map['id'] ?? '',
      requestType: _parseType(map['requestType']),
      accountId: map['accountId'] ?? '',
      accountName: map['accountName'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      previousBalance: map['previousBalance'] != null ? (map['previousBalance'] as num).toDouble() : null,
      newBalance: map['newBalance'] != null ? (map['newBalance'] as num).toDouble() : null,
      approvals: approvals,
      status: _computeStatus(approvals),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static AccountRequestType _parseType(dynamic t) {
    switch (t) {
      case 'updateBalance':
        return AccountRequestType.updateBalance;
      case 'delete':
        return AccountRequestType.delete;
      default:
        return AccountRequestType.create;
    }
  }

  static PaymentStatus _computeStatus(PaymentApproval approvals) {
    // Only developer and boss need to approve account requests (accountant is the initiator)
    if (approvals.developer == false || approvals.boss == false) return PaymentStatus.rejected;
    if (approvals.developer == true && approvals.boss == true) return PaymentStatus.approved;
    if (approvals.developer == true || approvals.boss == true) return PaymentStatus.partiallyApproved;
    return PaymentStatus.pending;
  }

  String get requestTypeDisplayName {
    switch (requestType) {
      case AccountRequestType.create:
        return 'Add Account';
      case AccountRequestType.updateBalance:
        return 'Update Balance';
      case AccountRequestType.delete:
        return 'Remove Account';
    }
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
