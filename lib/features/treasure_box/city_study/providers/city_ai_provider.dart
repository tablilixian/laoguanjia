import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/data/ai/ai_service.dart';
import 'package:home_manager/data/ai/ai_providers.dart';
import 'city_ai_prompts.dart';

final cityAiServiceProvider = Provider<CityAIService>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return CityAIService(aiService);
});

class CityAIService {
  final AIService _aiService;

  CityAIService(this._aiService);

  Future<String> generateGeography(String cityName, String province) async {
    final prompt = CityAIPrompts.geographyPrompt(cityName, province);
    return _callAI(prompt);
  }

  Future<String> generateHistory(String cityName, String province) async {
    final prompt = CityAIPrompts.historyPrompt(cityName, province);
    return _callAI(prompt);
  }

  Future<String> generateFigures(String cityName, String province) async {
    final prompt = CityAIPrompts.figuresPrompt(cityName, province);
    return _callAI(prompt);
  }

  Future<String> generateIndustry(String cityName, String province) async {
    final prompt = CityAIPrompts.industryPrompt(cityName, province);
    return _callAI(prompt);
  }

  Future<String> generateAll(String cityName, String province) async {
     final combinedPrompt = '''
 请为$province的 $cityName 写一份完整的城市精读报告。

请按以下四个部分组织内容：

## 一、地理区位
${CityAIPrompts.geographyPrompt(cityName, province)}

## 二、历史脉络
${CityAIPrompts.historyPrompt(cityName, province)}

## 三、人文名人
${CityAIPrompts.figuresPrompt(cityName, province)}

## 四、产业经济
${CityAIPrompts.industryPrompt(cityName, province)}

请在每个部分前用 "=== 标题 ===" 格式标注。''';
    return _callAI(combinedPrompt);
  }

  Future<String> _callAI(String prompt) async {
    try {
      return await _aiService.sendMessage(prompt, []);
    } catch (e) {
      throw Exception('AI 生成失败: $e');
    }
  }

  Stream<String> generateGeographyStream(
      String cityName, String province) {
    final prompt = CityAIPrompts.geographyPrompt(cityName, province);
    return _aiService.sendMessageStream(prompt, []);
  }

  Stream<String> generateHistoryStream(
      String cityName, String province) {
    final prompt = CityAIPrompts.historyPrompt(cityName, province);
    return _aiService.sendMessageStream(prompt, []);
  }

  Stream<String> generateFiguresStream(
      String cityName, String province) {
    final prompt = CityAIPrompts.figuresPrompt(cityName, province);
    return _aiService.sendMessageStream(prompt, []);
  }

  Stream<String> generateIndustryStream(
      String cityName, String province) {
    final prompt = CityAIPrompts.industryPrompt(cityName, province);
    return _aiService.sendMessageStream(prompt, []);
  }
}
