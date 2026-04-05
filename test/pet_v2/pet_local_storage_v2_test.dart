import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/data/models/pet_local_data.dart';

/// PetLocalStorageV2 logic tests (model-level).
///
/// These tests verify the data mutation logic that PetLocalStorageV2
/// orchestrates, without depending on platform channels (path_provider).
/// Integration tests for file I/O should run on device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetLocalStorageV2 logic (model-level)', () {
    test('empty creates valid initial structure', () {
      const petId = 'test-pet-001';
      final data = PetLocalData.empty(petId);

      expect(data.petId, petId);
      expect(data.version, '2.0');
      expect(data.state.hunger, 50);
      expect(data.interactions, isEmpty);
    });

    test('feed interaction updates state and adds record', () {
      var data = PetLocalData.empty('test-002');
      final now = DateTime.now();

      data = data.copyWith(
        state: data.state.applyInteraction('feed'),
        relationship: data.relationship.recordInteraction('feed'),
        interactions: [
          ...data.interactions,
          PetInteractionData(
            id: now.millisecondsSinceEpoch.toString(),
            type: 'feed',
            value: 20,
            createdAt: now,
          ),
        ],
      );

      expect(data.state.hunger, 70); // 50 + 20
      expect(data.state.happiness, 55); // 50 + 5
      expect(data.relationship.totalInteractions, 1);
      expect(data.relationship.feedCount, 1);
      expect(data.interactions.length, 1);
      expect(data.interactions.first.type, 'feed');
    });

    test('multiple interactions accumulate correctly', () {
      var data = PetLocalData.empty('test-003');

      data = data.copyWith(
        state: data.state.applyInteraction('feed'),
        relationship: data.relationship.recordInteraction('feed'),
        interactions: [
          ...data.interactions,
          PetInteractionData(id: '1', type: 'feed', value: 20, createdAt: DateTime.now()),
        ],
      );

      data = data.copyWith(
        state: data.state.applyInteraction('play'),
        relationship: data.relationship.recordInteraction('play'),
        interactions: [
          ...data.interactions,
          PetInteractionData(id: '2', type: 'play', value: 20, createdAt: DateTime.now()),
        ],
      );

      expect(data.state.hunger, 65); // 50 + 20 - 5
      expect(data.state.happiness, 75); // 50 + 5 + 20
      expect(data.relationship.totalInteractions, 2);
      expect(data.relationship.feedCount, 1);
      expect(data.relationship.playCount, 1);
      expect(data.interactions.length, 2);
    });

    test('conversation append and trim when over limit', () {
      var data = PetLocalData.empty('test-004');

      for (int i = 0; i < 205; i++) {
        final conversations = [
          ...data.conversations,
          PetConversationData(
            role: 'user',
            content: 'msg $i',
            createdAt: DateTime.now().add(Duration(seconds: i)),
          ),
        ];

        final trimmed = conversations.length > 200
            ? conversations.sublist(conversations.length - 100)
            : conversations;

        data = data.copyWith(conversations: trimmed);
      }

      expect(data.conversations.length, 104);
      expect(data.conversations.first.content, 'msg 101');
    });

    test('memory append preserves all fields', () {
      var data = PetLocalData.empty('test-005');
      final memory = PetMemoryData(
        id: 'mem-1',
        memoryType: 'interaction',
        title: '享用美食',
        description: '吃了美味的食物',
        emotion: 'joy',
        importance: 2,
        occurredAt: DateTime.now(),
      );

      data = data.copyWith(memories: [...data.memories, memory]);

      expect(data.memories.length, 1);
      expect(data.memories.first.title, '享用美食');
      expect(data.memories.first.importance, 2);
    });

    test('toJson/fromJson round-trip preserves all data', () {
      final original = PetLocalData(
        petId: 'test-006',
        month: '2026-04',
        generatedAt: DateTime(2026, 4, 5, 10, 0, 0),
        state: const PetState(
          hunger: 80,
          happiness: 90,
          cleanliness: 70,
          health: 100,
          level: 5,
          experience: 230,
          currentMood: 'happy',
          moodText: 'Feeling great!',
        ),
        personality: const PetPersonalityData(
          openness: 0.7,
          agreeableness: 0.8,
          speechStyle: '活泼',
          traits: ['好奇'],
        ),
        relationship: const PetRelationshipData(
          trustLevel: 65,
          intimacyLevel: 3,
          totalInteractions: 128,
          feedCount: 45,
          playCount: 50,
          chatCount: 33,
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
            findings: [
              {'location': '客厅', 'observation': '沙发上有衣服'},
            ],
            createdAt: DateTime(2026, 4, 4, 15, 0, 0),
          ),
        ],
      );

      final json = original.toJson();
      final restored = PetLocalData.fromJson(json);

      expect(restored.petId, original.petId);
      expect(restored.month, original.month);
      expect(restored.state.hunger, original.state.hunger);
      expect(restored.state.happiness, original.state.happiness);
      expect(restored.state.level, original.state.level);
      expect(restored.personality.openness, original.personality.openness);
      expect(restored.personality.traits, original.personality.traits);
      expect(restored.relationship.trustLevel, original.relationship.trustLevel);
      expect(restored.relationship.totalInteractions, original.relationship.totalInteractions);
      expect(restored.interactions.length, original.interactions.length);
      expect(restored.interactions.first.type, 'feed');
      expect(restored.memories.length, original.memories.length);
      expect(restored.memories.first.title, '享用美食');
      expect(restored.conversations.length, original.conversations.length);
      expect(restored.conversations.first.content, '你好');
      expect(restored.explorations.length, original.explorations.length);
      expect(restored.explorations.first.title, '客厅巡查');
      expect(restored.explorations.first.findings.length, 1);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'petId': 'test-007',
        'month': '2026-04',
        'state': {'hunger': 80},
        'personality': {},
        'relationship': {},
      };

      final data = PetLocalData.fromJson(json);

      expect(data.petId, 'test-007');
      expect(data.state.hunger, 80);
      expect(data.state.happiness, 50); // default
      expect(data.interactions, isEmpty);
      expect(data.memories, isEmpty);
    });
  });
}
