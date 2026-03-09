import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_manager/features/pets/pages/pet_create_page.dart';
import 'package:home_manager/features/pets/providers/pets_provider.dart';

class PetPage extends ConsumerWidget {
  const PetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('电子宠物'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/home/pets/create');
            },
          ),
        ],
      ),
      body: pets.when(
        data: (petsList) {
          if (petsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pets, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('还没有宠物，点击右上角添加'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: petsList.length,
            itemBuilder: (context, index) {
              final pet = petsList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: getPetIcon(pet.type),
                  ),
                  title: Text(pet.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${getPetTypeText(pet.type)} • 等级 ${pet.level}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusIndicator('饥饿', pet.hunger),
                          const SizedBox(width: 12),
                          _buildStatusIndicator('心情', pet.happiness),
                          const SizedBox(width: 12),
                          _buildStatusIndicator('清洁', pet.cleanliness),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    context.push('/home/pets/${pet.id}');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('错误: $error')),
      ),
    );
  }

  Widget getPetIcon(String type) {
    switch (type) {
      case 'cat':
        return const Icon(Icons.pets);
      case 'dog':
        return const Icon(Icons.pets);
      case 'rabbit':
        return const Icon(Icons.face);
      default:
        return const Icon(Icons.help);
    }
  }

  String getPetTypeText(String type) {
    switch (type) {
      case 'cat':
        return '猫咪';
      case 'dog':
        return '狗狗';
      case 'rabbit':
        return '兔子';
      default:
        return '其他';
    }
  }

  Widget _buildStatusIndicator(String label, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value%', style: const TextStyle(fontSize: 12)),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              widthFactor: value / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: getStatusColor(value),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color getStatusColor(int value) {
    if (value > 70) return Colors.green;
    if (value > 30) return Colors.yellow;
    return Colors.red;
  }
}
