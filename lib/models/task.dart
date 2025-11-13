class Task {
  final String id;
  final String name;
  final String? description;
  final String status;
  final String? priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? project;
  final String? projectName;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? completedDate;
  final int? progress;

  Task({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.priority,
    this.assignedTo,
    this.assignedToName,
    this.project,
    this.projectName,
    this.dueDate,
    this.startDate,
    this.completedDate,
    this.progress,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'pending',
      priority: json['priority'],
      assignedTo: json['assignedTo']?['_id'] ?? json['assignedTo'],
      assignedToName: json['assignedTo']?['name'],
      project: json['project']?['_id'] ?? json['project'],
      projectName: json['project']?['name'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      completedDate: json['completedDate'] != null ? DateTime.parse(json['completedDate']) : null,
      progress: json['progress'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'status': status,
      'priority': priority,
      'assignedTo': assignedTo,
      'project': project,
      'dueDate': dueDate?.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'progress': progress,
    };
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) && status != 'completed';
  }

  String get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return '#4caf50';
      case 'in_progress':
        return '#2196f3';
      case 'pending':
        return '#ff9800';
      default:
        return '#9e9e9e';
    }
  }
}
