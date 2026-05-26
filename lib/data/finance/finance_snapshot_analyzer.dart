import 'models/finance_snapshot.dart';

// ==================== 配置 ====================

/// 财务系统配置
class FinanceConfig {
  /// 主动收入判断阈值
  /// Δ净资产超过此值，弹窗询问是否包含主动收入
  static double activeIncomeThreshold = 100.0;
}

// ==================== 分析结果 ====================

/// 分析后应采取的动作
enum AnalysisAction {
  /// 首次快照，不计收入，静默保存
  none,

  /// 小额增长(<阈值)，自动归为被动收入，零打扰
  passiveIncome,

  /// 大额增长(≥阈值)，弹窗询问主动收入
  askActiveIncome,

  /// 净资产下降，算作支出，不弹窗
  expense,
}

/// 智能分析结果
class AnalysisResult {
  final AnalysisAction action;
  final double netWorthChange;
  final FinanceSnapshot? previousSnapshot;

  const AnalysisResult({
    required this.action,
    required this.netWorthChange,
    this.previousSnapshot,
  });

  bool get isAskActiveIncome => action == AnalysisAction.askActiveIncome;
  bool get isPassiveIncome => action == AnalysisAction.passiveIncome;
}

// ==================== 分析器 ====================

/// 智能预判分析器
///
/// 根据新旧快照的净资产变化，自动判断收入类型。
class FinanceSnapshotAnalyzer {
  /// 分析新快照，返回系统建议的动作
  static AnalysisResult analyze({
    required FinanceSnapshot newSnapshot,
    FinanceSnapshot? previousSnapshot,
  }) {
    // 首次快照：不计收入，只是起点
    if (previousSnapshot == null) {
      return AnalysisResult(
        action: AnalysisAction.none,
        netWorthChange: 0,
      );
    }

    final delta = newSnapshot.netWorth - previousSnapshot.netWorth;

    // 净资产下降：支出
    if (delta < 0) {
      return AnalysisResult(
        action: AnalysisAction.expense,
        netWorthChange: delta,
        previousSnapshot: previousSnapshot,
      );
    }

    // 小额增长：自动归为被动收入（零打扰）
    if (delta < FinanceConfig.activeIncomeThreshold) {
      return AnalysisResult(
        action: AnalysisAction.passiveIncome,
        netWorthChange: delta,
        previousSnapshot: previousSnapshot,
      );
    }

    // 大额增长：需要确认主动收入
    return AnalysisResult(
      action: AnalysisAction.askActiveIncome,
      netWorthChange: delta,
      previousSnapshot: previousSnapshot,
    );
  }
}
