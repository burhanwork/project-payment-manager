import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import 'database_helper.dart';

class ProjectService {
  final StreamController<List<Project>> _controller =
      StreamController<List<Project>>.broadcast();

  Stream<List<Project>> projectsStream() {
    _fetchAndEmit();
    return _controller.stream;
  }

  Future<void> _fetchAndEmit() async {
    try {
      final projects = await getProjects();
      if (!_controller.isClosed) {
        _controller.add(projects);
      }
    } catch (_) {}
  }

  Future<String> createProject(
    Project project, {
    double initialPayment = 0,
    String? receiptPath,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    await DatabaseHelper.insertProject({
      'id': id,
      'name': project.name,
      'clientName': project.clientName,
      'totalCost': project.totalCost,
      'totalPaid': initialPayment,
      'remainingBalance': project.totalCost - initialPayment,
      'milestones': jsonEncode(project.milestones),
      'completionPercentage': 0,
      'startDate': project.startDate.toIso8601String(),
      'expectedCompletionDate': project.expectedCompletionDate.toIso8601String(),
      'status': project.status.name,
      'createdBy': project.createdBy,
      'createdAt': now,
    });

    // If there's an initial payment, create a payment record
    if (initialPayment > 0) {
      final paymentId = const Uuid().v4();
      await DatabaseHelper.insertPayment({
        'id': paymentId,
        'projectId': id,
        'title': 'Initial Payment',
        'amount': initialPayment,
        'date': project.startDate.toIso8601String(),
        'method': 'bankTransfer',
        'proofPath': receiptPath,
        'addedBy': project.createdBy,
        'addedByName': '',
        'status': 'approved',
        'createdAt': now,
      });
    }

    _fetchAndEmit();
    return id;
  }

  Future<List<Project>> getProjects() async {
    final rows = await DatabaseHelper.getProjects();
    return rows.map((row) => _projectFromRow(row)).toList();
  }

  Future<Project?> getProject(String projectId) async {
    final row = await DatabaseHelper.getProject(projectId);
    if (row == null) return null;
    return _projectFromRow(row);
  }

  Future<void> updateProject(Project project) async {
    await DatabaseHelper.updateProject(project.id, {
      'name': project.name,
      'clientName': project.clientName,
      'totalCost': project.totalCost,
      'milestones': jsonEncode(project.milestones),
      'startDate': project.startDate.toIso8601String(),
      'expectedCompletionDate': project.expectedCompletionDate.toIso8601String(),
      'status': project.status.name,
    });
    _fetchAndEmit();
  }

  Future<void> updateCompletionPercentage(
      String projectId, double percentage) async {
    await DatabaseHelper.updateProject(projectId, {
      'completionPercentage': percentage,
    });
    _fetchAndEmit();
  }

  Project _projectFromRow(Map<String, dynamic> row) {
    List<String> milestones = [];
    final milestonesRaw = row['milestones'];
    if (milestonesRaw is String && milestonesRaw.isNotEmpty) {
      try {
        milestones = (jsonDecode(milestonesRaw) as List<dynamic>)
            .map((m) => m.toString())
            .toList();
      } catch (_) {}
    }

    final cost = (row['totalCost'] as num?)?.toDouble() ?? 0;
    final paid = (row['totalPaid'] as num?)?.toDouble() ?? 0;

    return Project(
      id: row['id'] as String,
      name: row['name'] as String,
      clientName: row['clientName'] as String,
      totalCost: cost,
      totalPaid: paid,
      remainingBalance: cost - paid,
      milestones: milestones,
      completionPercentage:
          (row['completionPercentage'] as num?)?.toDouble() ?? 0,
      startDate:
          DateTime.tryParse(row['startDate'] as String) ?? DateTime.now(),
      expectedCompletionDate:
          DateTime.tryParse(row['expectedCompletionDate'] as String) ??
              DateTime.now(),
      status: ProjectStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => ProjectStatus.planned,
      ),
      createdBy: row['createdBy'] as String,
      createdAt:
          DateTime.tryParse(row['createdAt'] as String) ?? DateTime.now(),
    );
  }

  void dispose() {
    _controller.close();
  }
}
