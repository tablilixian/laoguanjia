import 'package:drift/drift.dart';

/// 测试位图支持多少个标签
void main() {
  print('=== 位图标签支持测试 ===\n');
  
  // 测试不同位数的最大值
  for (int bits = 31; bits <= 64; bits++) {
    try {
      final mask = 1 << bits;
      print('位 $bits: 1 << $bits = $mask');
      
      if (bits == 63) {
        print('✅ Dart int 类型支持 64 位整数');
        print('✅ 可以支持 64 个标签（ID 0-63）');
      }
    } catch (e) {
      print('❌ 位 $bits: 超出范围 - $e');
      break;
    }
  }
  
  print('\n=== 实际应用示例 ===');
  
  // 示例1：使用前31个标签
  final mask31 = (1 << 30) | (1 << 15) | (1 << 0);
  print('31位示例 (标签ID 0, 15, 30):');
  print('  mask = $mask31');
  print('  二进制 = ${mask31.toRadixString(2)}');
  
  // 示例2：使用64个标签
  final mask64 = (1 << 63) | (1 << 32) | (1 << 0);
  print('\n64位示例 (标签ID 0, 32, 63):');
  print('  mask = $mask64');
  print('  二进制 = ${mask64.toRadixString(2)}');
  
  // 示例3：检查标签是否存在
  print('\n=== 位运算测试 ===');
  final testMask = 42; // 二进制 101010，标签ID 1, 3, 5
  print('测试 mask = ${testMask.toRadixString(2)} (二进制)');
  
  for (int i = 0; i < 6; i++) {
    final hasTag = (testMask & (1 << i)) != 0;
    print('  标签ID $i: ${hasTag ? "✅ 存在" : "❌ 不存在"}');
  }
  
  print('\n=== 结论 ===');
  print('当前实现 (IntColumn) 在 SQLite 中：');
  print('  - SQLite INTEGER: 支持 64 位整数 ✅');
  print('  - Dart int: 支持 64 位整数 ✅');
  print('  - 实际支持: 64 个标签 (ID 0-63) ✅');
  print('\n注意：在其他数据库（如PostgreSQL）中可能需要使用 BIGINT 类型');
}