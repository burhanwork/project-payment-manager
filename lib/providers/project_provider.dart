import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../services/project_service.dart';

final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService();
});

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, List<Project>>((ref) {
  return ProjectsNotifier(ref.read(projectServiceProvider));
});

class ProjectsNotifier extends StateNotifier<List<Project>> {
  final ProjectService _service;
  StreamSubscription? _subscription;

  ProjectsNotifier(this._service) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.projectsStream().listen(
      (projects) {
        state = projects;
      },
      onError: (_) {
        // Keep current state on error
      },
    );
  }

  void refresh() {
    _subscribe();
  }

  Future<void> addProject(
    Project project, {
    double initialPayment = 0,
    String? receiptPath,
  }) async {
    await _service.createProject(
      project,
      initialPayment: initialPayment,
      receiptPath: receiptPath,
    );
    // State is automatically updated by the stream listener
  }

  Future<void> updateProject(Project project) async {
    await _service.updateProject(project);
  }

  Future<void> updateCompletionPercentage(String projectId, double percentage) async {
    await _service.updateCompletionPercentage(projectId, percentage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class DashboardStats {
  final int totalProjects;
  final int activeProjects;
  final int completedProjects;
  final int plannedProjects;
  final double totalRevenue;
  final double totalPaid;
  final double totalRemaining;

  DashboardStats({
    required this.totalProjects,
    required this.activeProjects,
    required this.completedProjects,
    required this.plannedProjects,
    required this.totalRevenue,
    required this.totalPaid,
    required this.totalRemaining,
  });

  factory DashboardStats.fromProjects(List<Project> projects) {
    return DashboardStats(
      totalProjects: projects.length,
      activeProjects:
          projects.where((p) => p.status == ProjectStatus.inProgress).length,
      completedProjects:
          projects.where((p) => p.status == ProjectStatus.completed).length,
      plannedProjects:
          projects.where((p) => p.status == ProjectStatus.planned).length,
      totalRevenue: projects.fold(0, (sum, p) => sum + p.totalCost),
      totalPaid: projects.fold(0, (sum, p) => sum + p.totalPaid),
      totalRemaining: projects.fold(0, (sum, p) => sum + p.remainingBalance),
    );
  }

  factory DashboardStats.empty() {
    return DashboardStats(
      totalProjects: 0,
      activeProjects: 0,
      completedProjects: 0,
      plannedProjects: 0,
      totalRevenue: 0,
      totalPaid: 0,
      totalRemaining: 0,
    );
  }
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final projects = ref.watch(projectsProvider);
  return DashboardStats.fromProjects(projects);
});
