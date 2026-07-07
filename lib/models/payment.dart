enum PaymentStatus { pending, partiallyApproved, approved, rejected }

enum PaymentMethod { bankTransfer, cash, check, creditCard, online, other }

class PaymentApproval {
  final bool? developer;
  final bool? boss;
  final bool? accountant;
  final String? developerUid;
  final String? bossUid;
  final String? accountantUid;
  final DateTime? developerAt;
  final DateTime? bossAt;
  final DateTime? accountantAt;

  PaymentApproval({
    this.developer,
    this.boss,
    this.accountant,
    this.developerUid,
    this.bossUid,
    this.accountantUid,
    this.developerAt,
    this.bossAt,
    this.accountantAt,
  });

  factory PaymentApproval.fromMap(Map<dynamic, dynamic> map) {
    return PaymentApproval(
      developer: map['developer'] as bool?,
      boss: map['boss'] as bool?,
      accountant: map['accountant'] as bool?,
      developerUid: map['developerUid'] as String?,
      bossUid: map['bossUid'] as String?,
      accountantUid: map['accountantUid'] as String?,
      developerAt: map['developerAt'] != null
          ? DateTime.tryParse(map['developerAt'].toString())
          : null,
      bossAt: map['bossAt'] != null
          ? DateTime.tryParse(map['bossAt'].toString())
          : null,
      accountantAt: map['accountantAt'] != null
          ? DateTime.tryParse(map['accountantAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'developer': developer,
      'boss': boss,
      'accountant': accountant,
      'developerUid': developerUid,
      'bossUid': bossUid,
      'accountantUid': accountantUid,
      'developerAt': developerAt?.toIso8601String(),
      'bossAt': bossAt?.toIso8601String(),
      'accountantAt': accountantAt?.toIso8601String(),
    };
  }

  int get approvalCount {
    int count = 0;
    if (developer == true) count++;
    if (boss == true) count++;
    if (accountant == true) count++;
    return count;
  }

  bool get isFullyApproved =>
      developer == true && boss == true && accountant == true;

  bool get isRejected =>
      developer == false || boss == false || accountant == false;

  bool get hasAnyApproval => approvalCount > 0;
}

class Payment {
  final String id;
  final String projectId;
  final String title;
  final String? module;
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final String? notes;
  final String? proofPath;
  final String? bankAccountId;
  final String addedBy;
  final String addedByName;
  final PaymentApproval approvals;
  final PaymentStatus status;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.projectId,
    required this.title,
    this.module,
    required this.amount,
    required this.date,
    required this.method,
    this.notes,
    this.proofPath,
    this.bankAccountId,
    required this.addedBy,
    this.addedByName = '',
    required this.approvals,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromMap(Map<dynamic, dynamic> map) {
    final approvals = PaymentApproval.fromMap(
      (map['approvals'] as Map<dynamic, dynamic>?) ?? {},
    );
    return Payment(
      id: map['id'] ?? '',
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      module: map['module'] as String?,
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == map['method'],
        orElse: () => PaymentMethod.other,
      ),
      notes: map['notes'],
      proofPath: map['proofPath'],
      bankAccountId: map['bankAccountId'] as String?,
      addedBy: map['addedBy'] ?? '',
      addedByName: map['addedByName'] ?? '',
      approvals: approvals,
      status: _computeStatus(approvals),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'module': module,
      'amount': amount,
      'date': date.toIso8601String(),
      'method': method.name,
      'notes': notes,
      'proofPath': proofPath,
      'bankAccountId': bankAccountId,
      'addedBy': addedBy,
      'addedByName': addedByName,
      'approvals': approvals.toMap(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
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
        return 'Fully Approved';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  String get methodDisplayName {
    switch (method) {
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.check:
        return 'Check';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.online:
        return 'Online';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}
