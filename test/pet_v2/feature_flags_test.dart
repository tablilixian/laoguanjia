import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/core/config/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    test('useNewPetSystem defaults to false', () {
      // 默认关闭，确保不影响现有功能
      expect(FeatureFlags.useNewPetSystem, isFalse);
    });

    test('useNewPetSystem is a compile-time constant', () {
      // 确保是 const，支持 tree-shaking
      const value = FeatureFlags.useNewPetSystem;
      expect(value, isFalse);
    });
  });
}
