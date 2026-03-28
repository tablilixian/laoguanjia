import 'dart:typed_data';

/// 标签位图工具类
/// 
/// 使用位图来存储物品的标签关系，避免使用关系表
/// 支持64个标签（使用Int64类型）
/// 注意：在Web平台上使用BigInt来处理超过53位的位移
class TagsMaskHelper {
  TagsMaskHelper._();
  
  /// 使用BigInt进行位移操作（支持超过31位的位移）
  static int _shiftWithBigInt(int value, int shift) {
    // 使用Int64Bytes来创建大位移值
    final bytes = Uint8List(8);
    if (shift < 8) {
      bytes[7 - shift] = value;
    }
    // 从字节数组创建Int64
    final buffer = ByteData.view(bytes.buffer);
    return buffer.getInt64(0, Endian.little);
  }
  
  /// 添加标签
  static int addTag(int currentMask, int tagId) {
    if (tagId < 31) {
      return currentMask | (1 << tagId);
    } else {
      // 对于超过31位的位移，使用BigInt
      final shiftMask = BigInt.from(1) << tagId;
      return currentMask | shiftMask.toInt();
    }
  }
  
  /// 删除标签
  static int removeTag(int currentMask, int tagId) {
    if (tagId < 31) {
      return currentMask & ~(1 << tagId);
    } else {
      final shiftMask = BigInt.from(1) << tagId;
      return currentMask & ~shiftMask.toInt();
    }
  }
  
  /// 检查是否有标签
  static bool hasTag(int currentMask, int tagId) {
    if (tagId < 31) {
      return (currentMask & (1 << tagId)) != 0;
    } else {
      final shiftMask = BigInt.from(1) << tagId;
      return (BigInt.from(currentMask) & shiftMask) != BigInt.zero;
    }
  }
  
  /// 获取所有标签ID
  static List<int> getTagIds(int currentMask) {
    final tagIds = <int>[];
    for (int i = 0; i < 64; i++) {
      if (hasTag(currentMask, i)) {
        tagIds.add(i);
      }
    }
    return tagIds;
  }
  
  /// 从标签ID列表生成mask
  static int createMask(List<int> tagIds) {
    if (tagIds.isEmpty) return 0;
    
    // 检查是否有超过31位的标签
    final hasLargeIndex = tagIds.any((id) => id >= 31);
    
    if (!hasLargeIndex) {
      // 快速路径：所有标签都在31位以内
      int mask = 0;
      for (final tagId in tagIds) {
        mask |= (1 << tagId);
      }
      return mask;
    } else {
      // 使用BigInt处理大位移
      BigInt mask = BigInt.zero;
      for (final tagId in tagIds) {
        mask = mask | (BigInt.from(1) << tagId);
      }
      return mask.toInt();
    }
  }
  
  /// 检查是否有任何一个标签（OR查询）
  static bool hasAnyTag(int currentMask, List<int> tagIds) {
    for (final tagId in tagIds) {
      if (hasTag(currentMask, tagId)) {
        return true;
      }
    }
    return false;
  }
  
  /// 检查是否有所有标签（AND查询）
  static bool hasAllTags(int currentMask, List<int> tagIds) {
    for (final tagId in tagIds) {
      if (!hasTag(currentMask, tagId)) {
        return false;
      }
    }
    return true;
  }
  
  /// 更新标签mask（替换所有标签）
  static int updateMask(int currentMask, List<int> newTagIds) {
    return createMask(newTagIds);
  }
  
  /// 获取标签数量
  static int getTagCount(int currentMask) {
    return getTagIds(currentMask).length;
  }
  
  /// 检查mask是否为空
  static bool isEmpty(int currentMask) {
    return currentMask == 0;
  }
}