import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/payment.dart';
import '../models/app_user.dart';
import 'database_helper.dart';

class PaymentService {
  final StreamController<List<Payment>> _controller =
      StreamController<List<Payment>>.broadcast();

  Stream<List<Payment>> paymentsStream() {
    _fetchAndEmit();
    return _controller.stream;
  }

  Future<void> _fetchAndEmit() async {
    try {
      final payments = await getAllPayments();
      if (!_controller.isClosed) {
        _controller.add(payments);
      }
    } catch (_) {}
  }

  Future<String> addPayment(Payment payment, {String? receiptPath}) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    await DatabaseHelper.insertPayment({
      'id': id,
      'projectId': payment.projectId,
      'title': payment.title,
      'module': payment.module,
      'amount': payment.amount,
      'date': payment.date.toIso8601String(),
      'method': payment.method.name,
      'notes': payment.notes,
      'proofPath': receiptPath ?? payment.proofPath,
      'addedBy': payment.addedBy,
      'addedByName': payment.addedByName,
      'status': 'approved',
      'createdAt': now,
    });

    // Recalculate project totals
    await DatabaseHelper.recalcProjectTotals(payment.projectId);

    _fetchAndEmit();
    return id;
  }

  Future<List<Payment>> getPaymentsByProject(String projectId) async {
    final rows = await DatabaseHelper.getPaymentsByProject(projectId);
    return rows.map((row) => _paymentFromRow(row)).toList();
  }

  Future<List<Payment>> getAllPayments() async {
    final rows = await DatabaseHelper.getPayments();
    return rows.map((row) => _paymentFromRow(row)).toList();
  }

  Future<List<Payment>> getPendingPayments() async {
    return []; // No pending payments in offline mode - all auto-approved
  }

  Future<void> uploadReceipt(String paymentId, String filePath) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'payments',
      {'proofPath': filePath},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
    _fetchAndEmit();
  }

  Future<void> approvePayment({
    required String paymentId,
    required UserRole role,
    required String userId,
  }) async {
    // In offline mode, payments are auto-approved
    _fetchAndEmit();
  }

  Future<void> rejectPayment({
    required String paymentId,
    required UserRole role,
    required String userId,
  }) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'payments',
      {'status': 'rejected'},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
    _fetchAndEmit();
  }

  Payment _paymentFromRow(Map<String, dynamic> row) {
    final status = PaymentStatus.values.firstWhere(
      (s) => s.name == row['status'],
      orElse: () => PaymentStatus.approved,
    );

    // Build approvals based on status
    final isApproved = status == PaymentStatus.approved;
    final approvals = PaymentApproval(
      developer: isApproved ? true : null,
      boss: isApproved ? true : null,
      accountant: isApproved ? true : null,
    );

    return Payment(
      id: row['id'] as String,
      projectId: row['projectId'] as String,
      title: row['title'] as String,
      module: row['module'] as String?,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(row['date'] as String) ?? DateTime.now(),
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == row['method'],
        orElse: () => PaymentMethod.other,
      ),
      notes: row['notes'] as String?,
      proofPath: row['proofPath'] as String?,
      addedBy: row['addedBy'] as String,
      addedByName: (row['addedByName'] as String?) ?? '',
      approvals: approvals,
      status: status,
      createdAt:
          DateTime.tryParse(row['createdAt'] as String) ?? DateTime.now(),
    );
  }

  void dispose() {
    _controller.close();
  }
}
