enum BankAccountStatus { pending, active, inactive }

class BankAccount {
  final String id;
  final String name;
  final String? accountNumber;
  final String bankName;
  final String currency;
  final double currentBalance;
  final String? notes;
  final String createdBy;
  final String createdByName;
  final BankAccountStatus status;
  final DateTime createdAt;

  BankAccount({
    required this.id,
    required this.name,
    this.accountNumber,
    required this.bankName,
    this.currency = 'USD',
    required this.currentBalance,
    this.notes,
    required this.createdBy,
    this.createdByName = '',
    required this.status,
    required this.createdAt,
  });

  factory BankAccount.fromMap(Map<dynamic, dynamic> map) {
    return BankAccount(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      accountNumber: map['accountNumber'] as String?,
      bankName: map['bankName'] ?? '',
      currency: map['currency'] ?? 'USD',
      currentBalance: (map['currentBalance'] ?? 0).toDouble(),
      notes: map['notes'] as String?,
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      status: _parseStatus(map['status']),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static BankAccountStatus _parseStatus(dynamic s) {
    switch (s) {
      case 'active':
        return BankAccountStatus.active;
      case 'inactive':
        return BankAccountStatus.inactive;
      default:
        return BankAccountStatus.pending;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'currency': currency,
      'currentBalance': currentBalance,
      'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isActive => status == BankAccountStatus.active;

  String get statusDisplayName {
    switch (status) {
      case BankAccountStatus.pending:
        return 'Pending Approval';
      case BankAccountStatus.active:
        return 'Active';
      case BankAccountStatus.inactive:
        return 'Closed';
    }
  }

  String get displayLabel => '$bankName – $name';
}
