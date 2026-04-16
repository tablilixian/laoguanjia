import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 音效类型枚举 - 包含游戏中所有可用的音效
/// 
/// 每个音效都对应大富翁4原版音效文件，提供沉浸式的游戏体验
enum SoundEffect {
  // ==================== 核心游戏音效 ====================
  /// 掷骰子 - 骰子滚动的声音
  diceRoll,
  
  /// 棋子移动 - 企鹅走路的可爱声音
  tokenMove,
  
  /// 购买土地 - 购得土地确认音效
  buy,
  
  /// 缴纳过路费 - 付钱给其他玩家
  rent,
  
  /// 加盖建筑 - 建造房屋/酒店
  build,
  
  // ==================== 事件音效 ====================
  /// 进入监狱 - 警车警报声
  jail,
  
  /// 抽取卡牌 - 获得命运/公益卡
  card,
  
  /// 胜利 - 本月冠军欢呼声
  win,
  
  /// 破产 - 破产悲剧音效
  lose,
  
  // ==================== UI交互音效 ====================
  /// 按钮点击 - 轻微的点击反馈
  click,
  
  /// 确认操作 - 确定按钮音效
  confirm,
  
  /// 取消操作 - 取消按钮音效
  cancel,
  
  /// 错误提示 - 操作错误提示音
  error,
  
  // ==================== 特殊事件音效 ====================
  /// 掷出对子 - 乐透中奖欢呼（连续掷骰）
  doubles,
  
  /// 乐透开始 - 摇奖开始音效
  lotteryStart,
  
  /// 经过起点获得奖励 - 接到金币音效
  passGo,
  
  /// 抵押/赎回 - 关门音效
  mortgage,
  
  /// 拍卖成交 - 拍卖成功音效
  auction,
  
  // ==================== 神仙系统音效 ====================
  /// 土地公降临 - 保佑该格子的土地
  landGod,
  
  /// 天使降临 - 获得好运
  angel,
  
  /// 恶魔降临 - 遭遇不幸
  demon,
  
  /// 大财神 - 获得大量现金
  richGod,
  
  /// 大穷神 - 现金减少
  poorGod,
  
  /// 大衰神 - 遭遇不幸（可用作被衰神附身）
  decayGod,
  
  /// 神明离开 - 神仙效果结束
  godLeave,
  
  // ==================== 道具系统音效 ====================
  /// 使用卡片 - 使用道具卡
  useCard,
  
  /// 传送/飞毯 - 传送效果
  teleport,
  
  /// 被车撞到 - 被救护车/汽车撞飞
  hitByCar,
  
  /// 地雷爆炸 - 踩到地雷
  mineExplode,
  
  /// 放置地雷
  placeMine,
  
  /// 放置路障
  placeRoadblock,
  
  /// 接到炸弹 - 收到定时炸弹
  receiveBomb,
  
  /// 建筑被摧毁 - 核弹/地震等摧毁建筑
  buildingDestroy,
  
  /// 拆毁建筑 - 机器工人拆毁
  demolish,
  
  /// 机器工人加盖 - 快速建造
  buildWithWorker,
  
  /// 进入建筑 - 进入他人的建筑
  enterBuilding,
  
  // ==================== 财务相关音效 ====================
  /// 花费资金 - 支出金钱
  spendMoney,
  
  /// 股票分红 - 上市公司分红
  stockDividend,
}

/// 音效服务 - 管理游戏中所有音效的播放
/// 
/// 使用单例模式，通过大富翁4原版音效提供沉浸式体验。
/// 支持本地资源和网络URL双重模式，优先使用本地资源。
/// 当本地资源不可用时，回退到触觉反馈。
class SoundService {
  static bool _enabled = true;
  static bool _initialized = false;
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _musicPlayer = AudioPlayer();
  
