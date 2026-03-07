import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../household/providers/household_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  bool _isResending = false;

  void _resendVerificationEmail() async {
    setState(() {
      _isResending = true;
    });

    await ref.read(authStateProvider.notifier).resendVerificationEmail();

    setState(() {
      _isResending = false;
    });
  }

  void _backToLogin() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (authState.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final householdState = ref.read(householdProvider);
        if (householdState.currentHousehold == null) {
          context.go('/create-household');
        } else {
          context.go('/home');
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('邮箱验证'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.email_outlined,
                size: 80,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '验证邮件已发送',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '我们已向 ${widget.email} 发送了验证邮件，请点击邮件中的链接完成验证。',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (authState.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  authState.errorMessage!,
                  style: const TextStyle(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isResending ? null : _resendVerificationEmail,
              icon: _isResending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.refresh),
              label: const Text('重新发送验证邮件'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _backToLogin,
              child: const Text('返回登录'),
            ),
            const SizedBox(height: 32),
            Text(
              '提示：',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '• 请检查垃圾邮件文件夹\n• 验证邮件可能需要几分钟才能到达\n• 点击邮件中的链接后会自动登录',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
