import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/utils/task_recurrence_helper.dart';
import '../../household/providers/household_provider.dart';

enum TaskFilter { all, pending, completed, deleted }

class TasksState {
  final List<Task> tasks;
  final List<Task> deletedTasks;
  final TaskFilter filter;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  TasksState({
    this.tasks = const [],
    this.deletedTasks = const [],
    this.filter = TaskFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  List<Task> get filteredTasks {
    var result = tasks;

    if (filter == TaskFilter.pending) {
      result = result.where((t) => !t.isCompleted).toList();
    } else if (filter == TaskFilter.completed) {
      result = result.where((t) => t.isCompleted).toList();
    } else if (filter == TaskFilter.deleted) {
      result = deletedTasks;
    }

    if (searchQuery.isNotEmpty) {
      result = result
          .where((t) =>
              t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (t.description?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    return result;
  }

  int get pendingCount => tasks.where((t) => !t.isCompleted).length;

  int get completedCount => tasks.where((t) => t.isCompleted).length;

  int get deletedCount => deletedTasks.length;

  TasksState copyWith({
    List<Task>? tasks,
    List<Task>? deletedTasks,
    TaskFilter? filter,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      deletedTasks: deletedTasks ?? this.deletedTasks,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TasksNotifier extends StateNotifier<TasksState> {
  final TaskRepository _repository = TaskRepository();
  final Ref _ref;

  TasksNotifier(this._ref) : super(TasksState()) {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final tasks = await _repository.getTasks(householdId);
      final deletedTasks = await _repository.getDeletedTasks(householdId);
      final resetTasks = TaskRecurrenceHelper.resetTasksIfNeeded(tasks);
      
      if (resetTasks != tasks) {
        await _updateResetTasks(tasks, resetTasks);
      }
      
      state = state.copyWith(
        tasks: resetTasks, 
        deletedTasks: deletedTasks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载任务失败: ${e.toString()}',
      );
    }
  }

  Future<void> _updateResetTasks(List<Task> originalTasks, List<Task> resetTasks) async {
    for (int i = 0; i < originalTasks.length; i++) {
      final originalTask = originalTasks[i];
      final resetTask = resetTasks[i];
      
      if (originalTask.status != resetTask.status || 
          originalTask.dueDate != resetTask.dueDate) {
        await _repository.updateTask(resetTask);
      }
    }
  }

  String? _getHouseholdId() {
    final householdState = _ref.read(householdProvider);
    return householdState.currentHousehold?.id;
  }

  Future<void> refresh() async {
    await _loadTasks();
  }

  void setFilter(TaskFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> createTask(Task task) async {
    print('=== TasksNotifier.createTask 开始 ===');
    state = state.copyWith(isLoading: true);

    try {
      final newTask = await _repository.createTask(task);
      print('createTask 成功，newTask: ${newTask.toMap()}');
      state = state.copyWith(
        tasks: [newTask, ...state.tasks],
        isLoading: false,
      );
    } catch (e, stackTrace) {
      print('createTask 错误: $e');
      print('堆栈跟踪: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '创建任务失败: ${e.toString()}',
      );
    }
  }

  Future<void> updateTask(Task task) async {
    state = state.copyWith(isLoading: true);

    try {
      final updatedTask = await _repository.updateTask(task);
      final index = state.tasks.indexWhere((t) => t.id == task.id);
      final newTasks = [...state.tasks];
      newTasks[index] = updatedTask;

      state = state.copyWith(
        tasks: newTasks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '更新任务失败: ${e.toString()}',
      );
    }
  }

  Future<void> toggleTaskStatus(String taskId) async {
    print('=== toggleTaskStatus 开始 ===');
    print('taskId: $taskId');
    
    final task = state.tasks.firstWhere((t) => t.id == taskId);
    print('当前任务: ${task.toMap()}');
    print('当前状态: ${task.status}');
    print('isCompleted: ${task.isCompleted}');
    
    final newStatus = !task.isCompleted;
    print('新状态: $newStatus');

    try {
      print('调用 repository.toggleTaskStatus...');
      final updatedTask = await _repository.toggleTaskStatus(taskId, newStatus);
      print('更新成功: ${updatedTask.toMap()}');
      
      final index = state.tasks.indexWhere((t) => t.id == taskId);
      final newTasks = [...state.tasks];
      newTasks[index] = updatedTask;

      state = state.copyWith(tasks: newTasks);
      print('状态已更新到 state');
    } catch (e, stackTrace) {
      print('toggleTaskStatus 错误: $e');
      print('堆栈跟踪: $stackTrace');
      state = state.copyWith(
        errorMessage: '更新任务状态失败: ${e.toString()}',
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.deleteTask(taskId);
      final deletedTask = state.tasks.firstWhere((t) => t.id == taskId);
      final newTasks = state.tasks.where((t) => t.id != taskId).toList();
      final newDeletedTasks = [...state.deletedTasks, deletedTask.copyWith(deletedAt: DateTime.now())];

      state = state.copyWith(
        tasks: newTasks,
        deletedTasks: newDeletedTasks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '删除任务失败: ${e.toString()}',
      );
    }
  }

  Future<void> restoreTask(String taskId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.restoreTask(taskId);
      final restoredTask = state.deletedTasks.firstWhere((t) => t.id == taskId);
      final newDeletedTasks = state.deletedTasks.where((t) => t.id != taskId).toList();
      final newTasks = [...state.tasks, restoredTask.copyWith(deletedAt: null)];

      state = state.copyWith(
        tasks: newTasks,
        deletedTasks: newDeletedTasks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '恢复任务失败: ${e.toString()}',
      );
    }
  }

  Future<void> clearDeletedTasks() async {
    state = state.copyWith(isLoading: true);

    try {
      final deletedTaskIds = state.deletedTasks.map((t) => t.id).toList();
      for (final taskId in deletedTaskIds) {
        await _repository.deleteTask(taskId);
      }

      state = state.copyWith(
        deletedTasks: [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '清空回收站失败: ${e.toString()}',
      );
    }
  }

  Future<void> searchTasks(String query) async {
    final householdId = _getHouseholdId();
    if (householdId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final tasks = await _repository.searchTasks(householdId, query);
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '搜索任务失败: ${e.toString()}',
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  return TasksNotifier(ref);
});