  /// 音效资源映射表
  /// 
  /// key: SoundEffect 枚举值
  /// value: 本地资源路径（相对于 assets/）
  /// 
  /// 所有音效均来自大富翁4原版游戏，版权归原厂商所有
  /// 仅供学习交流使用
  static const Map<SoundEffect, String> _soundAssets = {
    // ==================== 核心游戏音效 ====================
    SoundEffect.diceRoll: 'sounds/dice.wav',
    SoundEffect.tokenMove: 'sounds/token_move.wav',
    SoundEffect.buy: 'sounds/buy.wav',
    SoundEffect.rent: 'sounds/rent.wav',
    SoundEffect.build: 'sounds/build.wav',
    
    // ==================== 事件音效 ====================
    SoundEffect.jail: 'sounds/jail.wav',
    SoundEffect.card: 'sounds/card.wav',
    SoundEffect.win: 'sounds/win.wav',
    SoundEffect.lose: 'sounds/lose.wav',
    
    // ==================== UI交互音效 ====================
    SoundEffect.click: 'sounds/click.wav',
    SoundEffect.confirm: 'sounds/confirm.wav',
    SoundEffect.cancel: 'sounds/cancel.wav',
    SoundEffect.error: 'sounds/error.wav',
    
    // ==================== 特殊事件音效 ====================
    SoundEffect.doubles: 'sounds/doubles.wav',
    SoundEffect.lotteryStart: 'sounds/lottery_start.wav',
    SoundEffect.passGo: 'sounds/pass_go.wav',
    SoundEffect.mortgage: 'sounds/mortgage.wav',
    SoundEffect.auction: 'sounds/auction.wav',
    
    // ==================== 神仙系统音效 ====================
    SoundEffect.landGod: 'sounds/land_god.wav',
    SoundEffect.angel: 'sounds/angel.wav',
    SoundEffect.demon: 'sounds/demon.wav',
    SoundEffect.richGod: 'sounds/rich_god.wav',
    SoundEffect.poorGod: 'sounds/poor_god.wav',
    SoundEffect.decayGod: 'sounds/decay_god.wav',
    SoundEffect.godLeave: 'sounds/god_leave.wav',
    
    // ==================== 道具系统音效 ====================
    SoundEffect.useCard: 'sounds/use_card.wav',
    SoundEffect.teleport: 'sounds/teleport.wav',
    SoundEffect.hitByCar: 'sounds/hit_by_car.wav',
    SoundEffect.mineExplode: 'sounds/mine_explode.wav',
    SoundEffect.placeMine: 'sounds/place_mine.wav',
    SoundEffect.placeRoadblock: 'sounds/place_roadblock.wav',
    SoundEffect.receiveBomb: 'sounds/receive_bomb.wav',
    SoundEffect.buildingDestroy: 'sounds/building_destroy.wav',
    SoundEffect.demolish: 'sounds/demolish.wav',
    SoundEffect.buildWithWorker: 'sounds/build_with_worker.wav',
    SoundEffect.enterBuilding: 'sounds/enter_building.wav',
    
    // ==================== 财务相关音效 ====================
    SoundEffect.spendMoney: 'sounds/spend_money.wav',
    SoundEffect.stockDividend: 'sounds/stock_dividend.wav',
  };

  /// 初始化音效服务
  /// 
  /// 在应用启动时调用一次，设置音频播放器参数。
  /// [ReleaseMode.stop] 确保每次播放新音效时停止当前音效，
  /// 避免多音效同时播放造成的混乱。
  static Future<void> init() async {
    if (_initialized) return;
    
    // 停止模式：每次播放新音效时停止当前音效
    await _player.setReleaseMode(ReleaseMode.stop);
    // 循环模式：用于背景音乐
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    
    _initialized = true;
    debugPrint('SoundService initialized');
  }

  /// 设置音效开关
  /// 
  /// [enabled] true: 播放音效, false: 禁用所有音效
  static void setEnabled(bool enabled) {
    _enabled = enabled;
    debugPrint('SoundService enabled: $enabled');
  }

  /// 获取当前音效开关状态
  static bool get isEnabled => _enabled;

  /// 播放指定音效
  /// 
  /// 播放流程：
  /// 1. 检查音效开关，禁用时直接返回
  /// 2. 获取音效对应的本地资源路径
  /// 3. 尝试播放本地音效资源
  /// 4. 播放失败时回退到触觉反馈
  /// 
  /// [effect] 要播放的音效类型
  static Future<void> play(SoundEffect effect) async {
    // 音效禁用时直接返回
    if (!_enabled) return;

    // 获取音效资源路径
    final asset = _soundAssets[effect];
    if (asset == null) {
      debugPrint('SoundService: unknown effect $effect');
      return;
    }

    try {
      // 停止当前播放的音效
      await _player.stop();
      // 播放本地音效资源
      await _player.play(AssetSource(asset));
      debugPrint('SoundService: playing $effect');
    } catch (e) {
      // 播放失败时输出错误日志
      debugPrint('SoundService: play failed for $effect: $e');
      // 回退到触觉反馈作为后备
      await _playHaptic(effect);
    }
  }

