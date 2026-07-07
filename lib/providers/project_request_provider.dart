import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_request.dart';
import '../models/payment.dart';
import '../services/project_request_service.dart';

final projectRequestServiceProvider = Provider<ProjectRequestService>((ref) {
  return ProjectRequestService();
});

final projectRequestsProvider =
    StateNotifierProvider<ProjectRequestsNotifier, List<ProjectRequest>>((ref) {
  return ProjectRequestsNotifier(ref.read(projectRequestServiceProvider));
});

class ProjectRequestsNotifier extends StateNotifier<List<ProjectRequest>> {
  final ProjectRequestService _service;
  StreamSubscription? _subscription;

  ProjectRequestsNotifier(this._service) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.projectRequestsStream().listen(
      (requests) {
        state = requests;
      },
      onError: (_) {},
    );
  }

  void refresh() {
    _subscribe();
  }

  Future<void> createProjectRequest({
    required String name,
    required String clientName,
    required double totalCost,
    required double initialPayment,
    required List<String> milestones,
    required DateTime startDate,
    required DateTime expectedCompletionDate,
    required String status,
    String? receiptPath,
    String? bankAccountId,
  }) async {
    await _service.createProjectRequest(
      name: name,
      clientName: clientName,
      totalCost: totalCost,
      initialPayment: initialPayment,
      milestones: milestones,
      startDate: startDate,
      expectedCompletionDate: expectedCompletionDate,
      status: status,
      receiptPath: receiptPath,
      bankAccountId: bankAccountId,
    );
  }

  Future<void> approveProjectRequest({
    required String requestId,
    required dynamic role,
    required String userId,
  }) async {
    await _service.approveProjectRequest(
      requestId: requestId,
      role: role,
      userId: userId,
    );
  }

  Future<void> rejectProjectRequest({
    required String requestId,
    required dynamic role,
    required String userId,
  }) async {
    await _service.rejectProjectRequest(
      requestId: requestId,
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

final pendingProjectRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(projectRequestsProvider);
  return requests
      .where((r) =>
          r.status == PaymentStatus.pending ||
          r.status == PaymentStatus.partiallyApproved)
      .length;
});
