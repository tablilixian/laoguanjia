import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../household/providers/household_provider.dart';
import '../providers/tasks_provider.dart';
import '../../../data/models/task.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    
    final filter = TaskFilter.values[_tabController.index];
    ref.read(tasksProvider.notifier).setFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    if (householdState.currentHousehold == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('任务管理'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '请先加入或创建家庭',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/join-household'),
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('创建/加入家庭'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredTasks = tasksState.filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管理'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.primaryContainer,
          ),
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '待办'),
            Tab(text: '已完成'),
          ],
        ),
      ),
      body: tasksState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredTasks.isEmpty
              ? _buildEmptyState(context, theme)
              : RefreshIndicator(
                  onRefresh: () => ref.read(tasksProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      return _buildTaskCard(context, task, theme);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/home/tasks/create'),
        icon: const Icon(Icons.add),
        label: const Text('创建任务'),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 100,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            _getEmptyMessage(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建新任务',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    final filter = ref.read(tasksProvider).filter;
    switch (filter) {
      case TaskFilter.pending:
        return '暂无待办任务';
      case TaskFilter.completed:
        return '暂无已完成任务';
      default:
        return '暂无任务';
    }
  }

  Widget _buildTaskCard(BuildContext context, Task task, ThemeData theme) {
    final isOverdue = task.isOverdue && !task.isCompleted;
    final isDueToday = task.isDueToday && !task.isCompleted;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog(context, task);
      },
      onDismissed: (direction) {
        ref.read(tasksProvider.notifier).deleteTask(task.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => context.push('/home/tasks/${task.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已过期',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isDueToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '今天',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (_) {
                        ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
                      },
                    ),
                  ],
                ),
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(task.dueDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (task.assignedTo != null) ...[
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getAssignedMemberName(task),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) {
      return '今天 ${_formatTime(date)}';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return '明天 ${_formatTime(date)}';
    } else {
      return '${date.month}月${date.day}日 ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getAssignedMemberName(Task task) {
    if (task.assignedTo == null) return '未指派';
    
    final householdState = ref.read(householdProvider);
    final member = householdState.members
        .firstWhere((m) => m.id == task.assignedTo, orElse: () => householdState.members.first);
    return member.name;
  }

  Future<bool?> _showDeleteConfirmDialog(
    BuildContext context,
    Task task,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索任务'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入任务标题或描述',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            ref.read(tasksProvider.notifier).setSearchQuery(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              ref.read(tasksProvider.notifier).setSearchQuery('');
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}
