import 'dart:async';
import 'dart:convert';
import 'package:home_manager/data/models/exploration_diary.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/data/repositories/exploration_repository.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';
import 'package:home_manager/data/ai/ai_service.dart';
import 'package:home_manager/data/ai/ai_settings_service.dart';
import 'package:home_manager/data/ai/ai_models.dart';
import 'package:home_manager/core/services/exploration_prompt_builder.dart';

class ExplorationService {
  static final ExplorationService _instance = ExplorationService._internal();
  factory ExplorationService() => _instance;
  ExplorationService._internal();

  final ExplorationRepository _repository = ExplorationRepository();
  final PetAIRepository _aiRepository = PetAIRepository();
  final AIService _aiService = AIService(AISettingsService());

  // 探索配置
  static const int maxTodayExplorations = 3;
  static const int minHungerToExplore = 20;
  static const int minHappinessToExplore = 30;
  static const int hungerCostPerExploration = 15;
  static const int happinessGainPerExploration = 5;

  /// 检查是否可以探索
  Future<ExplorationCheckResult> checkCanExplore(Pet pet) async {
    // 检查饱食度
    if (pet.hunger < minHungerToExplore) {
      return ExplorationCheckResult.failure('太饿了，先吃点东西吧');
    }

    // 检查心情
    if (pet.happiness < minHappinessToExplore) {
      return ExplorationCheckResult.failure('心情不好，想在家里休息');
    }

    // 检查今日次数
    final todayCount = await _getTodayExplorationCount(pet.id);
    if (todayCount >= maxTodayExplorations) {
      return ExplorationCheckResult.failure('今天已经玩累了，明天再出去吧');
    }

    return ExplorationCheckResult.success(stats: {
      'todayExplorationCount': todayCount,
      'remainingExplorations': maxTodayExplorations - todayCount,
    });
  }

  /// 获取今日探索次数
  Future<int> _getTodayExplorationCount(String petId) async {
    return await _repository.getTodayExplorationCount(petId);
  }

  /// 生成探索日记（非流式）
  Future<ExplorationDiary> generateDiary({
    required Pet pet,
    required PetPersonality personality,
    String explorationType = 'normal',
  }) async {
    // 1. 检查是否可以探索
    final checkResult = await checkCanExplore(pet);
    if (!checkResult.canExplore) {
      throw Exception(checkResult.reason);
    }

    // 2. 构建 Prompt
    final skills = pet.skills.map((s) => PetSkillInfo(
      name: s.name,
      description: s.description,
      icon: s.icon,
    )).toList();

    final prompt = ExplorationPromptBuilder.build(
      petName: pet.name,
      petType: pet.type,
      level: pet.level,
      hunger: pet.hunger,
      happiness: pet.happiness,
      health: pet.health,
      traits: personality.traits,
      habits: personality.habits,
      fears: personality.fears,
      speechStyle: personality.speechStyle,
      skills: skills,
    );

    // 3. 调用 AI 生成
    final aiResponse = await _callAI(prompt);

    // 4. 解析响应
    final parsed = ExplorationPromptBuilder.parseAIResponse(aiResponse);

    // 5. 获取亲密度
    final relationship = await _aiRepository.getRelationship(pet.id);
    final intimacyLevel = relationship?.intimacyLevel ?? 0;

    // 6. 保存到数据库
    final diary = await _repository.saveDiary(
      petId: pet.id,
      title: parsed.title,
      content: parsed.content,
      stops: parsed.stops,
      explorationType: explorationType,
      moodAfter: parsed.moodAfter,
      intimacyLevelAtExplore: intimacyLevel,
    );

    // 7. 更新宠物状态
    await _repository.updatePetExplorationStats(
      pet.id,
      hungerChange: -hungerCostPerExploration,
      happinessChange: happinessGainPerExploration,
      moodAfter: parsed.moodAfter,
    );

    return diary;
  }

