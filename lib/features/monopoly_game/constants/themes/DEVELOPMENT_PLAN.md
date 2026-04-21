# 地产大亨 - 棋盘主题化开发计划

## 📋 概述

本计划将当前硬编码的中国城市棋盘配置重构为可插拔的主题系统，支持玩家自主���择不同风格的游戏主题（如中国城市、国际城市等），同时保持游戏玩法不变，仅改变文案。

---

## ✅ 已完成（2026-04-21）

以下阶段已实现：

### Phase 1: 主题数据模型 ✅
- `board_theme.dart` - 完整的主题模型定义
  - `BoardThemeInfo` - 主题元信息
  - `ThemeCellConfig` - 地产格子配置
  - `ThemeSpecialCellConfig` - 特殊格子配置
  - `ThemeStationCellConfig` - 站点配置
  - `BoardTheme` - 完整主题（含 buildCells()）
  - `CardTemplate` - 卡牌模板（支持占位符）
  - `CardEffectTemplate` - 卡牌效果模板

### Phase 2: 基础配置 ✅
- `base_config.dart` - 游戏基础配置
  - 颜色组颜色值映射
  - 颜色组名称
  - 火车站租金表
  - 公用事业租金乘数
  - 特殊格子索引常量

### Phase 3: 卡牌模板 ✅
- `base_cards.dart` - 卡牌模板（支持占位符替换）
  - 命运卡模板（13张）
  - 公益卡模板（16张）
  - 占位符支持：`{{go}}`, `{{jail}}`, `{{railroad}}`, `{{utility}}`, `{{parkPlace}}`, `{{boardwalk}}`

### Phase 4: 中国城市主题 ✅
- `china_theme.dart` - 中国城市主题
  - 28个中国城市（拉萨、西宁、桂林...）
  - 4个高铁站（北京南站、虹桥站...）
  - 2个公用事业（国家电网、中国石化）
  - 10个特殊格子

### Phase 5: 国际城市主题 ✅
- `international_theme.dart` - 美国版主题
  - 28个美国城市（Mediterranean Avenue, Baltic Avenue...）
  - 4个火车站（Reading Railroad, Pennsylvania Railroad...）
  - 2个公用事业（Electric Company, Water Works）
  - 10个特殊格子（Go, Jail, Community Chest...）

### Phase 6: 主题Provider ✅
- `theme_provider.dart` - 主题状态管理
  - `availableThemesProvider` - 可用主题列表
  - `selectedThemeIdProvider` - 当前选择的主题ID
  - `currentThemeProvider` - 当前主题
  - `currentCellsProvider` - 当前Cell列表
  - `currentColorGroupMapProvider` - 颜色组映射
  - 持久化支持（SharedPreferences）

### Phase 7: 向后兼容 ✅
- `board_config.dart` - 已修改为兼容模式
  - 导出主题系统内容
  - `boardCells` getter 从 chinaTheme 获取
  - `chanceCards` / `communityChestCards` 保持中国城市版本

---

## 📂 当前目录结构

```
lib/features/monopoly_game/
├── constants/
│   ├── themes/                          # ✅ 已创建
│   │   ├── DEVELOPMENT_PLAN.md          # 本文档
│   │   ├── board_theme.dart          # 主题模型定义
│   │   ├── base_config.dart         # 基础配置
│   │   ├── base_cards.dart         # 卡牌模板
│   │   ├── theme_provider.dart     # 主题状态管理
│   │   ├── china_theme.dart        # 中国城市主题
│   │   └── international_theme.dart # 美国版主题
│   ├── board_config.dart            # ✅ 兼容模式
│   └── board_layout_config.dart    # 不变
├── providers/
│   └── game_provider.dart         # 暂未修改（兼容）
└── ...
```

---

## 🎯 待完成

### Phase 8: UI 支持（可选）
- 主题选择页面 `theme_selection_page.dart`
- 游戏设置页面集成主题选择

### Phase 9: 动态主题切换（可选）
- 修改 `game_provider.dart` 使用 `currentThemeProvider`
- 修改 `card_service.dart` 使用主题卡牌

### Phase 10: 持久化（已完成）
- 已有基础实现，需测试

---

## 🌍 主题列表

| ID | 名称 | 描述 | 状态 |
|----|------|------|------|
| `china_cities` | 中国城市 | 经典中国城市地图 | ✅ |
| `international` | 美国版 | Classic US Cities Map | ✅ |

---

## 🔧 使用方法

### 1. 获取当前主题
```dart
final theme = ref.read(currentThemeProvider);
final cells = theme.buildCells();
```

### 2. 获取当前主题的Cell��表
```dart
final cells = ref.read(currentCellsProvider);
```

### 3. 切换主题
```dart
ref.read(selectedThemeIdProvider.notifier).setTheme('international');
```

### 4. 获取主题列表（用于UI）
```dart
final themes = ref.watch(availableThemesProvider);
```

---

## ⚠️ 注意事项

1. **向后兼容**：现有代码无需修改即可工作，因为 `board_config.dart` 已改为从 chinaTheme 获取数据

2. **卡牌数据**：当前 `chanceCards` 和 `communityChestCards` 仍为中国城市版本，未来可通过主题 Provider 动态获取

3. **主题持久化**：使用 SharedPreferences，需要确保应用已初始化

---

## 📋 验收标准

| 标准 | 状态 |
|------|------|
| 主题数据模型完整 | ✅ |
| 中国城市主题可用 | ✅ |
| 国际城市主题可用 | ✅ |
| Provider 可用 | ✅ |
| 向后兼容 | ✅ |
| 代码无编译错误 | ✅ |

---

*文档版本: 1.1*
*更新日期: 2026-04-21*