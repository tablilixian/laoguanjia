class CityAIPrompts {
  static String geographyPrompt(String cityName, String province) {
    return '''请分析 $cityName（$province）的地理区位特征。
请从以下角度分析：
1. 地形地貌（山地/平原/沿海/盆地等）
2. 交通区位（是否紧邻高速、铁路、江河港口、机场等）
3. 自然资源（矿产、水利、森林等）
4. 气候特征
5. 地理区位对城市发展的影响

请用300-500字左右的中文回答，语言简洁、有洞察力。''';
  }

  static String historyPrompt(String cityName, String province) {
    return '''请梳理 $cityName（$province）的历史脉络。
请从以下角度分析：
1. 建城年代与历史沿革
2. 重要历史事件（迁徙、战乱、区划调整等）
3. 历史上为何兴盛，又为何沉寂
4. 历史对今天城市的影响

请用300-500字左右的中文回答，语言简洁、有洞察力。''';
  }

  static String figuresPrompt(String cityName, String province) {
    return '''请介绍 $cityName（$province）走出的名人名士。
请包括：
1. 历史名人（名臣、文人、思想家等）
2. 近现代名人（企业家、科学家、艺术家等）
3. 这些人物的成就和格局
4. 地域文化对人物性格和成就的影响

请用300-500字左右的中文回答，语言简洁、有洞察力。''';
  }

  static String industryPrompt(String cityName, String province) {
    return '''请分析 $cityName（$province）的产业经济特征。
请从以下角度分析：
1. 支柱产业是什么？
2. 有哪些本土龙头或隐形冠军企业？
3. 企业发展历程和商业模式
4. 产业如何撑起地方经济、带动就业

请用300-500字左右的中文回答，语言简洁、有洞察力。''';
  }
}

class CityAISectionInfo {
  final String key;
  final String title;
  final String icon;
  final String hint;

  const CityAISectionInfo({
    required this.key,
    required this.title,
    required this.icon,
    required this.hint,
  });

  static const List<CityAISectionInfo> sections = [
    CityAISectionInfo(
      key: 'geography',
      title: '地理区位',
      icon: '📍',
      hint: '地形、交通、自然资源…',
    ),
    CityAISectionInfo(
      key: 'history',
      title: '历史脉络',
      icon: '📜',
      hint: '建城、变迁、兴衰…',
    ),
    CityAISectionInfo(
      key: 'figures',
      title: '人文名人',
      icon: '👤',
      hint: '名臣、文人、企业家…',
    ),
    CityAISectionInfo(
      key: 'industry',
      title: '产业经济',
      icon: '🏭',
      hint: '支柱产业、龙头企业…',
    ),
  ];
}
