import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

final paymentsProvider =
    StateNotifierProvider<PaymentsNotifier, List<Payment>>((ref) {
  return PaymentsNotifier(ref.read(paymentServiceProvider));
});

class PaymentsNotifier extends StateNotifier<List<Payment>> {
  final PaymentService _service;
  StreamSubscription? _subscription;

  PaymentsNotifier(this._service) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.paymentsStream().listen(
      (payments) {
        state = payments;
      },
      onError: (_) {
        // Keep current state on error
      },
    );
  }

  void refresh() {
    _subscribe();
  }

  Future<void> addPayment(Payment payment, {String? receiptPath}) async {
    await _service.addPayment(payment, receiptPath: receiptPath);
    // State is automatically updated by the stream listener
  }

  Future<void> uploadReceipt(String paymentId, String filePath) async {
    await _service.uploadReceipt(paymentId, filePath);
  }

  Future<void> approvePayment({
    required String paymentId,
    required dynamic role,
    required String userId,
  }) async {
    await _service.approvePayment(
      paymentId: paymentId,
      role: role,
      userId: userId,
    );
  }

  Future<void> rejectPayment({
    required String paymentId,
    required dynamic role,
    required String userId,
  }) async {
    await _service.rejectPayment(
      paymentId: paymentId,
      role: role,
      userId: userId,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final pendingPaymentsCountProvider = Provider<int>((ref) {
  final payments = ref.watch(paymentsProvider);
  return payments
      .where((p) =>
          p.status == PaymentStatus.pending ||
          p.status == PaymentStatus.partiallyApproved)
      .length;
});

final recentPaymentsProvider = Provider<List<Payment>>((ref) {
  final payments = ref.watch(paymentsProvider);
  return payments.take(5).toList();
});
