enum ProjectStatus { planned, inProgress, completed }

class Project {
  final String id;
  final String name;
  final String clientName;
  final double totalCost;
  final double totalPaid;
  final double remainingBalance;
  final DateTime startDate;
  final DateTime expectedCompletionDate;
  final ProjectStatus status;
  final List<String> milestones;
  final double completionPercentage;
  final String createdBy;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.clientName,
    required this.totalCost,
    this.totalPaid = 0,
    double? remainingBalance,
    this.milestones = const [],
    this.completionPercentage = 0,
    required this.startDate,
    required this.expectedCompletionDate,
    this.status = ProjectStatus.planned,
    required this.createdBy,
    required this.createdAt,
  }) : remainingBalance = remainingBalance ?? (totalCost - totalPaid);

  factory Project.fromMap(Map<dynamic, dynamic> map) {
    final cost = (map['totalCost'] ?? 0).toDouble();
    final paid = (map['totalPaid'] ?? 0).toDouble();
    return Project(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      clientName: map['clientName'] ?? '',
      totalCost: cost,
      totalPaid: paid,
      remainingBalance: (map['remainingBalance'] ?? (cost - paid)).toDouble(),
      milestones: (map['milestones'] as List<dynamic>?)
              ?.map((m) => m.toString())
              .toList() ??
          [],
      completionPercentage:
          (map['completionPercentage'] ?? 0).toDouble().clamp(0, 100),
      startDate:
          DateTime.tryParse(map['startDate']?.toString() ?? '') ?? DateTime.now(),
      expectedCompletionDate:
          DateTime.tryParse(map['expectedCompletionDate']?.toString() ?? '') ??
              DateTime.now(),
      status: ProjectStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ProjectStatus.planned,
      ),
      createdBy: map['createdBy'] ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'clientName': clientName,
      'totalCost': totalCost,
      'totalPaid': totalPaid,
      'remainingBalance': remainingBalance,
      'milestones': milestones,
      'completionPercentage': completionPercentage,
      'startDate': startDate.toIso8601String(),
      'expectedCompletionDate': expectedCompletionDate.toIso8601String(),
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get statusDisplayName {
    switch (status) {
      case ProjectStatus.planned:
        return 'Planned';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }

  double get progressPercentage {
    if (totalCost == 0) return 0;
    return (totalPaid / totalCost * 100).clamp(0, 100);
  }

  Project copyWith({
    String? id,
    String? name,
    String? clientName,
    double? totalCost,
    double? totalPaid,
    double? remainingBalance,
    List<String>? milestones,
    double? completionPercentage,
    DateTime? startDate,
    DateTime? expectedCompletionDate,
    ProjectStatus? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      totalCost: totalCost ?? this.totalCost,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingBalance: remainingBalance,
      milestones: milestones ?? this.milestones,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      startDate: startDate ?? this.startDate,
      expectedCompletionDate:
          expectedCompletionDate ?? this.expectedCompletionDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
