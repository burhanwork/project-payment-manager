import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_request.dart';
import '../models/payment.dart';
import '../services/account_request_service.dart';

final accountRequestServiceProvider = Provider<AccountRequestService>((ref) {
  return AccountRequestService();
});

final accountRequestsProvider =
    StateNotifierProvider<AccountRequestsNotifier, List<AccountRequest>>((ref) {
  return AccountRequestsNotifier(ref.read(accountRequestServiceProvider));
});

class AccountRequestsNotifier extends StateNotifier<List<AccountRequest>> {
  final AccountRequestService _service;
  StreamSubscription? _subscription;

  AccountRequestsNotifier(this._service) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.requestsStream().listen(
      (requests) {
        state = requests;
      },
      onError: (_) {},
    );
  }

  void refresh() {
    _subscribe();
  }

  Future<void> approveRequest(String requestId) async {
    await _service.approveRequest(requestId);
  }

  Future<void> rejectRequest(String requestId) async {
    await _service.rejectRequest(requestId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final pendingAccountRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(accountRequestsProvider);
  return requests
      .where((r) =>
          r.status == PaymentStatus.pending ||
          r.status == PaymentStatus.partiallyApproved)
      .length;
});
