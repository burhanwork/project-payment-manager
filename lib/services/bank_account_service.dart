import 'dart:async';
import '../models/bank_account.dart';
import 'api_client.dart';
import 'socket_service.dart';

class BankAccountService {
  Timer? _pollTimer;
  StreamSubscription? _socketSub;
  final StreamController<List<BankAccount>> _controller =
      StreamController<List<BankAccount>>.broadcast();

  Stream<List<BankAccount>> accountsStream() {
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
      final accounts = await getAllAccounts();
      if (!_controller.isClosed) {
        _controller.add(accounts);
      }
    } catch (_) {}
  }

  Future<List<BankAccount>> getAllAccounts() async {
    final list = await ApiClient.getList('/bank-accounts/all');
    return list.map((m) => BankAccount.fromMap(m)).toList();
  }

  Future<List<BankAccount>> getActiveAccounts() async {
    final list = await ApiClient.getList('/bank-accounts');
    return list.map((m) => BankAccount.fromMap(m)).toList();
  }

  Future<void> createAccount({
    required String name,
    required String bankName,
    String? accountNumber,
    required double currentBalance,
    String currency = 'USD',
    String? notes,
  }) async {
    await ApiClient.post('/bank-accounts', {
      'name': name,
      'bankName': bankName,
      if (accountNumber != null) 'accountNumber': accountNumber,
      'currentBalance': currentBalance,
      'currency': currency,
      if (notes != null) 'notes': notes,
    });
    _fetchAndEmit();
  }

  Future<void> requestUpdateBalance(String accountId, double newBalance) async {
    await ApiClient.post('/bank-accounts/$accountId/request-update', {
      'newBalance': newBalance,
    });
    _fetchAndEmit();
  }

  Future<void> requestDelete(String accountId) async {
    await ApiClient.post('/bank-accounts/$accountId/request-delete', {});
    _fetchAndEmit();
  }

  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _controller.close();
  }
}
