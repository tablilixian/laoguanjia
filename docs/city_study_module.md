# 城市精读模块文档

## 概述

城市精读是「老管家」百宝箱中的一个小工具，灵感来源于「上帝模拟器」爱好方法。用户可以通过精读中国县域城市的地理、历史、人文和产业，积累认知储备，完成 50 座城市的目标。

## 功能

- **省级地图**：显示中国省份轮廓，省颜色根据精读完成度渐变
- **县域点位**：2884 个县/区以圆点标记，颜色区分状态（灰=未开始/黄=进行中/绿=已完成）
- **分步引导**：地理区位 → 历史脉络 → 人文名人 → 产业经济，每步独立编辑
- **AI 辅助**：调用已有的 Gemini / 智谱AI 为每部分自动生成内容
- **进度追踪**：统计已完成/进行中数量，进度条可视化
- **随机选城**：一键随机选择一个县域开始精读
- **本地存储**：JSON 格式保存到应用文档目录
- **导入导出**：支持数据导出为 JSON 和从 JSON 导入（集成到系统导出功能）

## 目录结构

```
lib/features/treasure_box/city_study/
├── models/
│   └── city_study.dart              # 数据模型（County, Province, CityStudy 等）
├── data/
│   ├── china_divisions.dart         # 行政区划数据加载（省界+县区元数据）
│   ├── city_study_repository.dart   # JSON 文件读写（本地持久化）
│   └── city_study_export_source.dart # 数据导出源（集成 DataExportSource）
├── providers/
│   ├── city_study_provider.dart     # Riverpod 状态管理
│   ├── city_ai_provider.dart        # AI 服务封装
│   └── city_ai_prompts.dart         # AI 提示词模板
├── pages/
│   ├── city_study_home_page.dart    # 主页面（地图 + 统计 + 操作按钮）
│   ├── city_study_edit_page.dart    # 精读编辑页（分区编辑 + AI + 标签）
│   └── city_study_list_page.dart    # 精读列表页
└── widgets/
    ├── china_province_map.dart      # 省界地图 CustomPainter
    └── section_editor_card.dart     # 分区编辑器卡片
```

## 数据文件

### `assets/data/city_study/`

| 文件 | 大小 | 说明 |
|------|------|------|
| `province_boundary.json` | ~582KB | 省级 GeoJSON（DataV 数据源，35 个省/直辖市/自治区） |
| `provinces.json` | ~7KB | 省元数据（名称、代码、中心坐标） |
| `counties.json` | ~385KB | 县区元数据（2884 条，含代码、名称、中心坐标、所属省代码） |

数据来源：DataV 高德开放平台 + GeoMapData_CN

## 数据模型

### `CityStudy` 核心类

```dart
CityStudy {
  int adcode;              // 6位行政区划代码
  String name;             // 县/区名称
  String province;         // 所属省名称
  CityStudyStatus status;  // notStarted / inProgress / completed
  CityStudySections sections;  // 四个精读分区
  String notes;            // 自由笔记
  List<String> tags;       // 标签
  DateTime createdAt;      // 创建时间
  DateTime updatedAt;      // 更新时间
}
```

### `CityStudySections` 包含四个分区

| 字段 | 类型 | 标题 | AI 提示词 |
|------|------|------|-----------|
| `geography` | `CityStudySection` | 地理区位 | 地形、交通、资源、气候 |
| `history` | `CityStudySection` | 历史脉络 | 建城、变迁、兴衰 |
| `figures` | `CityStudySection` | 人文名人 | 名臣、文人、企业家 |
| `industry` | `CityStudySection` | 产业经济 | 支柱产业、龙头企业 |

## 存储方案

数据以 JSON 格式保存在 `{应用文档目录}/city_studies.json`。

```json
{
  "version": 1,
  "studies": [
    {
      "adcode": 340881,
      "name": "桐城市",
      "province": "安徽省",
      "status": 1,
      "sections": { ... },
      "notes": "",
      "tags": ["人文"],
      "createdAt": "2026-06-11T...",
      "updatedAt": "2026-06-11T..."
    }
  ]
}
```

## 地图绘制

使用 `CustomPainter` 绘制中国省界地图，无需额外地图 SDK。

- **坐标投影**：等距圆柱投影（Equirectangular），经度→X，纬度→Y
- **边界范围**：经度 73.66°~135.05°，纬度 3.86°~53.55°
- **省界绘制**：从 GeoJSON 解析 `Polygon`/`MultiPolygon` 坐标
- **县区标记**：根据中心坐标绘制圆点，颜色反映精读状态
- **点击检测**：射线法（Ray Casting）判定点是否在多边形内

## AI 集成

使用项目中已有的 `AIService`（支持 Gemini 和智谱AI）。

用户需先在「设置 → AI 设置」中配置 API Key。精读编辑页每部分下方有「AI 辅助生成」按钮，调用对应提示词生成内容。

## 扩展示例

### 添加新的标签

在 `city_study_edit_page.dart` 的 `_availableTags` 列表中添加：

```dart
static const List<String> _availableTags = [
  '人文', '产业', '推荐', '自然风光', '美食', '古建筑', '沿海', '山区', '平原', '边境',
  '你的新标签',
];
```

### 导出数据格式

可通过系统设置 → 数据导出 中「城市精读」选项导出。
