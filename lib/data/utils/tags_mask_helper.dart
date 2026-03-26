/// 标签位图工具类
/// 
/// 使用位图来存储物品的标签关系，避免使用关系表
/// 支持64个标签（使用Int64类型）
class TagsMaskHelper {
  TagsMaskHelper._();
  
  /// 添加标签
  static int addTag(int currentMask, int tagId) {
    return currentMask | (1 << tagId);
  }
  
  /// 删除标签
  static int removeTag(int currentMask, int tagId) {
    return currentMask & ~(1 << tagId);
  }
  
  /// 检查是否有标签
  static bool hasTag(int currentMask, int tagId) {
    return (currentMask & (1 << tagId)) != 0;
  }
  
  /// 获取所有标签ID
  static List<int> getTagIds(int currentMask) {
    final tagIds = <int>[];
    for (int i = 0; i < 64; i++) {
      if ((currentMask & (1 << i)) != 0) {
        tagIds.add(i);
      }
    }
    return tagIds;
  }
  
  /// 从标签ID列表生成mask
  static int createMask(List<int> tagIds) {
    int mask = 0;
    for (final tagId in tagIds) {
      mask |= (1 << tagId);
    }
    return mask;
  }
  
  /// 检查是否有任何一个标签（OR查询）
  static bool hasAnyTag(int currentMask, List<int> tagIds) {
    for (final tagId in tagIds) {
      if ((currentMask & (1 << tagId)) != 0) {
        return true;
      }
    }
    return false;
  }
  
  /// 检查是否有所有标签（AND查询）
  static bool hasAllTags(int currentMask, List<int> tagIds) {
    for (final tagId in tagIds) {
      if ((currentMask & (1 << tagId)) == 0) {
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
    int count = 0;
    for (int i = 0; i < 64; i++) {
      if ((currentMask & (1 << i)) != 0) {
        count++;
      }
    }
    return count;
  }
  
  /// 检查mask是否为空
  static bool isEmpty(int currentMask) {
    return currentMask == 0;
  }
}