import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/core/services/pet_butler_service.dart';
import 'package:home_manager/features/household/providers/household_provider.dart';

/// 物品管家页
///
/// 展示过期提醒、库存检查、维护建议。
class PetV2ItemsPage extends ConsumerStatefulWidget {
  const PetV2ItemsPage({super.key});

  @override
  ConsumerState<PetV2ItemsPage> createState() => _PetV2ItemsPageState();
}

class _PetV2ItemsPageState extends ConsumerState<PetV2ItemsPage> {
  List<ItemAlert> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final household = ref.read(householdProvider).currentHousehold;
      if (household == null) {
        setState(() {
          _error = '请先加入或创建一个家庭';
          _isLoading = false;
        });
        return;
      }

      final butler = PetButlerService();
      final briefing = await butler.generateBriefing(
        householdId: household.id,
        petName: '管家',
      );

      setState(() {
        _alerts = briefing.itemAlerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'expired':
        return Icons.warning_rounded;
      case 'expiring_soon':
        return Icons.schedule;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.info_outline;
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'expired':
        return const Color(0xFFFF5252);
      case 'expiring_soon':
        return const Color(0xFFFF9800);
      case 'maintenance':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getAlertLabel(String type) {
    switch (type) {
      case 'expired':
        return '已过期';
      case 'expiring_soon':
        return '即将过期';
      case 'maintenance':
        return '维护建议';
      default:
        return '提醒';
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
          '物品管家',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5D4037)),
            onPressed: _isLoading ? null : _loadItems,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('✅', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          const Text(
                            '一切正常！',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF5D4037),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '家里所有物品状态良好~',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        return _buildItemCard(alert);
                      },
                    ),
    );
  }

  Widget _buildItemCard(ItemAlert alert) {
    final color = _getAlertColor(alert.alertType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getAlertIcon(alert.alertType), color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.message,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _getAlertLabel(alert.alertType),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: color,
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (alert.location != null) ...[
              const SizedBox(height: 8),
              Text(
                '📍 位置: ${alert.location}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text('加入清单'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _dismissAlert(alert),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('已处理'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _dismissAlert(ItemAlert alert) {
    setState(() => _alerts.remove(alert));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ 「${alert.itemName}」已标记为已处理'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
