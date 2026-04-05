/// 功能开关配置
///
/// 用于控制新旧宠物系统的切换，支持渐进式迁移 (Strangler Pattern)。
///
/// 使用方式:
/// ```dart
/// if (FeatureFlags.useNewPetSystem) {
///   return const PetV2HomePage(); // 新系统
/// }
/// return const PetHomePage();     // 旧系统
/// ```
class FeatureFlags {
  FeatureFlags._();

  /// 是否启用新宠物管家系统 (v2)
  ///
  /// - `false`: 使用旧系统 (Supabase 7 张表)
  /// - `true`: 使用新系统 (pets_meta + 本地 JSON)
  ///
  /// 迁移阶段:
  /// - Phase 1-4: 保持 false，新系统在独立分支开发
  /// - Phase 5 (灰度): 部分用户设为 true
  /// - Phase 5 (全量): 所有用户设为 true
  /// - Phase 6: 删除旧代码，移除此开关
  static const bool useNewPetSystem = false;
}
