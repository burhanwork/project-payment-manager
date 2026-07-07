import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_account.dart';
import '../services/bank_account_service.dart';

final bankAccountServiceProvider = Provider<BankAccountService>((ref) {
  return BankAccountService();
});

final bankAccountsProvider =
    StateNotifierProvider<BankAccountsNotifier, List<BankAccount>>((ref) {
  return BankAccountsNotifier(ref.read(bankAccountServiceProvider));
});

class BankAccountsNotifier extends StateNotifier<List<BankAccount>> {
  final BankAccountService _service;
  StreamSubscription? _subscription;

  BankAccountsNotifier(this._service) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.accountsStream().listen(
      (accounts) {
        state = accounts;
      },
      onError: (_) {},
    );
  }

  void refresh() {
    _subscribe();
  }

  Future<void> createAccount({
    required String name,
    required String bankName,
    String? accountNumber,
    required double currentBalance,
    String currency = 'USD',
    String? notes,
  }) async {
    await _service.createAccount(
      name: name,
      bankName: bankName,
      accountNumber: accountNumber,
      currentBalance: currentBalance,
      currency: currency,
      notes: notes,
    );
  }

  Future<void> requestUpdateBalance(String accountId, double newBalance) async {
    await _service.requestUpdateBalance(accountId, newBalance);
  }

  Future<void> requestDelete(String accountId) async {
    await _service.requestDelete(accountId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final activeAccountsProvider = Provider<List<BankAccount>>((ref) {
  return ref.watch(bankAccountsProvider)
      .where((a) => a.status == BankAccountStatus.active)
      .toList();
});
