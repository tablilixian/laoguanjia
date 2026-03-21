enum TaskStatus { pending, completed }

enum TaskRecurrence { none, daily, weekly, monthly }

class Task {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String? assignedTo;
  final DateTime? dueDate;
  final TaskRecurrence recurrence;
  final TaskStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Task({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    this.assignedTo,
    this.dueDate,
    required this.recurrence,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      assignedTo: map['assigned_to'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      recurrence: TaskRecurrence.values.firstWhere(
        (e) => e.name == map['recurrence'],
        orElse: () => TaskRecurrence.none,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TaskStatus.pending,
      ),
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'due_date': dueDate?.toIso8601String(),
      'recurrence': recurrence.name,
      'status': status.name,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? householdId,
    String? title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    TaskRecurrence? recurrence,
    TaskStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Task(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      recurrence: recurrence ?? this.recurrence,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get isCompleted => status == TaskStatus.completed;

  bool get isDeleted => deletedAt != null;

  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = dueDate!;
    return now.year == due.year &&
        now.month == due.month &&
        now.day == due.day;
  }

  bool get isDueTomorrow {
    if (dueDate == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final due = dueDate!;
    return tomorrow.year == due.year &&
        tomorrow.month == due.month &&
        tomorrow.day == due.day;
  }
}
