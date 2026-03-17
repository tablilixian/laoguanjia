import 'dart:convert';
import 'package:home_manager/data/models/exploration_diary.dart';
import 'package:home_manager/data/supabase/supabase_client.dart';

class ExplorationRepository {
  final supabase = SupabaseClientManager.client;

  /// 保存探索日记
  Future<ExplorationDiary> saveDiary({
    required String petId,
    required String title,
    required String content,
    required List<ExplorationStop> stops,
    required String explorationType,
    String? moodAfter,
    required int intimacyLevelAtExplore,
    int durationMinutes = 60,
  }) async {
    try {
      final data = await supabase.from('pet_exploration_diaries').insert({
        'pet_id': petId,
        'title': title,
        'content': content,
        'stops': jsonEncode(stops.map((s) => s.toJson()).toList()),
        'exploration_type': explorationType,
        'mood_after': moodAfter,
        'intimacy_level_at_explore': intimacyLevelAtExplore,
        'duration_minutes': durationMinutes,
      }).select().single();

      return ExplorationDiary.fromJson(data);
    } catch (e) {
      throw Exception('Failed to save exploration diary: $e');
    }
  }

  /// 获取宠物的探索日记列表
  Future<List<ExplorationDiary>> getDiaries(String petId, {int limit = 10}) async {
    try {
      final data = await supabase
          .from('pet_exploration_diaries')
          .select()
          .eq('pet_id', petId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List).map((json) => ExplorationDiary.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get exploration diaries: $e');
    }
  }

  /// 获取单条日记详情
  Future<ExplorationDiary?> getDiaryById(String diaryId) async {
    try {
      final data = await supabase
          .from('pet_exploration_diaries')
          .select()
          .eq('id', diaryId)
          .single();

      return ExplorationDiary.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// 删除探索日记
  Future<void> deleteDiary(String diaryId) async {
    try {
      await supabase.from('pet_exploration_diaries').delete().eq('id', diaryId);
    } catch (e) {
      throw Exception('Failed to delete exploration diary: $e');
    }
  }

  /// 更新宠物的探索次数
  Future<void> updatePetExplorationStats(
    String petId, {
    required int hungerChange,
    required int happinessChange,
    String? moodAfter,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 先获取当前宠物状态
      final petData = await supabase
          .from('pets')
          .select()
          .eq('id', petId)
          .single();

      int currentHunger = petData['hunger'] ?? 0;
      int currentHappiness = petData['happiness'] ?? 0;
      int explorationCount = petData['exploration_count'] ?? 0;
      int todayCount = petData['today_exploration_count'] ?? 0;
      DateTime? lastExploredAt = petData['last_explored_at'] != null
          ? DateTime.parse(petData['last_explored_at'])
          : null;
      DateTime? lastDate = petData['last_exploration_date'] != null
          ? DateTime.parse(petData['last_exploration_date'])
          : null;

      // 检查是否需要重置今日次数
      bool needResetTodayCount = false;
      if (lastDate == null) {
        needResetTodayCount = true;
      } else if (lastDate.year != today.year ||
          lastDate.month != today.month ||
          lastDate.day != today.day) {
        needResetTodayCount = true;
      }

      // 计算新值
      int newHunger = (currentHunger + hungerChange).clamp(0, 100);
      int newHappiness = (currentHappiness + happinessChange).clamp(0, 100);

      await supabase.from('pets').update({
        'hunger': newHunger,
        'happiness': newHappiness,
        'exploration_count': explorationCount + 1,
        'today_exploration_count': needResetTodayCount ? 1 : todayCount + 1,
        'last_explored_at': now.toIso8601String(),
        'last_exploration_date': today.toIso8601String().split('T')[0],
        if (moodAfter != null) 'current_mood': moodAfter,
      }).eq('id', petId);
    } catch (e) {
      throw Exception('Failed to update pet exploration stats: $e');
    }
  }

  /// 检查宠物今日探索次数
  Future<int> getTodayExplorationCount(String petId) async {
    try {
      final petData = await supabase
          .from('pets')
          .select('today_exploration_count, last_exploration_date')
          .eq('id', petId)
          .single();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDate = petData['last_exploration_date'] != null
          ? DateTime.parse(petData['last_exploration_date'])
          : null;

      // 如果日期不同，重置为 0
      if (lastDate == null ||
          lastDate.year != today.year ||
          lastDate.month != today.month ||
          lastDate.day != today.day) {
        return 0;
      }

      return petData['today_exploration_count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