  /// 生成探索日记（流式）
  Stream<ExplorationStreamEvent> generateDiaryStream({
    required Pet pet,
    required PetPersonality personality,
    String explorationType = 'normal',
  }) async* {
    // 1. 检查是否可以探索
    final checkResult = await checkCanExplore(pet);
    if (!checkResult.canExplore) {
      yield ExplorationStreamEvent.error(checkResult.reason!);
      return;
    }

    // 2. 构建 Prompt
    final skills = pet.skills.map((s) => PetSkillInfo(
      name: s.name,
      description: s.description,
      icon: s.icon,
    )).toList();

    final prompt = ExplorationPromptBuilder.build(
      petName: pet.name,
      petType: pet.type,
      level: pet.level,
      hunger: pet.hunger,
      happiness: pet.happiness,
      health: pet.health,
      traits: personality.traits,
      habits: personality.habits,
      fears: personality.fears,
      speechStyle: personality.speechStyle,
      skills: skills,
    );

    yield ExplorationStreamEvent.started();

    // 3. 流式调用 AI
    String fullContent = '';
    try {
      await for (final chunk in _callAIStream(prompt)) {
        fullContent += chunk;
        yield ExplorationStreamEvent.contentUpdate(fullContent);
      }
    } catch (e) {
      yield ExplorationStreamEvent.error('AI 生成失败: $e');
      return;
    }

    // 4. 解析响应
    final parsed = ExplorationPromptBuilder.parseAIResponse(fullContent);

    if (!parsed.isValid) {
      // 如果解析失败，保存原始内容
      yield ExplorationStreamEvent.parsingFailed(parsed.content);
    }

    // 5. 获取亲密度
    final relationship = await _aiRepository.getRelationship(pet.id);
    final intimacyLevel = relationship?.intimacyLevel ?? 0;

    // 6. 保存到数据库
    final diary = await _repository.saveDiary(
      petId: pet.id,
      title: parsed.title,
      content: parsed.content,
      stops: parsed.stops,
      explorationType: explorationType,
      moodAfter: parsed.moodAfter,
      intimacyLevelAtExplore: intimacyLevel,
    );

    // 7. 更新宠物状态
    await _repository.updatePetExplorationStats(
      pet.id,
      hungerChange: -hungerCostPerExploration,
      happinessChange: happinessGainPerExploration,
      moodAfter: parsed.moodAfter,
    );

    yield ExplorationStreamEvent.completed(diary);
  }

  /// 获取宠物探索历史
  Future<List<ExplorationDiary>> getDiaries(String petId, {int limit = 10}) {
    return _repository.getDiaries(petId, limit: limit);
  }

  /// 获取单条日记详情
  Future<ExplorationDiary?> getDiaryById(String diaryId) {
    return _repository.getDiaryById(diaryId);
  }

  /// 删除日记
  Future<void> deleteDiary(String diaryId) {
    return _repository.deleteDiary(diaryId);
  }

  /// 调用 AI（非流式）
  Future<String> _callAI(String prompt) async {
    try {
      final response = await _aiService.sendMessage(prompt, []);
      return response;
    } catch (e) {
      throw Exception('AI 响应失败: $e');
    }
  }

  /// 调用 AI（流式）
  Stream<String> _callAIStream(String prompt) async* {
    try {
      await for (final chunk in _aiService.sendMessageStream(prompt, [])) {
        yield chunk;
      }
    } catch (e) {
      throw Exception('AI 响应失败: $e');
    }
  }
}

/// 流式事件
class ExplorationStreamEvent {
  final ExplorationStreamEventType type;
  final String? content;
  final ExplorationDiary? diary;
  final String? error;

  ExplorationStreamEvent._({
    required this.type,
    this.content,
    this.diary,
    this.error,
  });

  factory ExplorationStreamEvent.started() =>
      ExplorationStreamEvent._(type: ExplorationStreamEventType.started);

  factory ExplorationStreamEvent.contentUpdate(String content) =>
      ExplorationStreamEvent._(
        type: ExplorationStreamEventType.contentUpdate,
        content: content,
      );

  factory ExplorationStreamEvent.completed(ExplorationDiary diary) =>
      ExplorationStreamEvent._(
        type: ExplorationStreamEventType.completed,
        diary: diary,
      );

  factory ExplorationStreamEvent.error(String error) =>
      ExplorationStreamEvent._(
        type: ExplorationStreamEventType.error,
        error: error,
      );

  factory ExplorationStreamEvent.parsingFailed(String content) =>
      ExplorationStreamEvent._(
        type: ExplorationStreamEventType.parsingFailed,
        content: content,
      );
}

enum ExplorationStreamEventType {
  started,
  contentUpdate,
  completed,
  error,
  parsingFailed,
}
