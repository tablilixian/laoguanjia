import 'package:home_manager/data/repositories/pet_ai_repository.dart';
import 'package:home_manager/data/models/pet.dart';

class PetExportService {
  final PetAIRepository _repository = PetAIRepository();

  Future<String> exportPet(String petId) async {
    return await _repository.exportPet(petId);
  }

  Future<Pet> importPet(String jsonData) async {
    return await _repository.importPet(jsonData);
  }

  String getExportFileName(Pet pet) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'pet_${pet.name}_$timestamp.json';
  }
}
