// 地产大亨 - 操作记录看板组件
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../constants/board_config.dart';
import '../../providers/game_provider.dart';

/// 操作记录单项
class OperationLogEntry {
  final String id;
  final int turnNumber;
  final String playerName;
  final Color playerColor;
  final OperationType type;
  final String description;
  final int? amount; // 金额变化
  final String? propertyName;
  final DateTime timestamp;

  OperationLogEntry({
    required this.id,
    required this.turnNumber,
    required this.playerName,
    required this.playerColor,
    required this.type,
    required this.description,
    this.amount,
    this.propertyName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 操作类型
enum OperationType {
  rollDice, // 掷骰子
  move, // 移动
  buyProperty, // 购买地产
  payRent, // 支付租金
  collectRent, // 收取租金
  drawCard, // 抽卡
  tax, // 税务
  start, // 游戏开始
  doubles, // 对子
  jail, // 入狱
  build, // 建造
  mortgage, // 抵押
  other, // 其他
}

/// 操作记录管理器
class OperationLogManager extends ChangeNotifier {
  static OperationLogManager? _instance;
  static OperationLogManager get instance =>
      _instance ??= OperationLogManager._();

  OperationLogManager._();

  final List<OperationLogEntry> _entries = [];
  final int _maxEntries = 10;

  List<OperationLogEntry> get entries => List.unmodifiable(_entries);

  /// 添加记录
  void addEntry(OperationLogEntry entry) {
    _entries.add(entry);
    // 保持最多10条
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
  }

  /// 清空记录
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// 便捷方法：掷骰子
  void logRollDice({
    required String playerName,
    required Color playerColor,
    required int dice1,
    required int dice2,
    required int turnNumber,
    required int fromPosition,
  }) {
    final total = dice1 + dice2;
    final isDoubles = dice1 == dice2;
    final fromCell = boardCells[fromPosition];
    final toPosition = (fromPosition + total) % 40;
    final toCell = boardCells[toPosition];
    final passedStart = toPosition < fromPosition;

    String description;
    if (toPosition != fromPosition) {
      description =
          '从(${fromCell.name})移动${total}步到(${toCell.name})${passedStart ? "，经过起点" : ""}';
    } else {
      description = '原地不动';
    }

    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.rollDice,
        description: description,
      ),
    );
  }

  /// 便捷方法：购买地产
  void logBuyProperty({
    required String playerName,
    required Color playerColor,
    required String propertyName,
    required int price,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.buyProperty,
        description: '购买了 $propertyName',
        amount: -price,
        propertyName: propertyName,
      ),
    );
  }

  /// 便捷方法：支付租金
  void logPayRent({
    required String playerName,
    required Color playerColor,
    required String propertyName,
    required int amount,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.payRent,
        description: '向$propertyName支付租金',
        amount: -amount,
        propertyName: propertyName,
      ),
    );
  }

  /// 便捷方法：收取租金
  void logCollectRent({
    required String playerName,
    required Color playerColor,
    required String fromPlayerName,
    required int amount,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.collectRent,
        description: '从$fromPlayerName收取租金',
        amount: amount,
      ),
    );
  }

  /// 便捷方法：抽卡
  void logDrawCard({
    required String playerName,
    required Color playerColor,
    required String cardTitle,
    required String cardDescription,
    required int? amount,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.drawCard,
        description: '$cardTitle: $cardDescription',
        amount: amount,
      ),
    );
  }

  /// 便捷方法：税务
  void logTax({
    required String playerName,
    required Color playerColor,
    required String taxType,
    required int amount,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.tax,
        description: taxType,
        amount: -amount,
      ),
    );
  }

  /// 便捷方法：对子
  void logDoubles({
    required String playerName,
    required Color playerColor,
    required int consecutiveCount,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.doubles,
        description: '掷到对子，可以再掷一次（连续$consecutiveCount次）',
      ),
    );
  }

  /// 便捷方法：入狱
  void logJail({
    required String playerName,
    required Color playerColor,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.jail,
        description: '被送进派出所',
      ),
    );
  }

  /// 便捷方法：经过起点
  void logPassStart({
    required String playerName,
    required Color playerColor,
    required int turnNumber,
  }) {
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.move,
        description: '经过起点，获得\$200',
        amount: 200,
      ),
    );
  }

  /// 便捷方法：建造
  void logBuild({
    required String playerName,
    required Color playerColor,
    required String propertyName,
    required int houses,
    required int price,
    required int turnNumber,
  }) {
    final houseText = houses >= 5 ? '酒店' : '${houses}栋房屋';
    addEntry(
      OperationLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        turnNumber: turnNumber,
        playerName: playerName,
        playerColor: playerColor,
        type: OperationType.build,
        description: '在$propertyName建造了$houseText',
        amount: -price,
        propertyName: propertyName,
      ),
    );
  }
}

/// 操作记录看板Widget
class OperationLogBoard extends StatelessWidget {
  final OperationLogManager manager;
  final VoidCallback? onTap;

  const OperationLogBoard({super.key, required this.manager, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        final entries = manager.entries;
        if (entries.isEmpty) {
          return _buildEmptyBoard();
        }
        return _buildLogList(entries);
      },
    );
  }

  Widget _buildEmptyBoard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: const Center(
        child: Text(
          '暂无操作记录',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildLogList(List<OperationLogEntry> entries) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '操作记录',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // 记录列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[entries.length - 1 - index]; // 最新在前面
                return _buildLogItem(entry);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(OperationLogEntry entry) {
    // 金额颜色
    Color? amountColor;
    String? amountText;
    if (entry.amount != null) {
      if (entry.amount! > 0) {
        amountColor = Colors.green;
        amountText = '+${entry.amount}';
      } else if (entry.amount! < 0) {
        amountColor = Colors.red;
        amountText = '${entry.amount}';
      }
    }

    // 类型图标
    IconData typeIcon;
    Color typeColor;
    switch (entry.type) {
      case OperationType.rollDice:
        typeIcon = Icons.casino;
        typeColor = Colors.orange;
        break;
      case OperationType.buyProperty:
        typeIcon = Icons.shopping_cart;
        typeColor = Colors.green;
        break;
      case OperationType.payRent:
      case OperationType.collectRent:
        typeIcon = Icons.attach_money;
        typeColor = Colors.red;
        break;
      case OperationType.drawCard:
        typeIcon = Icons.style;
        typeColor = Colors.purple;
        break;
      case OperationType.tax:
        typeIcon = Icons.receipt;
        typeColor = Colors.orange;
        break;
      case OperationType.doubles:
        typeIcon = Icons.stars;
        typeColor = Colors.amber;
        break;
      case OperationType.jail:
        typeIcon = Icons.gavel;
        typeColor = Colors.red;
        break;
      case OperationType.build:
        typeIcon = Icons.home;
        typeColor = Colors.blue;
        break;
      default:
        typeIcon = Icons.circle;
        typeColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号
          SizedBox(
            width: 16,
            child: Text(
              '${entry.turnNumber}',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
          ),
          // 玩家颜色标记
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: entry.playerColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 4),
          // 图标
          Icon(typeIcon, size: 10, color: typeColor),
          const SizedBox(width: 4),
          // 描述
          Expanded(
            child: Text(
              '${entry.playerName}: ${entry.description}',
              style: TextStyle(fontSize: 10, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 金额
          if (amountText != null)
            Text(
              amountText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// 操作记录看板Provider
final operationLogManagerProvider = Provider<OperationLogManager>((ref) {
  return OperationLogManager.instance;
});
