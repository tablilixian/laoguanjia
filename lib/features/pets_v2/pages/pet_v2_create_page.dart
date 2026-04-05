import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';
import 'package:home_manager/features/pets_v2/providers/pet_v2_provider.dart';

/// 宠物管家 V2 创建页
class PetV2CreatePage extends ConsumerStatefulWidget {
  const PetV2CreatePage({super.key});

  @override
  ConsumerState<PetV2CreatePage> createState() => _PetV2CreatePageState();
}

class _PetV2CreatePageState extends ConsumerState<PetV2CreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  String _selectedType = 'cat';
  bool _isCreating = false;

  static const _petTypes = [
    {'value': 'cat', 'label': '猫咪', 'icon': '🐱'},
    {'value': 'dog', 'label': '狗狗', 'icon': '🐶'},
    {'value': 'rabbit', 'label': '兔子', 'icon': '🐰'},
    {'value': 'hamster', 'label': '仓鼠', 'icon': '🐹'},
    {'value': 'bird', 'label': '小鸟', 'icon': '🐦'},
    {'value': 'fish', 'label': '小鱼', 'icon': '🐟'},
    {'value': 'turtle', 'label': '乌龟', 'icon': '🐢'},
    {'value': 'lizard', 'label': '蜥蜴', 'icon': '🦎'},
    {'value': 'hedgehog', 'label': '刺猬', 'icon': '🦔'},
    {'value': 'pig', 'label': '小猪', 'icon': '🐷'},
    {'value': 'other', 'label': '其他', 'icon': '🐾'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _createPet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final household = ref.read(householdProvider).currentHousehold;
      if (household == null) {
        throw Exception('请先加入或创建一个家庭');
      }

      await ref.read(petV2ServiceProvider).createPet(
            householdId: household.id,
            ownerId: null,
            name: _nameController.text.trim(),
            type: _selectedType,
            breed: _breedController.text.trim().isEmpty
                ? null
                : _breedController.text.trim(),
          );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '添加宠物',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF5E6), Color(0xFFFFE0B2)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _petTypes
                          .firstWhere(
                            (t) => t['value'] == _selectedType,
                            orElse: () => {'icon': '🐾'},
                          )['icon'] as String,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name input
              const Text(
                '宠物名称',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '给宠物取个名字',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '请输入宠物名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Breed input
              const Text(
                '品种 (可选)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _breedController,
                decoration: InputDecoration(
                  hintText: '例如: 橘猫、金毛、垂耳兔',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Type selector
              const Text(
                '宠物类型',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _petTypes.map((type) {
                  final isSelected = type['value'] == _selectedType;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type['icon'] as String),
                        const SizedBox(width: 4),
                        Text(type['label'] as String),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedType = type['value'] as String);
                    },
                    selectedColor: const Color(0xFFFFE0B2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createPet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 2,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '创建宠物',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
