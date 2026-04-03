import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/member.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/household_provider.dart';

/// 成员管理页面
class MemberManagementPage extends ConsumerWidget {
  const MemberManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdState = ref.watch(householdProvider);
    final authUser = ref.watch(authUserProvider);
    final theme = Theme.of(context);

    String? currentUserId;
    if (authUser.value != null) {
      currentUserId = authUser.value!.id;
    }

    Member? currentMember;
    if (currentUserId != null && householdState.members.isNotEmpty) {
      try {
        currentMember = householdState.members.firstWhere(
          (m) => m.userId == currentUserId,
        );
      } catch (_) {
        currentMember = householdState.members.first;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('成员管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showInviteSheet(context, ref),
            tooltip: '邀请成员',
          ),
        ],
      ),
      body: householdState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : householdState.members.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // 当前用户卡片
                if (currentMember != null)
                  _buildCurrentUserCard(context, ref, currentMember, theme),
                // 分隔线
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    '家庭成员 (${householdState.members.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // 成员列表
                ...householdState.members.map(
                  (member) => _buildMemberTile(
                    context,
                    ref,
                    member,
                    isCurrentUser: member.id == currentMember?.id,
                    currentMember: currentMember,
                    theme: theme,
                  ),
                ),
                // 底部邀请按钮
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _showInviteSheet(context, ref),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('邀请新成员'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '通过邀请码邀请家人加入家庭',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  /// 当前用户卡片
  Widget _buildCurrentUserCard(
    BuildContext context,
    WidgetRef ref,
    Member member,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(member, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '你',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildRoleChip(member.role, theme),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showEditNameDialog(context, ref, member),
                child: const Text('编辑'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 成员卡片
  Widget _buildMemberTile(
    BuildContext context,
    WidgetRef ref,
    Member member, {
    required bool isCurrentUser,
    required Member? currentMember,
    required ThemeData theme,
  }) {
    if (isCurrentUser) return const SizedBox.shrink();

    final isAdmin = currentMember?.role == MemberRole.admin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildAvatar(member, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRoleChip(member.role, theme),
                  ],
                ),
              ),
              if (isAdmin)
                TextButton(
                  onPressed: () => _showRemoveDialog(context, ref, member),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('移除'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 头像
  Widget _buildAvatar(Member member, ThemeData theme) {
    if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(member.avatarUrl!),
      );
    }

    final color = _getAvatarColor(member.id);
    final initial = member.name.isNotEmpty ? member.name[0] : '?';

    return CircleAvatar(
      radius: 24,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 角色标签
  Widget _buildRoleChip(MemberRole role, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: role == MemberRole.admin
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role == MemberRole.admin ? '管理员' : '成员',
        style: theme.textTheme.labelSmall?.copyWith(
          color: role == MemberRole.admin
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '家庭只有你一个人',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '邀请家人一起管理吧',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showInviteSheet(context, ref),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('邀请家人'),
          ),
        ],
      ),
    );
  }

  /// 编辑昵称弹窗
  void _showEditNameDialog(BuildContext context, WidgetRef ref, Member member) {
    final controller = TextEditingController(text: member.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入新的昵称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
                }
                return;
              }

              if (context.mounted) Navigator.pop(context);

              final success = await ref
                  .read(householdProvider.notifier)
                  .updateMemberName(member.id, newName);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('昵称已修改')));
                } else {
                  final error = ref.read(householdProvider).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? '修改失败'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 移除成员弹窗
  void _showRemoveDialog(BuildContext context, WidgetRef ref, Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要移除「${member.name}」吗？\n该成员将不再能访问家庭。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (context.mounted) Navigator.pop(context);

              await ref
                  .read(householdProvider.notifier)
                  .removeMember(member.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已移除成员「${member.name}」')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  /// 邀请弹窗
  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _InviteSheet(),
    );
  }

  /// 头像颜色（基于 ID hash，保证同一成员颜色固定）
  static const _avatarColors = [
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFF7986CB),
    Color(0xFF4DB6AC),
    Color(0xFFFFD54F),
    Color(0xFFA1887F),
    Color(0xFF90A4AE),
    Color(0xFF81C784),
    Color(0xFFFF8A65),
    Color(0xFFF06292),
  ];

  Color _getAvatarColor(String id) {
    final hash = id.split('').fold<int>(0, (prev, c) => prev + c.codeUnitAt(0));
    return _avatarColors[hash % _avatarColors.length];
  }
}

/// 邀请成员 BottomSheet
class _InviteSheet extends ConsumerWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);
    final inviteCode = householdState.currentHousehold?.inviteCode ?? '------';

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('邀请家人加入', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '分享邀请码，让家人加入家庭',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // 邀请码显示
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        inviteCode,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          letterSpacing: 6,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: householdState.isLoading
                          ? null
                          : () async {
                              final success = await ref
                                  .read(householdProvider.notifier)
                                  .refreshInviteCode();
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('邀请码已刷新')),
                                );
                              }
                            },
                      icon: householdState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text('刷新'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
