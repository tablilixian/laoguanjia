import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ItemCreatePage extends ConsumerStatefulWidget {
  final String? itemId; // 如果有值则为编辑模式

  const ItemCreatePage({super.key, this.itemId});

  @override
  ConsumerState<ItemCreatePage> createState() => _ItemCreatePageState();
}

class _ItemCreatePageState extends ConsumerState<ItemCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  String _selectedType = 'other';
  String? _selectedLocationId;
  String? _selectedOwnerId;

  bool get isEditMode => widget.itemId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? '编辑物品' : '添加物品'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_box_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isEditMode ? '编辑物品页' : '添加物品页',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'UI 尚未实现',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
