import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/data/models/pet.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // household is now obtained inside the onPressed callback

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建宠物'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
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
                items: [
                  DropdownMenuItem(value: 'cat', child: const Text('猫咪')),
                  DropdownMenuItem(value: 'dog', child: const Text('狗狗')),
                  DropdownMenuItem(value: 'rabbit', child: const Text('兔子')),
                  DropdownMenuItem(value: 'other', child: const Text('其他')),
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
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() && ref.read(householdProvider).currentHousehold != null) {
                    try {
                      final household = ref.read(householdProvider).currentHousehold!;
                      final pet = Pet(
                        id: '',
                        householdId: household.id,
                        name: _nameController.text,
                        type: _selectedType,
                        breed: _breedController.text.isEmpty ? null : _breedController.text,
                        hunger: 50,
                        happiness: 50,
                        cleanliness: 50,
                        health: 100,
                        level: 1,
                        experience: 0,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await ref.read(petNotifierProvider.notifier).createPet(pet);
                      context.pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('创建宠物失败: $e')),
                      );
                    }
                  }
                },
                child: const Text('创建宠物'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
