import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/data/models/pet_relationship.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';
import 'package:home_manager/data/ai/ai_service.dart';
import 'package:home_manager/data/ai/ai_models.dart';
import 'package:home_manager/data/ai/ai_settings_service.dart';

class PetChatResult {
  final String message;
  final PetSkill? detectedSkill;

  PetChatResult({required this.message, this.detectedSkill});
}

class PetChatStreamResult {
  final String delta;
  final String fullResponse;
  final PetSkill? detectedSkill;
  final bool isComplete;

  PetChatStreamResult({
    required this.delta,
    required this.fullResponse,
    this.detectedSkill,
    required this.isComplete,
  });
}

class PetChatService {
  final PetAIRepository _repository = PetAIRepository();
  final AIService _aiService = AIService(AISettingsService());

  Future<PetChatResult> sendMessage({
    required Pet pet,
    required String message,
    required List<ChatMessage> history,
    bool isOwner = false,
  }) async {
    final personality = await _repository.getPersonality(pet.id);
    final importantMemories = await _repository.getImportantMemories(
      pet.id,
      limit: 2,
    );
    final recentMemories = await _repository.getRecentMemories(
      pet.id,
      days: 7,
      limit: 3,
    );
    final allMemories = {...importantMemories, ...recentMemories}.toList();
    allMemories.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final memories = allMemories.take(5).toList();
    final relationship = await _repository.getRelationship(pet.id);

    final systemPrompt = _buildSystemPrompt(
      pet: pet,
      personality: personality,
      skills: pet.skills,
      memories: memories,
      relationship: relationship,
    );

    final historyForAI = history
        .map(
          (m) => ChatMessage(
            id: m.id,
            content: m.content,
            isUser: m.isUser,
            timestamp: m.timestamp,
          ),
        )
        .toList();

    String aiResponse;
    try {
      aiResponse = await _aiService.sendMessage(message, historyForAI);
    } catch (e) {
      throw Exception('AI 响应失败: $e');
    }

    if (isOwner) {
      await _onOwnerMessage(pet, message, aiResponse);
    }

    return PetChatResult(
      message: aiResponse,
      detectedSkill: _detectSkill(message),
    );
  }

  Stream<PetChatStreamResult> sendMessageStream({
    required Pet pet,
    required String message,
    required List<ChatMessage> history,
    bool isOwner = false,
  }) async* {
    final personality = await _repository.getPersonality(pet.id);
    final importantMemories = await _repository.getImportantMemories(
      pet.id,
      limit: 2,
    );
    final recentMemories = await _repository.getRecentMemories(
      pet.id,
      days: 7,
      limit: 3,
    );
    final allMemories = {...importantMemories, ...recentMemories}.toList();
    allMemories.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final memories = allMemories.take(5).toList();
    final relationship = await _repository.getRelationship(pet.id);

    final systemPrompt = _buildSystemPrompt(
      pet: pet,
      personality: personality,
      skills: pet.skills,
      memories: memories,
      relationship: relationship,
    );

    final historyForAI = history
        .map(
          (m) => ChatMessage(
            id: m.id,
            content: m.content,
            isUser: m.isUser,
            timestamp: m.timestamp,
          ),
        )
        .toList();

    String fullResponse = '';
    try {
      await for (final chunk in _aiService.sendMessageStream(
        message,
        historyForAI,
      )) {
        fullResponse += chunk;
        yield PetChatStreamResult(
          delta: chunk,
          fullResponse: fullResponse,
          detectedSkill: _detectSkill(message),
          isComplete: false,
        );
      }
    } catch (e) {
      throw Exception('AI 响应失败: $e');
    }

    if (isOwner && fullResponse.isNotEmpty) {
      await _onOwnerMessage(pet, message, fullResponse);
      await _repository.saveConversation(pet.id, 'user', message);
      await _repository.saveConversation(pet.id, 'assistant', fullResponse);
    }

    yield PetChatStreamResult(
      delta: '',
      fullResponse: fullResponse,
      detectedSkill: _detectSkill(message),
      isComplete: true,
    );
  }

