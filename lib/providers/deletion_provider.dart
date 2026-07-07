import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deletion_request.dart';
import '../models/payment.dart';
import '../services/deletion_service.dart';

final deletionServiceProvider = Provider<DeletionService>((ref) {
  return DeletionService();
});

final deletionsProvider =
    StateNotifierProvider<DeletionsNotifier, List<DeletionRequest>>((ref) {
  return DeletionsNotifier(ref.read(deletionServiceProvider));
});

class DeletionsNotifier extends StateNotifier<List<DeletionRequest>> {
  final DeletionService _service;
  StreamSubscription? _subscription;

  DeletionsNotifier(this._service) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.deletionsStream().listen(
      (deletions) {
        state = deletions;
      },
      onError: (_) {
        // Keep current state on error
      },
    );
  }

  void refresh() {
    _subscribe();
  }

  Future<DeletionRequest> createDeletionRequest({
    required String targetType,
    required String targetId,
    String? milestoneName,
  }) async {
    return await _service.createDeletionRequest(
      targetType: targetType,
      targetId: targetId,
      milestoneName: milestoneName,
    );
  }

  Future<void> approveDeletion({
    required String deletionId,
    required dynamic role,
    required String userId,
  }) async {
    await _service.approveDeletion(
      deletionId: deletionId,
      role: role,
      userId: userId,
    );
  }

  Future<void> rejectDeletion({
    required String deletionId,
    required dynamic role,
    required String userId,
  }) async {
    await _service.rejectDeletion(
      deletionId: deletionId,
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

final pendingDeletionsCountProvider = Provider<int>((ref) {
  final deletions = ref.watch(deletionsProvider);
  return deletions
      .where((d) =>
          d.status == PaymentStatus.pending ||
          d.status == PaymentStatus.partiallyApproved)
      .length;
});
