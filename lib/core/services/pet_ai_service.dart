import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/models/pet_personality.dart';
import 'package:home_manager/data/models/pet_memory.dart';
import 'package:home_manager/data/models/pet_skill.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';
import 'package:home_manager/core/services/personality_generator.dart';
import 'package:home_manager/core/services/skill_generator.dart';
import 'package:home_manager/core/services/prompt_builder.dart';

class PetAIService {
  final PetAIRepository _repository = PetAIRepository();

  Future<void> initializePetAI({
    required Pet pet,
    required String ownerId,
    PetSkill? userSelectedSkill,
  }) async {
    final personality = PersonalityGenerator.generate(
      petId: pet.id,
      petType: pet.type,
      name: pet.name,
      breed: pet.breed,
    );

    final createdPersonality = await _repository.createPersonality(personality);

    await _repository.updatePetPersonalityId(pet.id, createdPersonality.id);

    final skills = SkillGenerator.generateSkills(
      userSelectedSkill: userSelectedSkill,
      intimacyLevel: 0,
    );

    await _repository.updatePetSkills(pet.id, skills);

    await _repository.updatePetMood(pet.id, 'neutral', '刚来到新家，有点紧张');

    await _repository.createRelationship(pet.id);

    await _repository.createMemory(
      PetMemory(
        id: '',
        petId: pet.id,
        memoryType: 'milestone',
        title: '初遇',
        description: '我遇到了我的主人，这是我们故事的开始',
        emotion: 'joy',
        participants: ['主人', '我'],
        importance: 5,
        isSummarized: false,
        occurredAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<PetPersonality?> getPersonality(String petId) async {
    return await _repository.getPersonality(petId);
  }

  Future<List<PetMemory>> getMemories(String petId, {int? limit}) async {
    return await _repository.getMemories(petId, limit: limit);
  }

  Future<List<PetMemory>> getRelevantMemories(String petId) async {
    final important = await _repository.getImportantMemories(petId, limit: 2);
    final recent = await _repository.getRecentMemories(
      petId,
      days: 7,
      limit: 2,
    );

    final all = <PetMemory>{...important, ...recent}.toList();
    all.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return all.take(5).toList();
  }

  String buildMemoryContext(List<PetMemory> memories) {
    if (memories.isEmpty) return '';

    final buffer = StringBuffer();

    final sorted = memories
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    for (final memory in sorted) {
      buffer.writeln('- ${memory.title}: ${memory.description}');
    }

    return buffer.toString();
  }

  String buildSystemPrompt({
    required Pet pet,
    required PetPersonality personality,
    required List<PetSkill> skills,
    String? memoryContext,
  }) {
    return PromptBuilder.buildSystemPrompt(
      pet: pet,
      personality: personality,
      skills: skills,
      memoryContext: memoryContext,
    );
  }

  PetSkill? detectSkillFromMessage(String message) {
    return PetSkill.detectSkillFromMessage(message);
  }

  List<PetSkill> getAvailableSkillsForSelection(int intimacyLevel) {
    return SkillGenerator.getAvailableSkillsForSelection(intimacyLevel);
  }
}
