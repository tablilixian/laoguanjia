import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../household/providers/household_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _wagController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _wagAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _wagController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    
    _wagAnimation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _wagController, curve: Curves.easeInOut),
    );
    
    _bounceController.repeat(reverse: true);
    _wagController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _wagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdState = ref.watch(householdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(householdState.currentHousehold?.name ?? '未加入家庭'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text('仪表盘 - 待实现'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _bounceAnimation.value),
            child: child,
          );
        },
        child: AnimatedBuilder(
          animation: _wagAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _wagAnimation.value,
              child: child,
            );
          },
          child: FloatingActionButton(
            onPressed: () => context.push('/home/pets'),
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.pets,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
