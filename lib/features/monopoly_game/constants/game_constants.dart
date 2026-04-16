// 地产大亨 - 游戏常量配置
// 将硬编码的游戏数值抽取到配置文件中，便于调整和国际化
// 数值基于大富翁原版规则

class GameConstants {
  GameConstants._();

  // ==================== 核心游戏数值 ====================
  
  /// 玩家初始现金
  static const int startingCash = 1500;
  
  /// 经过起点奖励
  static const int passGoReward = 200;
  
  /// 个人所得税
  static const int incomeTax = 200;
  
  /// 消费税
  static const int luxuryTax = 100;
  
  /// 保释金金额
  static const int bailAmount = 50;
  
  /// 抵押赎回利息（百分比）
  static const double mortgageInterestRate = 0.1;
  
  /// 房屋出售价格比例（相对于购买价）
  static const double houseSellRatio = 0.5;

  // ==================== 监狱相关 ====================
  
  /// 监狱位置索引
  static const int jailIndex = 10;
  
  /// 最多在监狱停留的回合数
  static const int maxJailTurns = 3;
  
  /// 连续对子次数上限（超过则进监狱）
  static const int maxConsecutiveDoubles = 3;

  // ==================== 维修费用（卡牌效果） ====================
  
  /// 机会卡 - 房屋维修费用
  static const int chanceHouseRepair = 25;
  
  /// 机会卡 - 酒店维修费用
  static const int chanceHotelRepair = 100;
  
  /// 公益卡 - 房屋维修费用
  static const int communityChestHouseRepair = 40;
  
  /// 公益卡 - 酒店维修费用
  static const int communityChestHotelRepair = 115;

  // ==================== AI 相关 ====================
  
  /// 简单难度 - 购买地产概率 (0.0-1.0)
  static const double easyDifficultyBuyProb = 0.6;
  
  /// 简单难度 - 建造房屋概率 (0.0-1.0)
  static const double easyDifficultyBuildProb = 0.4;
  
  /// 简单难度 - 支付保释金概率 (0.0-1.0)
  static const double easyDifficultyBailProb = 0.5;
  
  /// 保守型 - 购买所需现金倍数（相对于价格）
  static const double conservativeBuyCashMultiplier = 1.5;
  
  /// 保守型 - 最低回报率要求
  static const double conservativeMinROI = 0.1;
  
  /// 激进型 - 建造所需现金倍数（相对于总费用）
  static const double aggressiveBuildCashMultiplier = 2.0;
  
  /// 保守型 - 建造所需现金倍数（相对于总费用）
  static const double conservativeBuildCashMultiplier = 3.0;
  
  /// 随机型 - 建造所需现金倍数（相对于总费用）
  static const double randomBuildCashMultiplier = 1.5;
  
  /// 简单难度 - 拍卖出价上限比例（相对于底价）
  static const double easyAuctionMaxBidRatio = 0.8;
  
  /// 困难难度 - 愿意出价倍数（相对于底价）
  static const double hardAuctionWillingBidMultiplier = 1.2;
  
  /// 拍卖最低加价幅度
  static const int auctionMinBidIncrement = 50;
  
  /// 完整色组地产价值倍数
  static const double completeSetValueMultiplier = 1.5;

  // ==================== 动画与延迟 ====================
  
  /// 骰子动画延迟 (毫秒)
  static const int diceAnimationDelay = 100;
  
  /// 简单难度 AI 决策延迟 (毫秒)
  static const int easyAIDelay = 1500;
  
  /// 困难难度 AI 决策延迟 (毫秒)
  static const int hardAIDelay = 500;
  
  /// AI 建造延迟 (毫秒)
  static const int aiBuildDelay = 1000;
  
  /// AI 购买延迟 (毫秒)
  static const int aiBuyDelay = 300;
  
  /// 玩家移动延迟 (毫秒)
  static const int playerMoveDelay = 500;
  
  /// 掷骰子延迟 (毫秒)
  static const int diceRollDelay = 800;

  // ==================== UI 相关 ====================
  
  /// 日志最大显示条数
  static const int logMaxEntries = 10;
  
  /// 玩家棋子大小比例（相对于格子大小）
  static const double tokenSizeRatio = 0.25;
  
  /// 玩家面板头像尺寸
  static const int playerAvatarSize = 40;
  
  /// 现金不足警告阈值
  static const int lowCashWarningThreshold = 100;
  
  /// 格子内边距
  static const double cellPadding = 10.0;
  
  /// 圆角半径
  static const double borderRadius = 10.0;

  // ==================== 棋盘相关 ====================
  
  /// 棋盘总格子数
  static const int boardCellCount = 40;
  
  /// 起点索引
  static const int goIndex = 0;
  
  /// 人民广场索引
  static const int freeParkingIndex = 20;
  
  /// 前往监狱索引
  static const int goToJailIndex = 30;
}
