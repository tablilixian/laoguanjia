import 'app_database.dart';
import '../models/task.dart' as models;

extension TaskExtensions on Task {
  Map<String, dynamic> toRemoteJson({bool forUpdate = false}) {
    final json = {
      'id': id,
      'household_id': householdId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'due_date': dueDate?.toIso8601String(),
      'recurrence': recurrence,
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'version': version,
    };
    
    // UPDATE 时不传递 updated_at，让远端数据库触发器自动设置
    // INSERT 时传递 updated_at
    if (!forUpdate) {
      json['updated_at'] = updatedAt.toIso8601String();
    }
    
    return json;
  }

  models.Task toTaskModel() {
    return models.Task(
      id: id,
      householdId: householdId,
      title: title,
      description: description,
      assignedTo: assignedTo,
      dueDate: dueDate,
      recurrence: models.TaskRecurrence.values.firstWhere(
        (e) => e.name == recurrence,
        orElse: () => models.TaskRecurrence.none,
      ),
      status: models.TaskStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => models.TaskStatus.pending,
      ),
      createdBy: createdBy,
      createdAt: createdAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}
