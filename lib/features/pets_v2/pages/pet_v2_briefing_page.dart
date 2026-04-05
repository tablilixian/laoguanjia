import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/core/services/pet_butler_service.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';
import 'package:home_manager/features/pets_v2/providers/pet_v2_provider.dart';
import 'package:home_manager/features/pets_v2/widgets/mood_bubble.dart';

/// 管家播报页
///
/// 展示晨间播报、任务提醒、物品提醒。
class PetV2BriefingPage extends ConsumerStatefulWidget {
  const PetV2BriefingPage({super.key});

  @override
  ConsumerState<PetV2BriefingPage> createState() => _PetV2BriefingPageState();
}

class _PetV2BriefingPageState extends ConsumerState<PetV2BriefingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _typewriterController;
  String _displayedText = '';
  String _fullText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _typewriterController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _loadBriefing();
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    super.dispose();
  }

  Future<void> _loadBriefing() async {
    setState(() => _isLoading = true);

    try {
      final household = ref.read(householdProvider).currentHousehold;
      final petId = ref.read(currentPetV2IdProvider);

      if (household == null || petId == null) {
        setState(() {
          _fullText = '请先选择一只宠物';
          _isLoading = false;
        });
        return;
      }

      final petData = await ref.read(petV2ServiceProvider).getPetData(petId);
      final butler = PetButlerService();

      final briefing = await butler.generateBriefing(
        householdId: household.id,
        petName: petData?.petId.substring(0, 4) ?? '宠物',
      );

      final buffer = StringBuffer();
      buffer.writeln(briefing.greeting);
      buffer.writeln();

      if (briefing.weatherAdvice != null) {
        buffer.writeln('🌤️ ${briefing.weatherAdvice}');
        buffer.writeln();
      }

      if (briefing.taskAlerts.isNotEmpty) {
        buffer.writeln('📋 今日待办:');
        for (final alert in briefing.taskAlerts.take(3)) {
          final icon = alert.urgency == 'urgent' ? '🔴' : '🟡';
          buffer.writeln('$icon ${alert.message}');
        }
        buffer.writeln();
      }

      if (briefing.itemAlerts.isNotEmpty) {
        buffer.writeln('📦 物品提醒:');
        for (final alert in briefing.itemAlerts.take(3)) {
          final icon = alert.alertType == 'expired' ? '🚨' : '⚠️';
          buffer.writeln('$icon ${alert.message}');
        }
      }

      setState(() {
        _fullText = buffer.toString();
        _isLoading = false;
      });

      _startTypewriter();
    } catch (e) {
      setState(() {
        _fullText = '加载播报失败: $e';
        _isLoading = false;
      });
    }
  }

  void _startTypewriter() {
    _typewriterController.reset();
    _typewriterController.forward();

    int currentIndex = 0;
    _typewriterController.addListener(() {
      final newIndex = (_typewriterController.value * _fullText.length).round();
      if (newIndex != currentIndex && newIndex <= _fullText.length) {
        setState(() => _displayedText = _fullText.substring(0, newIndex));
        currentIndex = newIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '管家播报',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5D4037)),
            onPressed: _isLoading ? null : _loadBriefing,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoodBubble(
                    text: _displayedText,
                    emoji: '🐱',
                  ),
                  const SizedBox(height: 16),
                  if (!_typewriterController.isAnimating &&
                      _displayedText.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.check),
                      label: const Text('知道了'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
