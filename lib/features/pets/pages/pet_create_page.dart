import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';
import 'package:home_manager/features/pets/providers/pets_provider.dart';

class PetCreatePage extends ConsumerStatefulWidget {
  const PetCreatePage({super.key});

  @override
  ConsumerState<PetCreatePage> createState() => _PetCreatePageState();
}

class _PetCreatePageState extends ConsumerState<PetCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  String _selectedType = 'cat';
  PetSkill? _selectedSkill;

  final List<PetSkill> _availableSkills = [
    PetSkill(
      id: 'emotional',
      name: '情感陪伴',
      description: '善于倾听和安慰',
      icon: '💕',
      level: 1,
      keywords: [],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'coding',
      name: '编程助手',
      description: '懂代码会 debug',
      icon: '💻',
      level: 1,
      keywords: [],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'study',
      name: '学习伙伴',
      description: '陪你学习解答问题',
      icon: '📚',
      level: 1,
      keywords: [],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'fitness',
      name: '健身教练',
      description: '制定训练计划',
      icon: '🏋️',
      level: 1,
      keywords: [],
      isVisible: true,
      unlockIntimacy: 0,
    ),
    PetSkill(
      id: 'cooking',
      name: '烹饪大师',
      description: '教做菜分享食谱',
      icon: '🍳',
      level: 1,
      keywords: [],
      isVisible: true,
      unlockIntimacy: 0,
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建宠物')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '宠物名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入宠物名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: '宠物类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cat', child: Text('🐱 猫咪')),
                  DropdownMenuItem(value: 'dog', child: Text('🐕 狗狗')),
                  DropdownMenuItem(value: 'rabbit', child: Text('🐰 兔子')),
                  DropdownMenuItem(value: 'hamster', child: Text('🐹 仓鼠')),
                  DropdownMenuItem(value: 'guinea_pig', child: Text('🐹 豚鼠')),
                  DropdownMenuItem(value: 'chinchilla', child: Text('🐻 龙猫')),
                  DropdownMenuItem(value: 'bird', child: Text('🐦 鸟类')),
                  DropdownMenuItem(value: 'parrot', child: Text('🦜 鹦鹉')),
                  DropdownMenuItem(value: 'fish', child: Text('🐟 鱼类')),
                  DropdownMenuItem(value: 'turtle', child: Text('🐢 乌龟')),
                  DropdownMenuItem(value: 'lizard', child: Text('🦎 蜥蜴')),
                  DropdownMenuItem(value: 'hedgehog', child: Text('🦔 刺猬')),
                  DropdownMenuItem(value: 'ferret', child: Text('🦨 雪貂')),
                  DropdownMenuItem(value: 'pig', child: Text('🐷 宠物猪')),
                  DropdownMenuItem(value: 'other', child: Text('🐾 其他')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: '品种（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '选择宠物技能',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '选择宠物擅长的领域，后续可以解锁更多技能',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _availableSkills.length,
                itemBuilder: (context, index) {
                  final skill = _availableSkills[index];
                  final isSelected = _selectedSkill?.id == skill.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSkill = null;
                        } else {
                          _selectedSkill = skill;
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Colors.white,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            skill.icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            skill.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            skill.description,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() &&
                      ref.read(householdProvider).currentHousehold != null) {
                    try {
                      final household = ref
                          .read(householdProvider)
                          .currentHousehold!;
                      final pet = Pet(
                        id: '',
                        householdId: household.id,
                        name: _nameController.text,
                        type: _selectedType,
                        breed: _breedController.text.isEmpty
                            ? null
                            : _breedController.text,
                        hunger: 50,
                        happiness: 50,
                        cleanliness: 50,
                        health: 100,
                        level: 1,
                        experience: 0,
                        skills: _selectedSkill != null ? [_selectedSkill!] : [],
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await ref
                          .read(petNotifierProvider.notifier)
                          .createPet(pet, userSelectedSkill: _selectedSkill);
                      if (context.mounted) {
                        context.pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('创建宠物失败: $e')));
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('创建宠物'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
