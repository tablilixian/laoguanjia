import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/household_provider.dart';

class JoinHouseholdPage extends ConsumerStatefulWidget {
  const JoinHouseholdPage({super.key});

  @override
  ConsumerState<JoinHouseholdPage> createState() => _JoinHouseholdPageState();
}

class _JoinHouseholdPageState extends ConsumerState<JoinHouseholdPage> {
  final _formKey = GlobalKey<FormState>();
  final _householdIdController = TextEditingController();
  final _memberNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _householdIdController.dispose();
    _memberNameController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinHousehold() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final householdNotifier = ref.read(householdProvider.notifier);
    final success = await householdNotifier.joinHousehold(
      householdId: _householdIdController.text.trim(),
      memberName: _memberNameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final error = ref.read(householdProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? '加入家庭失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('加入家庭'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
            tooltip: '设置',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.group_add_outlined,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '加入家庭',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '输入家庭邀请码加入已有家庭',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    TextFormField(
                      controller: _householdIdController,
                      decoration: const InputDecoration(
                        labelText: '家庭邀请码',
                        hintText: '请输入邀请码',
                        prefixIcon: Icon(Icons.vpn_key),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入家庭邀请码';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _memberNameController,
                      decoration: const InputDecoration(
                        labelText: '您的昵称',
                        hintText: '例如：爸爸',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入您的昵称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleJoinHousehold,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('加入家庭', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/create-household'),
                      child: const Text('没有家庭？创建新家庭'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
