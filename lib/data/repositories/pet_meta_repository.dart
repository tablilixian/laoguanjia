import 'package:home_manager/data/supabase/supabase_client.dart';
import 'package:home_manager/data/models/pet_meta.dart';

/// 宠物云端元数据仓库
///
/// 仅操作 pets_meta 表，负责身份关联和跨设备同步。
class PetMetaRepository {
  final supabase = SupabaseClientManager.client;

  /// 创建宠物元数据
  Future<PetMeta> createMeta(PetMeta meta) async {
    final data = await supabase
        .from('pets_meta')
        .insert(meta.toJson())
        .select()
        .single();
    return PetMeta.fromJson(data);
  }

  /// 获取家庭下所有宠物元数据
  Future<List<PetMeta>> getMetas(String householdId) async {
    final data = await supabase
        .from('pets_meta')
        .select()
        .eq('household_id', householdId);
    return (data as List).map((j) => PetMeta.fromJson(j)).toList();
  }

  /// 获取单个宠物元数据
  Future<PetMeta?> getMeta(String petId) async {
    final data = await supabase
        .from('pets_meta')
        .select()
        .eq('id', petId)
        .maybeSingle();
    if (data == null) return null;
    return PetMeta.fromJson(data);
  }

  /// 更新宠物元数据 (仅身份字段 + 可选状态快照)
  Future<PetMeta> updateMeta(PetMeta meta,
      {Map<String, dynamic>? snapshot}) async {
    final updateData = {
      'name': meta.name,
      'type': meta.type,
      if (meta.breed != null) 'breed': meta.breed,
      if (meta.avatarUrl != null) 'avatar_url': meta.avatarUrl,
      if (snapshot != null) 'state_snapshot': snapshot,
      'last_sync_at': DateTime.now().toIso8601String(),
    };
    final data = await supabase
        .from('pets_meta')
        .update(updateData)
        .eq('id', meta.id)
        .select()
        .single();
    return PetMeta.fromJson(data);
  }

  /// 删除宠物元数据
  Future<void> deleteMeta(String petId) async {
    await supabase.from('pets_meta').delete().eq('id', petId);
  }
}
