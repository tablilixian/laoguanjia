// 地产大亨 - 骰子服务
import 'dart:math';

/// 骰子服务 - 负责掷骰子和相关逻辑
class DiceService {
  static final Random _random = Random();

  /// 掷两个骰子，返回总点数
  static int roll() {
    return rollDice1() + rollDice2();
  }

  /// 掷第一个骰子
  static int rollDice1() => _random.nextInt(6) + 1;

  /// 掷第二个骰子
  static int rollDice2() => _random.nextInt(6) + 1;

  /// 判断是否为双三（两个骰子点数相同）
  static bool isDoubles(int dice1, int dice2) => dice1 == dice2;

  /// 获取移动步数
  static (int dice1, int dice2, int total) rollBoth() {
    final dice1 = rollDice1();
    final dice2 = rollDice2();
    return (dice1, dice2, dice1 + dice2);
  }

  /// 计算经过起点后的位置
  /// [currentPosition] 当前职位 [steps] 移动步数
  static int calculatePosition(int currentPosition, int steps, {bool passGo = false}) {
    int newPosition = (currentPosition + steps) % 40;
    return newPosition;
  }

  /// 检查是否经过起点
  static bool checkPassGo(int currentPosition, int steps) {
    return currentPosition + steps >= 40;
  }
}
