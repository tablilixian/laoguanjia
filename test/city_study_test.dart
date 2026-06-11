import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/features/treasure_box/city_study/models/city_study.dart';

void main() {
  group('CityStudySection', () {
    test('should create with default values', () {
      final section = CityStudySection();
      expect(section.content, '');
      expect(section.aiGenerated, false);
    });

    test('should serialize to JSON', () {
      final section = CityStudySection(
        content: '测试内容',
        aiGenerated: true,
      );
      final json = section.toJson();
      expect(json['content'], '测试内容');
      expect(json['aiGenerated'], true);
    });

    test('should deserialize from JSON', () {
      final json = {'content': '测试内容', 'aiGenerated': true};
      final section = CityStudySection.fromJson(json);
      expect(section.content, '测试内容');
      expect(section.aiGenerated, true);
    });

    test('should handle empty JSON', () {
      final section = CityStudySection.fromJson({});
      expect(section.content, '');
      expect(section.aiGenerated, false);
    });
  });

  group('CityStudySections', () {
    test('should create with default sections', () {
      final sections = CityStudySections();
      expect(sections.geography.content, '');
      expect(sections.history.content, '');
      expect(sections.figures.content, '');
      expect(sections.industry.content, '');
    });

    test('hasAnyContent should return false when empty', () {
      final sections = CityStudySections();
      expect(sections.hasAnyContent, false);
    });

    test('hasAnyContent should return true when geography has content', () {
      final sections = CityStudySections(
        geography: CityStudySection(content: '地理内容'),
      );
      expect(sections.hasAnyContent, true);
    });

    test('should serialize and deserialize correctly', () {
      final original = CityStudySections(
        geography: CityStudySection(content: '地理', aiGenerated: true),
        history: CityStudySection(content: '历史', aiGenerated: false),
        figures: CityStudySection(content: '人物'),
        industry: CityStudySection(content: '产业', aiGenerated: true),
      );
      final json = original.toJson();
      final restored = CityStudySections.fromJson(json);
      expect(restored.geography.content, '地理');
      expect(restored.geography.aiGenerated, true);
      expect(restored.history.content, '历史');
      expect(restored.figures.content, '人物');
      expect(restored.industry.content, '产业');
      expect(restored.industry.aiGenerated, true);
    });
  });

  group('CityStudy', () {
    test('should create with default values', () {
      final study = CityStudy(
        adcode: 340881,
        name: '桐城市',
        province: '安徽省',
      );
      expect(study.adcode, 340881);
      expect(study.name, '桐城市');
      expect(study.province, '安徽省');
      expect(study.status, CityStudyStatus.notStarted);
      expect(study.sections.hasAnyContent, false);
      expect(study.notes, '');
      expect(study.tags, []);
    });

    test('should serialize and deserialize correctly', () {
      final original = CityStudy(
        adcode: 340881,
        name: '桐城市',
        province: '安徽省',
        status: CityStudyStatus.inProgress,
        sections: CityStudySections(
          geography: CityStudySection(content: '依山傍水'),
        ),
        notes: '好地方',
        tags: ['人文', '产业'],
      );
      final json = original.toJson();
      final restored = CityStudy.fromJson(json);
      expect(restored.adcode, 340881);
      expect(restored.name, '桐城市');
      expect(restored.province, '安徽省');
      expect(restored.status, CityStudyStatus.inProgress);
      expect(restored.sections.geography.content, '依山傍水');
      expect(restored.notes, '好地方');
      expect(restored.tags, ['人文', '产业']);
    });

    test('should update updatedAt on changes', () {
      final study = CityStudy(adcode: 340881, name: '桐城市', province: '安徽省');
      final oldUpdatedAt = study.updatedAt;
      study.updatedAt = DateTime.now();
      expect(study.updatedAt.isAfter(oldUpdatedAt), isTrue);
    });
  });

  group('CityStudyStore', () {
    test('should create empty store', () {
      final store = CityStudyStore();
      expect(store.studies, {});
      expect(store.completedCount, 0);
      expect(store.inProgressCount, 0);
      expect(store.totalCount, 0);
    });

    test('should calculate statistics correctly', () {
      final store = CityStudyStore(studies: {
        340881: CityStudy(
          adcode: 340881,
          name: '桐城市',
          province: '安徽省',
          status: CityStudyStatus.completed,
        ),
        330182: CityStudy(
          adcode: 330182,
          name: '建德市',
          province: '浙江省',
          status: CityStudyStatus.inProgress,
        ),
        110101: CityStudy(
          adcode: 110101,
          name: '东城区',
          province: '北京市',
          status: CityStudyStatus.notStarted,
        ),
      });
      expect(store.completedCount, 1);
      expect(store.inProgressCount, 1);
      expect(store.totalCount, 3);
    });

    test('should serialize and deserialize JSON', () {
      final store = CityStudyStore(studies: {
        340881: CityStudy(
          adcode: 340881,
          name: '桐城市',
          province: '安徽省',
          status: CityStudyStatus.completed,
          sections: CityStudySections(
            geography: CityStudySection(content: '地理内容', aiGenerated: true),
          ),
          tags: ['人文'],
        ),
      });
      final jsonStr = store.toJsonString();
      final restored = CityStudyStore.fromJsonString(jsonStr);
      expect(restored.totalCount, 1);
      final study = restored.studies[340881]!;
      expect(study.name, '桐城市');
      expect(study.province, '安徽省');
      expect(study.status, CityStudyStatus.completed);
      expect(study.sections.geography.content, '地理内容');
      expect(study.sections.geography.aiGenerated, true);
      expect(study.tags, ['人文']);
    });

    test('should handle empty JSON string', () {
      final store = CityStudyStore.fromJsonString('{"version":1,"studies":[]}');
      expect(store.totalCount, 0);
    });

    test('toJsonString should produce valid JSON', () {
      final store = CityStudyStore(studies: {
        340881: CityStudy(
          adcode: 340881,
          name: '桐城市',
          province: '安徽省',
        ),
      });
      final jsonStr = store.toJsonString();
      expect(jsonStr, contains('340881'));
      expect(jsonStr, contains('桐城市'));
      expect(jsonStr, contains('安徽省'));
    });
  });
}