  String _buildSystemPrompt({
    required Pet pet,
    PetPersonality? personality,
    required List<PetSkill> skills,
    required List<PetMemory> memories,
    PetRelationship? relationship,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('你是 ${pet.name}，一只${_getPetTypeText(pet.type)}。');

    if (personality != null) {
      buffer.writeln('\n## 性格特征');
      if (personality.traits.isNotEmpty) {
        buffer.writeln('具有${personality.traits.join("、")}的特点');
      }
      if (personality.habits.isNotEmpty) {
        buffer.writeln(personality.habits.join('，') + '。');
      }
      buffer.writeln('\n说话风格：${_getSpeechStyleDesc(personality.speechStyle)}');
    }

    if (skills.isNotEmpty) {
      buffer.writeln('\n## 技能领域');
      for (final skill in skills) {
        buffer.writeln('- ${skill.icon} ${skill.name}：${skill.description}');
      }
    }

    buffer.writeln('\n## 当前状态');
    buffer.writeln('- 饥饿度：${pet.hunger}%');
    buffer.writeln('- 心情值：${pet.happiness}%');
    buffer.writeln('- 清洁度：${pet.cleanliness}%');
    buffer.writeln('- 健康度：${pet.health}%');
    if (pet.currentMood != null) {
      buffer.writeln('- 当前心情：${pet.currentMood}');
    }

    if (memories.isNotEmpty) {
      buffer.writeln('\n## 我们的共同回忆');
      final sorted = memories.toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      for (final memory in sorted.take(5)) {
        buffer.writeln('- ${memory.title}: ${memory.description}');
      }
    }

    if (relationship != null) {
      buffer.writeln('\n## 关系');
      buffer.writeln('- 亲密度阶段：${relationship.intimacyStageName}');
      buffer.writeln('- 信任度：${relationship.trustLevel}');
    }

    buffer.writeln('\n## 行为规则');
    buffer.writeln('1. 始终保持上述性格特征，用符合性格的方式回应');
    buffer.writeln('2. 根据当前心情调整回复的语气');
    buffer.writeln('3. 适当提及你的技能和习惯');
    buffer.writeln('4. 如果心情不好，要表现出来');
    buffer.writeln('5. 不要总是说同样的话，要有不同的表达');
    buffer.writeln('6. 当用户提到你技能相关的关键词时，要展现你的专业知识');

    return buffer.toString();
  }

  String _getPetTypeText(String type) {
    switch (type) {
      case 'cat':
        return '小猫';
      case 'dog':
        return '小狗';
      case 'rabbit':
        return '小兔子';
      case 'hamster':
        return '小仓鼠';
      case 'guinea_pig':
        return '小豚鼠';
      case 'chinchilla':
        return '小龙猫';
      case 'bird':
        return '小鸟';
      case 'parrot':
        return '小鹦鹉';
      case 'fish':
        return '小鱼';
      case 'turtle':
        return '小乌龟';
      case 'lizard':
        return '小蜥蜴';
      case 'hedgehog':
        return '小刺猬';
      case 'ferret':
        return '小雪貂';
      case 'pig':
        return '小猪猪';
      default:
        return '小宠物';
    }
  }

  String _getSpeechStyleDesc(String style) {
    switch (style) {
      case 'cute':
        return '萌萌的，使用叠词，适当撒娇';
      case 'cool':
        return '酷酷的，简洁有力';
      case 'cheerful':
        return '活泼开朗，话多';
      case 'shy':
        return '害羞轻声，不太主动';
      default:
        return '正常自然';
    }
  }

  PetSkill? _detectSkill(String message) {
    return PetSkill.detectSkillFromMessage(message);
  }

  Future<void> _onOwnerMessage(
    Pet pet,
    String userMessage,
    String aiMessage,
  ) async {
    final skill = _detectSkill(userMessage);

    if (skill != null) {
      await _repository.createMemory(
        PetMemory(
          id: '',
          petId: pet.id,
          memoryType: 'conversation',
          title: '讨论了${skill.name}相关话题',
          description: '主人问我关于${skill.name}的问题，我给出了回答',
          emotion: 'neutral',
          participants: ['主人', '我'],
          importance: 2,
          isSummarized: false,
          occurredAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}
