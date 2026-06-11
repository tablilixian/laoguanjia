import 'dart:convert';

enum CityStudyStatus { notStarted, inProgress, completed }

class CityStudySection {
  String content;
  bool aiGenerated;

  CityStudySection({this.content = '', this.aiGenerated = false});

  Map<String, dynamic> toJson() => {
        'content': content,
        'aiGenerated': aiGenerated,
      };

  factory CityStudySection.fromJson(Map<String, dynamic> json) {
    return CityStudySection(
      content: json['content'] as String? ?? '',
      aiGenerated: json['aiGenerated'] as bool? ?? false,
    );
  }
}

class CityStudySections {
  CityStudySection geography;
  CityStudySection history;
  CityStudySection figures;
  CityStudySection industry;

  CityStudySections({
    CityStudySection? geography,
    CityStudySection? history,
    CityStudySection? figures,
    CityStudySection? industry,
  })  : geography = geography ?? CityStudySection(),
        history = history ?? CityStudySection(),
        figures = figures ?? CityStudySection(),
        industry = industry ?? CityStudySection();

  bool get hasAnyContent =>
      geography.content.isNotEmpty ||
      history.content.isNotEmpty ||
      figures.content.isNotEmpty ||
      industry.content.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'geography': geography.toJson(),
        'history': history.toJson(),
        'figures': figures.toJson(),
        'industry': industry.toJson(),
      };

  factory CityStudySections.fromJson(Map<String, dynamic> json) {
    return CityStudySections(
      geography: json['geography'] != null
          ? CityStudySection.fromJson(json['geography'])
          : null,
      history: json['history'] != null
          ? CityStudySection.fromJson(json['history'])
          : null,
      figures: json['figures'] != null
          ? CityStudySection.fromJson(json['figures'])
          : null,
      industry: json['industry'] != null
          ? CityStudySection.fromJson(json['industry'])
          : null,
    );
  }
}

class CountyInfo {
  final int adcode;
  final String name;
  final List<double> center;
  final List<double> centroid;
  final int provinceAdcode;

  const CountyInfo({
    required this.adcode,
    required this.name,
    required this.center,
    required this.centroid,
    required this.provinceAdcode,
  });

  factory CountyInfo.fromJson(Map<String, dynamic> json) {
    return CountyInfo(
      adcode: json['adcode'] as int,
      name: json['name'] as String,
      center: (json['center'] as List).cast<double>(),
      centroid: (json['centroid'] as List?)?.cast<double>() ??
          (json['center'] as List).cast<double>(),
      provinceAdcode: json['province_adcode'] as int,
    );
  }

  double get lng => center.isNotEmpty ? center[0] : 0;
  double get lat => center.isNotEmpty ? center[1] : 0;
}

class ProvinceInfo {
  final int adcode;
  final String name;
  final List<double> center;
  final List<int> children;

  const ProvinceInfo({
    required this.adcode,
    required this.name,
    required this.center,
    this.children = const [],
  });

  factory ProvinceInfo.fromJson(Map<String, dynamic> json) {
    return ProvinceInfo(
      adcode: json['adcode'] as int,
      name: json['name'] as String,
      center: (json['center'] as List).cast<double>(),
      children: (json['children'] as List?)?.cast<int>() ?? [],
    );
  }

  double get lng => center.isNotEmpty ? center[0] : 0;
  double get lat => center.isNotEmpty ? center[1] : 0;
}

class CityStudy {
  final int adcode;
  final String name;
  final String province;
  CityStudyStatus status;
  CityStudySections sections;
  String notes;
  List<String> tags;
  final DateTime createdAt;
  DateTime updatedAt;

  CityStudy({
    required this.adcode,
    required this.name,
    required this.province,
    this.status = CityStudyStatus.notStarted,
    CityStudySections? sections,
    this.notes = '',
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : sections = sections ?? CityStudySections(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'adcode': adcode,
        'name': name,
        'province': province,
        'status': status.index,
        'sections': sections.toJson(),
        'notes': notes,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CityStudy.fromJson(Map<String, dynamic> json) {
    return CityStudy(
      adcode: json['adcode'] as int,
      name: json['name'] as String,
      province: json['province'] as String? ?? '',
      status: CityStudyStatus.values[json['status'] as int? ?? 0],
      sections: json['sections'] != null
          ? CityStudySections.fromJson(json['sections'])
          : null,
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class CityStudyStore {
  final Map<int, CityStudy> studies;

  CityStudyStore({Map<int, CityStudy>? studies})
      : studies = studies ?? {};

  int get completedCount =>
      studies.values.where((s) => s.status == CityStudyStatus.completed).length;

  int get inProgressCount =>
      studies.values.where((s) => s.status == CityStudyStatus.inProgress).length;

  int get totalCount => studies.length;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'studies': studies.values
            .map((s) => s.toJson())
            .toList(),
      };

  factory CityStudyStore.fromJson(Map<String, dynamic> json) {
    final list = json['studies'] as List? ?? [];
    final map = <int, CityStudy>{};
    for (final item in list) {
      final study = CityStudy.fromJson(item as Map<String, dynamic>);
      map[study.adcode] = study;
    }
    return CityStudyStore(studies: map);
  }

  factory CityStudyStore.fromJsonString(String jsonString) {
    return CityStudyStore.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}