  /// 触觉反馈后备方案
  /// 
  /// 当音效播放失败时，使用设备振动提供反馈。
  /// 不同音效类型对应不同的振动强度。
  /// 
  /// [effect] 音效类型，用于选择振动模式
  static Future<void> _playHaptic(SoundEffect effect) async {
    switch (effect) {
      // 轻微反馈 - 点击类操作
      case SoundEffect.click:
      case SoundEffect.cancel:
      case SoundEffect.confirm:
        await HapticFeedback.lightImpact();
        
      // 中等反馈 - 移动、输入类操作
      case SoundEffect.diceRoll:
      case SoundEffect.tokenMove:
      case SoundEffect.error:
        await HapticFeedback.mediumImpact();
        
      // 强烈反馈 - 重要操作
      case SoundEffect.buy:
      case SoundEffect.build:
      case SoundEffect.buildWithWorker:
        await HapticFeedback.heavyImpact();
        
      // 选择反馈 - 获得类操作
      case SoundEffect.rent:
      case SoundEffect.card:
      case SoundEffect.useCard:
      case SoundEffect.passGo:
      case SoundEffect.doubles:
      case SoundEffect.lotteryStart:
        await HapticFeedback.selectionClick();
        
      // 振动反馈 - 负面事件
      case SoundEffect.jail:
      case SoundEffect.lose:
      case SoundEffect.demon:
      case SoundEffect.poorGod:
      case SoundEffect.decayGod:
      case SoundEffect.mineExplode:
      case SoundEffect.hitByCar:
      case SoundEffect.receiveBomb:
        await HapticFeedback.vibrate();
        
      // 双重重击 - 胜利、财神
      case SoundEffect.win:
      case SoundEffect.richGod:
      case SoundEffect.angel:
      case SoundEffect.landGod:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        
      // 默认轻微反馈
      default:
        await HapticFeedback.lightImpact();
    }
  }

  // ==================== 便捷播放方法 ====================
  // 以下方法提供更语义化的调用方式

  /// 播放掷骰子音效
  static Future<void> playDiceRoll() => play(SoundEffect.diceRoll);
  
  /// 播放棋子移动音效
  static Future<void> playTokenMove() => play(SoundEffect.tokenMove);
  
  /// 播放购买土地音效
  static Future<void> playBuy() => play(SoundEffect.buy);
  
  /// 播放缴纳过路费音效
  static Future<void> playRent() => play(SoundEffect.rent);
  
  /// 播放建造音效
  static Future<void> playBuild() => play(SoundEffect.build);
  
  /// 播放监狱音效
  static Future<void> playJail() => play(SoundEffect.jail);
  
  /// 播放抽卡音效
  static Future<void> playCard() => play(SoundEffect.card);
  
  /// 播放胜利音效
  static Future<void> playWin() => play(SoundEffect.win);
  
  /// 播放失败音效
  static Future<void> playLose() => play(SoundEffect.lose);
  
  /// 播放点击音效
  static Future<void> playClick() => play(SoundEffect.click);
  
  /// 播放确认音效
  static Future<void> playConfirm() => play(SoundEffect.confirm);
  
  /// 播放取消音效
  static Future<void> playCancel() => play(SoundEffect.cancel);
  
  /// 播放错误音效
  static Future<void> playError() => play(SoundEffect.error);
  
  /// 播放对子音效
  static Future<void> playDoubles() => play(SoundEffect.doubles);
  
  /// 播放经过起点音效
  static Future<void> playPassGo() => play(SoundEffect.passGo);
  
  /// 播放抵押音效
  static Future<void> playMortgage() => play(SoundEffect.mortgage);
  
  /// 播放拍卖音效
  static Future<void> playAuction() => play(SoundEffect.auction);
  
  /// 播放神仙降临音效（通用）
  static Future<void> playGodAppear() => play(SoundEffect.landGod);
  
  /// 播放天使音效
  static Future<void> playAngel() => play(SoundEffect.angel);
  
  /// 播放恶魔音效
  static Future<void> playDemon() => play(SoundEffect.demon);
  
  /// 播放财神音效
  static Future<void> playRichGod() => play(SoundEffect.richGod);
  
  /// 播放穷神音效
  static Future<void> playPoorGod() => play(SoundEffect.poorGod);
  
  /// 播放神明离开音效
  static Future<void> playGodLeave() => play(SoundEffect.godLeave);
  
  /// 播放使用卡片音效
  static Future<void> playUseCard() => play(SoundEffect.useCard);
  
  /// 播放传送音效
  static Future<void> playTeleport() => play(SoundEffect.teleport);
  
  /// 播放被撞音效
  static Future<void> playHitByCar() => play(SoundEffect.hitByCar);
  
  /// 播放地雷爆炸音效
  static Future<void> playMineExplode() => play(SoundEffect.mineExplode);
  
  /// 播放建筑摧毁音效
  static Future<void> playBuildingDestroy() => play(SoundEffect.buildingDestroy);
  
  /// 播放花费资金音效
  static Future<void> playSpendMoney() => play(SoundEffect.spendMoney);
  
  /// 播放股票分红音效
  static Future<void> playStockDividend() => play(SoundEffect.stockDividend);

  /// 释放音效服务资源
  /// 
  /// 在应用销毁时调用，释放音频播放器资源
  static Future<void> dispose() async {
    await _player.dispose();
    await _musicPlayer.dispose();
    debugPrint('SoundService disposed');
  }
}
