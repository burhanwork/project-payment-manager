import 'dart:async';
import '../models/project_request.dart';
import '../models/app_user.dart';
import 'api_client.dart';
import 'socket_service.dart';

class ProjectRequestService {
  Timer? _pollTimer;
  StreamSubscription? _socketSub;
  final StreamController<List<ProjectRequest>> _controller =
      StreamController<List<ProjectRequest>>.broadcast();

  Stream<List<ProjectRequest>> projectRequestsStream() {
    _startPolling();
    _socketSub?.cancel();
    _socketSub = SocketService.projectRequestRefreshStream.listen((_) => _fetchAndEmit());
    return _controller.stream;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _fetchAndEmit();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchAndEmit();
    });
  }

  Future<void> _fetchAndEmit() async {
    try {
      final requests = await getAllProjectRequests();
      if (!_controller.isClosed) {
        _controller.add(requests);
      }
    } catch (_) {}
  }

  Future<ProjectRequest> createProjectRequest({
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
    final fields = {
      'name': name,
      'clientName': clientName,
      'totalCost': totalCost.toString(),
      'initialPayment': initialPayment.toString(),
      'startDate': startDate.toIso8601String(),
      'expectedCompletionDate': expectedCompletionDate.toIso8601String(),
      'status': status,
      if (bankAccountId != null) 'bankAccountId': bankAccountId,
      for (var i = 0; i < milestones.length; i++) 'milestones[$i]': milestones[i],
    };
    final response = await ApiClient.postMultipart(
      '/project-requests',
      fields,
      filePath: receiptPath,
    );
    _fetchAndEmit();
    return ProjectRequest.fromMap(response);
  }

  Future<List<ProjectRequest>> getAllProjectRequests() async {
    final list = await ApiClient.getList('/project-requests');
    return list.map((m) => ProjectRequest.fromMap(m)).toList();
  }

  Future<void> approveProjectRequest({
    required String requestId,
    required UserRole role,
    required String userId,
  }) async {
    await ApiClient.post('/project-requests/$requestId/approve', {});
    _fetchAndEmit();
  }

  Future<void> rejectProjectRequest({
    required String requestId,
    required UserRole role,
    required String userId,
  }) async {
    await ApiClient.post('/project-requests/$requestId/reject', {});
    _fetchAndEmit();
  }

  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _controller.close();
  }
}
