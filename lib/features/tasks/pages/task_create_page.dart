import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../household/providers/household_provider.dart';
import '../providers/tasks_provider.dart';
import '../../../data/models/task.dart';
import '../../../data/models/member.dart';

class TaskCreatePage extends ConsumerStatefulWidget {
  final String? taskId;

  const TaskCreatePage({
    super.key,
    this.taskId,
  });

  @override
  ConsumerState<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends ConsumerState<TaskCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _assignedTo;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TaskRecurrence? _recurrence = TaskRecurrence.none;
  bool _isLoading = false;
  Task? _originalTask;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _loadTask();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    try {
      final tasksState = ref.read(tasksProvider);
      final task = tasksState.tasks.where((t) => t.id == widget.taskId).firstOrNull;

      if (task != null) {
        setState(() {
          _originalTask = task;
          _titleController.text = task.title;
          _descriptionController.text = task.description ?? '';
          _assignedTo = task.assignedTo;
          _dueDate = task.dueDate;
          _recurrence = task.recurrence;
          if (task.dueDate != null) {
            _dueTime = TimeOfDay.fromDateTime(task.dueDate!);
          }
        });
      }
    } catch (e) {
      print('加载任务失败: $e');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    print('=== 开始保存任务 ===');

    final householdState = ref.read(householdProvider);
    print('householdState: $householdState');
    print('currentHousehold: ${householdState.currentHousehold}');
    
    if (householdState.currentHousehold == null) {
      print('错误: currentHousehold 为 null');
      setState(() => _isLoading = false);
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    print('currentUser: $currentUser');
    
    if (currentUser == null) {
      print('错误: currentUser 为 null');
      setState(() => _isLoading = false);
      return;
    }

    final userId = currentUser.id;
    print('userId: $userId');
    print('householdId: ${householdState.currentHousehold!.id}');

    try {
      final task = Task(
        id: widget.taskId ?? const Uuid().v4(),
        householdId: householdState.currentHousehold!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        assignedTo: _assignedTo,
        dueDate: _dueDate != null && _dueTime != null
            ? DateTime(
                _dueDate!.year,
                _dueDate!.month,
                _dueDate!.day,
                _dueTime!.hour,
                _dueTime!.minute,
              )
            : null,
        recurrence: _recurrence ?? TaskRecurrence.none,
        status: widget.taskId == null ? TaskStatus.pending : (_originalTask?.status ?? TaskStatus.pending),
        createdBy: widget.taskId == null ? userId : (_originalTask?.createdBy ?? userId),
        createdAt: widget.taskId == null ? DateTime.now() : (_originalTask?.createdAt ?? DateTime.now()),
        completedAt: _originalTask?.completedAt,
        updatedAt: DateTime.now(),
      );

      print('准备保存任务: ${task.toMap()}');

      if (widget.taskId == null) {
        print('调用 createTask...');
        await ref.read(tasksProvider.notifier).createTask(task);
        print('createTask 完成');
      } else {
        print('调用 updateTask...');
        await ref.read(tasksProvider.notifier).updateTask(task);
        print('updateTask 完成');
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.taskId == null ? '任务创建成功' : '任务更新成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('错误: $e');
      print('堆栈跟踪: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    if (householdState.currentHousehold == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.taskId == null ? '创建任务' : '编辑任务'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('请先加入或创建家庭'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? '创建任务' : '编辑任务'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTitleField(theme),
            const SizedBox(height: 24),
            _buildDescriptionField(theme),
            const SizedBox(height: 24),
            _buildAssignedToField(theme),
            const SizedBox(height: 24),
            _buildDueDateField(theme),
            const SizedBox(height: 24),
            _buildRecurrenceField(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: '任务标题 *',
        hintText: '例如：倒垃圾',
        border: const OutlineInputBorder(),
        filled: true,
        prefixIcon: const Icon(Icons.title),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入任务标题';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: '任务描述',
        hintText: '添加更多细节...',
        border: const OutlineInputBorder(),
        filled: true,
        prefixIcon: const Icon(Icons.description_outlined),
      ),
      maxLines: 5,
    );
  }

  Widget _buildAssignedToField(ThemeData theme) {
    final householdState = ref.watch(householdProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '指派给',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _assignedTo,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            filled: true,
            prefixIcon: const Icon(Icons.person_outline),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('未指派'),
            ),
            ...householdState.members.map(
              (member) => DropdownMenuItem(
                value: member.id,
                child: Text(member.name),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _assignedTo = value);
          },
        ),
      ],
    );
  }

  Widget _buildDueDateField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '截止日期',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showDatePicker(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dueDate != null
                        ? '${_dueDate!.month}月${_dueDate!.day}日 ${_dueTime?.hour.toString().padLeft(2, '0')}:${_dueTime?.minute.toString().padLeft(2, '0')}'
                        : '选择日期和时间',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _dueDate != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _dueDate = null;
                        _dueTime = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '重复规则',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...TaskRecurrence.values.map(
          (recurrence) => RadioListTile<TaskRecurrence?>(
            title: Text(_getRecurrenceLabel(recurrence)),
            value: recurrence,
            groupValue: _recurrence,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _recurrence = value!);
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  String _getRecurrenceLabel(TaskRecurrence recurrence) {
    switch (recurrence) {
      case TaskRecurrence.none:
        return '不重复';
      case TaskRecurrence.daily:
        return '每天';
      case TaskRecurrence.weekly:
        return '每周';
      case TaskRecurrence.monthly:
        return '每月';
    }
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      _dueDate = pickedDate;
      _dueTime = pickedTime;
    });
  }
}
