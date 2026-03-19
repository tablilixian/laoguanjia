import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item_location.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/location_template/location_template.dart';
import '../../../data/location_template/location_template_library.dart';
import '../../household/providers/household_provider.dart';
import '../providers/locations_provider.dart';

class LocationInitWizard extends ConsumerStatefulWidget {
  const LocationInitWizard({super.key});

  @override
  ConsumerState<LocationInitWizard> createState() => _LocationInitWizardState();

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationInitWizard(),
    );
  }
}

class _LocationInitWizardState extends ConsumerState<LocationInitWizard> {
  final _repository = ItemRepository();
  int _currentStep = 0;
  final Set<String> _selectedRooms = {};
  bool _isLoading = false;
  bool _isCreating = false;

  final List<_RoomTemplate> _roomTemplates = [
    _RoomTemplate(name: '主卧', icon: '🛏️', keywords: ['主卧', '主卧室', '主人房']),
    _RoomTemplate(name: '次卧', icon: '🛏️', keywords: ['次卧', '次卧室', '客房', '客卧']),
    _RoomTemplate(name: '客厅', icon: '🛋️', keywords: ['客厅', '起居室']),
    _RoomTemplate(name: '厨房', icon: '🍳', keywords: ['厨房']),
    _RoomTemplate(name: '餐厅', icon: '🍽️', keywords: ['餐厅', '饭厅']),
    _RoomTemplate(name: '书房', icon: '📚', keywords: ['书房', '工作室']),
    _RoomTemplate(name: '卫生间', icon: '🚿', keywords: ['卫生间', '洗手间', '厕所', '浴室']),
    _RoomTemplate(name: '阳台', icon: '🌤️', keywords: ['阳台', '露台']),
    _RoomTemplate(name: '玄关', icon: '🚪', keywords: ['玄关', '门厅']),
    _RoomTemplate(name: '储物间', icon: '📦', keywords: ['储物间', '储藏室']),
    _RoomTemplate(name: '车库', icon: '🚗', keywords: ['车库', '停车位']),
    _RoomTemplate(name: '儿童房', icon: '🧸', keywords: ['儿童房', '儿童卧室', '小孩房']),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _currentStep == 0 ? _buildWelcomeStep() : _buildSelectionStep(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back),
            ),
          const Expanded(
            child: Text(
              '初始化位置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🏠', style: TextStyle(fontSize: 60)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '欢迎使用位置管理',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '让我们先创建你的家庭空间\n选择你家的房间类型',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '你可以随时在位置管理中添加更多位置或编辑现有位置',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '选择你的房间',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '选择你家的房间类型，系统会自动应用合适的模板',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _roomTemplates.map((room) {
            final isSelected = _selectedRooms.contains(room.name);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedRooms.remove(room.name);
                  } else {
                    _selectedRooms.add(room.name);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: (MediaQuery.of(context).size.width - 48) / 3,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGold.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryGold : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(room.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      room.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryGold : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        if (_selectedRooms.isNotEmpty) ...[
          const Text(
            '将创建的位置预览',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._selectedRooms.map((roomName) {
                  final room = _roomTemplates.firstWhere((r) => r.name == roomName);
                  final template = LocationTemplateLibrary.getRoomTemplate(roomName);
                  final slotCount = template?.totalSlots ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(room.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(room.name)),
                        Text(
                          '$slotCount 个槽位',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '合计',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_selectedRooms.length} 个位置',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('跳过'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isLoading || _isCreating
                  ? null
                  : () {
                      if (_currentStep == 0) {
                        setState(() => _currentStep = 1);
                      } else {
                        _createLocations();
                      }
                    },
              child: _isLoading || _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_currentStep == 0 ? '开始设置' : '创建位置'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createLocations() async {
    if (_selectedRooms.isEmpty) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      final householdId = ref.read(householdProvider).currentHousehold?.id;
      if (householdId == null) return;

      final now = DateTime.now();

      for (int i = 0; i < _selectedRooms.length; i++) {
        final roomName = _selectedRooms.elementAt(i);
        final room = _roomTemplates.firstWhere((r) => r.name == roomName);
        final template = LocationTemplateLibrary.getRoomTemplate(roomName);

        final location = ItemLocation(
          id: '',
          householdId: householdId,
          name: room.name,
          icon: room.icon,
          parentId: null,
          depth: 0,
          sortOrder: i,
          templateType: template?.type,
          templateConfig: template?.toConfigJson(),
          createdAt: now,
          updatedAt: now,
        );

        await _repository.createLocation(location);
      }

      ref.read(locationsProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已创建 ${_selectedRooms.length} 个位置'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

class _RoomTemplate {
  final String name;
  final String icon;
  final List<String> keywords;

  const _RoomTemplate({
    required this.name,
    required this.icon,
    required this.keywords,
  });
}
