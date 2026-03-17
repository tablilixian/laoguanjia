import 'dart:math';
import 'package:home_manager/data/models/pet_skill.dart';

class SkillGenerator {
  static final Random _random = Random();

  static List<PetSkill> generateSkills({
    PetSkill? userSelectedSkill,
    int intimacyLevel = 0,
  }) {
    final skills = <PetSkill>[];

    final availableSkills = PetSkill.getSkillsByIntimacy(intimacyLevel);

    if (userSelectedSkill != null) {
      skills.add(userSelectedSkill);
    }

    final otherSkills = availableSkills
        .where((s) => s.id != userSelectedSkill?.id)
        .toList();
    otherSkills.shuffle(_random);

    final hiddenSkill = otherSkills.firstWhere(
      (s) => !s.isVisible,
      orElse: () => otherSkills.first,
    );
    skills.add(hiddenSkill);

    if (skills.length < 3 && availableSkills.length > 2) {
      final thirdSkill = otherSkills.firstWhere(
        (s) => s.id != userSelectedSkill?.id && s.id != hiddenSkill.id,
        orElse: () => otherSkills[2],
      );
      skills.add(thirdSkill);
    }

    return skills;
  }

  static List<PetSkill> getAvailableSkillsForSelection(int intimacyLevel) {
    return PetSkill.allSkills
        .where((s) => s.isVisible && s.unlockIntimacy <= intimacyLevel)
        .toList();
  }

  static PetSkill? getSkillById(String id) {
    try {
      return PetSkill.allSkills.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<PetSkill> getUnlockedSkills(int intimacyLevel) {
    return PetSkill.getSkillsByIntimacy(intimacyLevel);
  }

  static List<PetSkill> getLockedSkills(int intimacyLevel) {
    return PetSkill.allSkills
        .where((s) => !s.isVisible && s.unlockIntimacy > intimacyLevel)
        .toList();
  }
}
