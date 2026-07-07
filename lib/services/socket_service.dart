import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'notification_service.dart';

/// Connects to the backend Socket.IO server and shows local notifications
/// whenever another user performs an action (payment, deletion, project request).
class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  IO.Socket? _socket;
  String? _currentUserId;

  // Streams that services subscribe to for instant data refresh
  static final _paymentEvents = StreamController<void>.broadcast();
  static final _deletionEvents = StreamController<void>.broadcast();
  static final _projectRequestEvents = StreamController<void>.broadcast();
  static final _accountEvents = StreamController<void>.broadcast();

  static Stream<void> get paymentRefreshStream => _paymentEvents.stream;
  static Stream<void> get deletionRefreshStream => _deletionEvents.stream;
  static Stream<void> get projectRequestRefreshStream => _projectRequestEvents.stream;
  static Stream<void> get accountRefreshStream => _accountEvents.stream;

  static String get _serverUrl {
    return 'http://localhost:3003';
  }

  void connect(String userId) {
    _currentUserId = userId;

    // Disconnect any previous socket before reconnecting
    _socket?.disconnect();
    _socket?.dispose();

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => debugPrint('Socket connected: ${_socket!.id}'));
    _socket!.onDisconnect((_) => debugPrint('Socket disconnected'));
    _socket!.onConnectError((e) => debugPrint('Socket error: $e'));

    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    // ── Payments ──────────────────────────────────────────────────────────────

    _socket?.on('payment:created', (data) {
      _paymentEvents.add(null);
      if (_isSelf(data['addedBy'])) return;
      final amount = data['amount']?.toString() ?? '';
      _show(
        title: 'New Payment Submitted',
        body: '${data['addedByName']} submitted "${data['title']}" — \$$amount',
        type: 'approval',
      );
    });

    _socket?.on('payment:updated', (data) {
      _paymentEvents.add(null);
      if (_isSelf(data['actorId'])) return;
      final status = data['status'] as String? ?? '';
      final title = data['title'] as String? ?? '';
      final actor = data['actorName'] as String? ?? 'Someone';
      switch (status) {
        case 'approved':
          _show(
            title: 'Payment Fully Approved ✓',
            body: '$actor approved "$title". All parties have approved.',
            type: 'payment',
          );
          break;
        case 'rejected':
          _show(
            title: 'Payment Rejected',
            body: '$actor rejected payment "$title".',
            type: 'payment',
          );
          break;
        case 'partiallyApproved':
          _show(
            title: 'Payment Partially Approved',
            body: '$actor approved "$title". Awaiting more approvals.',
            type: 'approval',
          );
          break;
      }
    });

    // ── Deletions ─────────────────────────────────────────────────────────────

    _socket?.on('deletion:created', (data) {
      _deletionEvents.add(null);
      if (_isSelf(data['requestedBy'])) return;
      final targetType = data['targetType'] as String? ?? '';
      final name = data['targetName'] as String? ?? '';
      _show(
        title: 'Deletion Approval Needed',
        body: '${data['requestedByName']} wants to delete $targetType "$name". Your approval is needed.',
        type: 'approval',
      );
    });

    _socket?.on('deletion:updated', (data) {
      _deletionEvents.add(null);
      _paymentEvents.add(null); // deletion may affect payments list
      if (_isSelf(data['actorId'])) return;
      final status = data['status'] as String? ?? '';
      final name = data['targetName'] as String? ?? '';
      final actor = data['actorName'] as String? ?? 'Someone';
      switch (status) {
        case 'approved':
          _show(
            title: 'Deletion Approved & Executed',
            body: '$actor approved deleting "$name". Item has been deleted.',
            type: 'approval',
          );
          break;
        case 'rejected':
          _show(
            title: 'Deletion Rejected',
            body: '$actor rejected the deletion of "$name".',
            type: 'approval',
          );
          break;
        case 'partiallyApproved':
          _show(
            title: 'Deletion Partially Approved',
            body: '$actor approved deleting "$name". Awaiting more approvals.',
            type: 'approval',
          );
          break;
      }
    });

    // ── Project Requests ──────────────────────────────────────────────────────

    _socket?.on('project-request:created', (data) {
      _projectRequestEvents.add(null);
      if (_isSelf(data['requestedBy'])) return;
      _show(
        title: 'New Project Request',
        body: '${data['requestedByName']} wants to create project "${data['name']}". Approval needed.',
        type: 'approval',
      );
    });

    _socket?.on('project-request:updated', (data) {
      _projectRequestEvents.add(null);
      if (_isSelf(data['actorId'])) return;
      final status = data['status'] as String? ?? '';
      final name = data['name'] as String? ?? '';
      final actor = data['actorName'] as String? ?? 'Someone';
      switch (status) {
        case 'approved':
          _show(
            title: 'Project Approved & Created ✓',
            body: '$actor approved project "$name". It has been created.',
            type: 'project',
          );
          break;
        case 'rejected':
          _show(
            title: 'Project Request Rejected',
            body: '$actor rejected the request to create "$name".',
            type: 'approval',
          );
          break;
        case 'partiallyApproved':
          _show(
            title: 'Project Partially Approved',
            body: '$actor approved project "$name". Awaiting more approvals.',
            type: 'approval',
          );
          break;
      }
    });

    // ── Bank Accounts ─────────────────────────────────────────────────────────

    _socket?.on('account:created', (data) {
      _accountEvents.add(null);
    });

    _socket?.on('account:activated', (data) {
      _accountEvents.add(null);
      if (_isSelf(data['createdBy'])) return;
      _show(
        title: 'Bank Account Approved',
        body: '"${data['name']}" has been approved and is now active.',
        type: 'account',
      );
    });

    _socket?.on('account:updated', (data) {
      _accountEvents.add(null);
    });

    _socket?.on('account:deactivated', (data) {
      _accountEvents.add(null);
      _show(
        title: 'Bank Account Closed',
        body: '"${data['name']}" has been closed by unanimous approval.',
        type: 'account',
      );
    });

    _socket?.on('account-request:created', (data) {
      _accountEvents.add(null);
      if (_isSelf(data['requestedBy'])) return;
      final type = data['requestType'] as String? ?? '';
      final name = data['accountName'] as String? ?? '';
      final requester = data['requestedByName'] as String? ?? 'Someone';
      final label = type == 'create' ? 'add' : type == 'delete' ? 'remove' : 'update';
      _show(
        title: 'Account Approval Needed',
        body: '$requester wants to $label bank account "$name". Your approval is needed.',
        type: 'account',
      );
    });

    _socket?.on('account-request:updated', (data) {
      _accountEvents.add(null);
      if (_isSelf(data['actorId'])) return;
      final status = data['status'] as String? ?? '';
      final name = data['accountName'] as String? ?? '';
      final actor = data['actorName'] as String? ?? 'Someone';
      if (status == 'approved') {
        _show(title: 'Account Request Approved', body: '$actor approved "$name" request. It has been executed.', type: 'account');
      } else if (status == 'rejected') {
        _show(title: 'Account Request Rejected', body: '$actor rejected the "$name" request.', type: 'account');
      } else if (status == 'partiallyApproved') {
        _show(title: 'Account Request Partially Approved', body: '$actor approved "$name" request. Awaiting more approvals.', type: 'account');
      }
    });

    // ── Direct Project Changes ────────────────────────────────────────────────
    // Uses project:user_created / project:user_updated (only fired on direct
    // user actions) to avoid double-notifying on financial recalculations.

    _socket?.on('project:user_created', (data) {
      if (_isSelf(data['createdById'])) return;
      final creator = data['createdByName'] as String? ?? 'Someone';
      _show(
        title: 'New Project Created',
        body: '$creator created project "${data['name']}" for ${data['clientName']}.',
        type: 'project',
      );
    });

    _socket?.on('project:user_updated', (data) {
      if (_isSelf(data['updatedById'])) return;
      final name = data['name'] as String? ?? '';
      final completionValue = data['completionValue'];
      final updatedByName = data['updatedByName'] as String? ?? 'Someone';
      if (completionValue != null) {
        _show(
          title: 'Project Progress Updated',
          body: '$updatedByName updated "$name" completion to $completionValue%.',
          type: 'project',
        );
      } else {
        _show(
          title: 'Project Updated',
          body: '$updatedByName updated project "$name".',
          type: 'project',
        );
      }
    });

    _socket?.on('project:deleted', (data) {
      if (_isSelf(data['actorId'])) return;
      final actor = data['actorName'] as String? ?? 'Someone';
      _show(
        title: 'Project Deleted',
        body: '$actor\'s deletion approval was the final vote. The project has been permanently deleted.',
        type: 'project',
      );
    });
  }

  bool _isSelf(dynamic userId) {
    if (_currentUserId == null || userId == null) return false;
    return userId.toString() == _currentUserId;
  }

  void _show({required String title, required String body, String type = ''}) {
    NotificationService().showLocalNotification(title: title, body: body, payload: type);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentUserId = null;
  }
}
