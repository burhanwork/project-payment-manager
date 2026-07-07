import 'dart:async';
import '../models/deletion_request.dart';
import '../models/app_user.dart';
import 'api_client.dart';
import 'socket_service.dart';

class DeletionService {
  Timer? _pollTimer;
  StreamSubscription? _socketSub;
  final StreamController<List<DeletionRequest>> _controller =
      StreamController<List<DeletionRequest>>.broadcast();

  Stream<List<DeletionRequest>> deletionsStream() {
    _startPolling();
    _socketSub?.cancel();
    _socketSub = SocketService.deletionRefreshStream.listen((_) => _fetchAndEmit());
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
      final deletions = await getAllDeletions();
      if (!_controller.isClosed) {
        _controller.add(deletions);
      }
    } catch (_) {}
  }

  Future<DeletionRequest> createDeletionRequest({
    required String targetType,
    required String targetId,
    String? milestoneName,
  }) async {
    final body = <String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
    };
    if (milestoneName != null) body['milestoneName'] = milestoneName;
    final response = await ApiClient.post('/deletions', body);
    _fetchAndEmit();
    return DeletionRequest.fromMap(response);
  }

  Future<List<DeletionRequest>> getAllDeletions() async {
    final list = await ApiClient.getList('/deletions');
    return list.map((m) => DeletionRequest.fromMap(m)).toList();
  }

  Future<List<DeletionRequest>> getPendingDeletions() async {
    final list = await ApiClient.getList('/deletions/pending');
    return list.map((m) => DeletionRequest.fromMap(m)).toList();
  }

  Future<void> approveDeletion({
    required String deletionId,
    required UserRole role,
    required String userId,
  }) async {
    await ApiClient.post('/deletions/$deletionId/approve', {});
    _fetchAndEmit();
  }

  Future<void> rejectDeletion({
    required String deletionId,
    required UserRole role,
    required String userId,
  }) async {
    await ApiClient.post('/deletions/$deletionId/reject', {});
    _fetchAndEmit();
  }

  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _controller.close();
  }
}
