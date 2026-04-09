// 地产大亨 - 音效服务
import 'package:flutter/services.dart';

/// 音效类型
enum SoundEffect {
  diceRoll,     // 掷骰子
  move,         // 移动
  buy,          // 购买成功
  rent,         // 收租金
  payRent,      // 付租金
  build,        // 建造
  jail,         // 进入监狱
  card,         // 抽卡
  win,          // 胜利
  lose,         // 失败
  click,        // 点击
}

/// 音效服务
class SoundService {
  static bool _enabled = true;
  static bool _musicEnabled = true;

  /// 初始化音效
  static Future<void> init() async {
    // 预留接口，可以后续添加实际音频库
  }

  /// 设置音效开关
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 设置背景音乐开关
  static void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
  }

  /// 播放音效
  static Future<void> play(SoundEffect effect) async {
    if (!_enabled) return;

    // 使用系统音效作为占位符
    // 后续可以替换为实际音频文件
    switch (effect) {
      case SoundEffect.click:
        await HapticFeedback.lightImpact();
        break;
      case SoundEffect.diceRoll:
        await HapticFeedback.mediumImpact();
        break;
      case SoundEffect.buy:
      case SoundEffect.build:
        await HapticFeedback.heavyImpact();
        break;
      case SoundEffect.rent:
      case SoundEffect.card:
        await HapticFeedback.selectionClick();
        break;
      case SoundEffect.jail:
        await HapticFeedback.vibrate();
        break;
      case SoundEffect.win:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        break;
      case SoundEffect.lose:
        await HapticFeedback.vibrate();
        break;
      default:
        await HapticFeedback.lightImpact();
    }
  }

  /// 播放移动音效
  static Future<void> playMove() => play(SoundEffect.move);

  /// 播放购买音效
  static Future<void> playBuy() => play(SoundEffect.buy);

  /// 播放租金音效
  static Future<void> playRent() => play(SoundEffect.rent);

  /// 播放建造音效
  static Future<void> playBuild() => play(SoundEffect.build);

  /// 播放抽卡音效
  static Future<void> playCard() => play(SoundEffect.card);

  /// 播放胜利音效
  static Future<void> playWin() => play(SoundEffect.win);

  /// 播放失败音效
  static Future<void> playLose() => play(SoundEffect.lose);

  /// 播放点击音效
  static Future<void> playClick() => play(SoundEffect.click);

  /// 释放资源
  static void dispose() {
    // 预留清理接口
  }
}