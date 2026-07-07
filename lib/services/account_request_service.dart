import 'dart:async';
import '../models/account_request.dart';
import 'api_client.dart';
import 'socket_service.dart';

class AccountRequestService {
  Timer? _pollTimer;
  StreamSubscription? _socketSub;
  final StreamController<List<AccountRequest>> _controller =
      StreamController<List<AccountRequest>>.broadcast();

  Stream<List<AccountRequest>> requestsStream() {
    _startPolling();
    _socketSub?.cancel();
    _socketSub = SocketService.accountRefreshStream.listen((_) => _fetchAndEmit());
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
      final requests = await getAllRequests();
      if (!_controller.isClosed) {
        _controller.add(requests);
      }
    } catch (_) {}
  }

  Future<List<AccountRequest>> getAllRequests() async {
    final list = await ApiClient.getList('/account-requests');
    return list.map((m) => AccountRequest.fromMap(m)).toList();
  }

  Future<List<AccountRequest>> getPendingRequests() async {
    final list = await ApiClient.getList('/account-requests/pending');
    return list.map((m) => AccountRequest.fromMap(m)).toList();
  }

  Future<void> approveRequest(String requestId) async {
    await ApiClient.post('/account-requests/$requestId/approve', {});
    _fetchAndEmit();
  }

  Future<void> rejectRequest(String requestId) async {
    await ApiClient.post('/account-requests/$requestId/reject', {});
    _fetchAndEmit();
  }

  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _controller.close();
  }
}
