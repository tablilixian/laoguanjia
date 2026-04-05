import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/data/models/pet_local_data.dart';

void main() {
  group('PetState', () {
    test('initial state has default values', () {
      final state = PetState.initial();

      expect(state.hunger, 50);
      expect(state.happiness, 50);
      expect(state.cleanliness, 50);
      expect(state.health, 100);
      expect(state.level, 1);
      expect(state.experience, 0);
      expect(state.currentMood, 'neutral');
    });

    test('applyInteraction feed increases hunger and experience', () {
      final state = PetState.initial();
      final updated = state.applyInteraction('feed');

      expect(updated.hunger, 70); // 50 + 20
      expect(updated.happiness, 55); // 50 + 5
      expect(updated.experience, 5);
      expect(updated.level, 1); // not enough for level up
    });

    test('applyInteraction play increases happiness', () {
      final state = PetState.initial();
      final updated = state.applyInteraction('play');

      expect(updated.happiness, 70); // 50 + 20
      expect(updated.hunger, 45); // 50 - 5
      expect(updated.experience, 10);
    });

    test('applyInteraction bath increases cleanliness', () {
      final state = PetState.initial();
      final updated = state.applyInteraction('bath');

      expect(updated.cleanliness, 80); // 50 + 30
      expect(updated.happiness, 45); // 50 - 5
    });

    test('applyInteraction train increases experience most', () {
      final state = PetState.initial();
      final updated = state.applyInteraction('train');

      expect(updated.experience, 15);
      expect(updated.hunger, 40); // 50 - 10
      expect(updated.happiness, 60); // 50 + 10
    });

    test('values clamp to 0-100 range', () {
      final state = const PetState(hunger: 5, happiness: 5);
      final updated = state.applyInteraction('train');

      expect(updated.hunger, 0); // 5 - 10 = -5 → clamped to 0
      expect(updated.happiness, 15); // 5 + 10 = 15
    });

    test('level up when experience exceeds threshold', () {
      final state = const PetState(level: 1, experience: 95);
      final updated = state.applyInteraction('train'); // +15 exp

      expect(updated.experience, 10); // 95 + 15 = 110, 110 - 100 = 10
      expect(updated.level, 2);
    });

    test('unknown interaction type returns unchanged state', () {
      final state = PetState.initial();
      final updated = state.applyInteraction('unknown');

      expect(updated.hunger, state.hunger);
      expect(updated.happiness, state.happiness);
    });

    test('copyWith updates only specified fields', () {
      final state = PetState.initial();
      final updated = state.copyWith(hunger: 80, currentMood: 'happy');

      expect(updated.hunger, 80);
      expect(updated.currentMood, 'happy');
      expect(updated.happiness, 50); // unchanged
      expect(updated.level, 1); // unchanged
    });

    test('toJson and fromJson round-trip', () {
      final state = const PetState(
        hunger: 80,
        happiness: 90,
        cleanliness: 70,
        health: 100,
        level: 5,
        experience: 230,
        currentMood: 'happy',
        moodText: 'Feeling great!',
      );

      final json = state.toJson();
      final restored = PetState.fromJson(json);

      expect(restored.hunger, state.hunger);
      expect(restored.happiness, state.happiness);
      expect(restored.cleanliness, state.cleanliness);
      expect(restored.health, state.health);
      expect(restored.level, state.level);
      expect(restored.experience, state.experience);
      expect(restored.currentMood, state.currentMood);
      expect(restored.moodText, state.moodText);
    });
  });

  group('PetRelationshipData', () {
    test('initial relationship has zero values', () {
      final rel = PetRelationshipData.initial();

      expect(rel.trustLevel, 0);
      expect(rel.intimacyLevel, 0);
      expect(rel.totalInteractions, 0);
    });

    test('recordInteraction increments counters', () {
      final rel = PetRelationshipData.initial();
      final updated = rel.recordInteraction('feed');

      expect(updated.totalInteractions, 1);
      expect(updated.feedCount, 1);
      expect(updated.playCount, 0);
      expect(updated.chatCount, 0);
      expect(updated.lastInteractionAt, isNotNull);
      expect(updated.firstInteractionAt, isNotNull);
    });

    test('recordInteraction tracks different types', () {
      var rel = PetRelationshipData.initial();
      rel = rel.recordInteraction('feed');
      rel = rel.recordInteraction('play');
      rel = rel.recordInteraction('chat');

      expect(rel.totalInteractions, 3);
      expect(rel.feedCount, 1);
      expect(rel.playCount, 1);
      expect(rel.chatCount, 1);
    });

    test('intimacy level increases with interactions', () {
      var rel = PetRelationshipData.initial();

      // 10 interactions → Lv.2 (threshold is < 10 for Lv.1)
      for (int i = 0; i < 10; i++) {
        rel = rel.recordInteraction('feed');
      }
      expect(rel.intimacyLevel, 2);

      // 30 interactions → Lv.3 (threshold is < 30 for Lv.2)
      for (int i = 0; i < 20; i++) {
        rel = rel.recordInteraction('feed');
      }
      expect(rel.intimacyLevel, 3);
    });

    test('toJson and fromJson round-trip', () {
      final rel = const PetRelationshipData(
        trustLevel: 65,
        intimacyLevel: 3,
        totalInteractions: 128,
        feedCount: 45,
        playCount: 50,
        chatCount: 33,
        joyScore: 78.5,
        sadnessScore: 12.3,
      );

      final json = rel.toJson();
      final restored = PetRelationshipData.fromJson(json);

      expect(restored.trustLevel, rel.trustLevel);
      expect(restored.intimacyLevel, rel.intimacyLevel);
      expect(restored.totalInteractions, rel.totalInteractions);
      expect(restored.joyScore, rel.joyScore);
    });
  });

  group('PetPersonalityData', () {
    test('initial personality has default values', () {
      final p = PetPersonalityData.initial();

      expect(p.openness, 0.5);
      expect(p.agreeableness, 0.5);
      expect(p.extraversion, 0.5);
      expect(p.conscientiousness, 0.5);
      expect(p.neuroticism, 0.5);
      expect(p.speechStyle, 'normal');
      expect(p.traits, isEmpty);
    });

    test('toJson and fromJson round-trip', () {
      final p = const PetPersonalityData(
        openness: 0.7,
        agreeableness: 0.8,
        extraversion: 0.5,
        conscientiousness: 0.6,
        neuroticism: 0.3,
        traits: ['好奇', '粘人'],
        habits: ['喜欢在窗台晒太阳'],
        fears: ['打雷'],
        speechStyle: '活泼',
        originDescription: '一只小橘猫',
      );

      final json = p.toJson();
      final restored = PetPersonalityData.fromJson(json);

      expect(restored.openness, p.openness);
      expect(restored.traits, p.traits);
      expect(restored.speechStyle, p.speechStyle);
    });
  });

  group('PetLocalData', () {
    test('empty creates valid initial data', () {
      final data = PetLocalData.empty('test-pet-id');

      expect(data.petId, 'test-pet-id');
      expect(data.version, '2.0');
      expect(data.state.level, 1);
      expect(data.relationship.totalInteractions, 0);
      expect(data.interactions, isEmpty);
      expect(data.memories, isEmpty);
      expect(data.conversations, isEmpty);
    });

    test('toJson and fromJson round-trip', () {
      final data = PetLocalData(
        petId: 'test-123',
        month: '2026-04',
        generatedAt: DateTime(2026, 4, 5, 10, 0, 0),
        state: const PetState(
          hunger: 80,
          happiness: 90,
          level: 5,
          experience: 230,
          currentMood: 'happy',
        ),
        personality: const PetPersonalityData(
          openness: 0.7,
          speechStyle: '活泼',
        ),
        relationship: const PetRelationshipData(
          trustLevel: 65,
          intimacyLevel: 3,
          totalInteractions: 128,
        ),
        interactions: [
          PetInteractionData(
            id: '1',
            type: 'feed',
            value: 20,
            createdAt: DateTime(2026, 4, 5, 8, 0, 0),
          ),
        ],
        memories: [
          PetMemoryData(
            id: 'mem-1',
            memoryType: 'interaction',
            title: '享用美食',
            description: '吃了美味的食物',
            emotion: 'joy',
            importance: 2,
            occurredAt: DateTime(2026, 4, 5, 8, 0, 0),
          ),
        ],
        conversations: [
          PetConversationData(
            role: 'user',
            content: '你好',
            createdAt: DateTime(2026, 4, 5, 9, 0, 0),
          ),
        ],
        explorations: [
          PetExplorationData(
            id: 'exp-1',
            title: '客厅巡查',
            content: '一切正常',
            explorationType: 'patrol',
            durationMinutes: 5,
            moodAfter: 'satisfied',
            createdAt: DateTime(2026, 4, 4, 15, 0, 0),
          ),
        ],
      );

      final json = data.toJson();
      final restored = PetLocalData.fromJson(json);

      expect(restored.petId, data.petId);
      expect(restored.month, data.month);
      expect(restored.state.hunger, data.state.hunger);
      expect(restored.state.happiness, data.state.happiness);
      expect(restored.state.level, data.state.level);
      expect(restored.personality.openness, data.personality.openness);
      expect(restored.relationship.trustLevel, data.relationship.trustLevel);
      expect(restored.interactions.length, 1);
      expect(restored.interactions.first.type, 'feed');
      expect(restored.memories.length, 1);
      expect(restored.memories.first.title, '享用美食');
      expect(restored.conversations.length, 1);
      expect(restored.conversations.first.content, '你好');
      expect(restored.explorations.length, 1);
      expect(restored.explorations.first.title, '客厅巡查');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'petId': 'test-123',
        'month': '2026-04',
        'state': {'hunger': 80},
        'personality': {},
        'relationship': {},
      };

      final data = PetLocalData.fromJson(json);

      expect(data.petId, 'test-123');
      expect(data.state.hunger, 80);
      expect(data.state.happiness, 50); // default
      expect(data.interactions, isEmpty);
      expect(data.memories, isEmpty);
    });

    test('copyWith updates specified fields only', () {
      final data = PetLocalData.empty('test-123');
      final updated = data.copyWith(
        state: data.state.copyWith(hunger: 90),
        conversations: [
          PetConversationData(
            role: 'user',
            content: 'hello',
            createdAt: DateTime(2026, 4, 5),
          ),
        ],
      );

      expect(updated.state.hunger, 90);
      expect(updated.conversations.length, 1);
      expect(updated.petId, 'test-123'); // unchanged
      expect(updated.interactions, isEmpty); // unchanged
    });
  });

  group('PetSkillData', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'weather_sense',
        'name': '天气感知',
        'unlocked': true,
        'level': 1,
      };

      final skill = PetSkillData.fromJson(json);

      expect(skill.id, 'weather_sense');
      expect(skill.name, '天气感知');
      expect(skill.unlocked, true);
      expect(skill.level, 1);
    });

    test('toJson serializes correctly', () {
      const skill = PetSkillData(
        id: 'item_patrol',
        name: '物品巡检',
        unlocked: false,
        level: 0,
      );

      final json = skill.toJson();

      expect(json['id'], 'item_patrol');
      expect(json['unlocked'], false);
    });
  });
}
