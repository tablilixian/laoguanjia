# Home Manager 离线同步开发指南

> **版本**: v1.0  
> **日期**: 2026-03-21  
> **状态**: 草案  
> **作者**: Sisyphus AI Agent

---

## 目录

1. [项目概述](#1-项目概述)
2. [架构设计](#2-架构设计)
3. [技术选型](#3-技术选型)
4. [数据库设计](#4-数据库设计)
5. [同步引擎设计](#5-同步引擎设计)
6. [实现步骤](#6-实现步骤)
7. [API 接口规范](#7-api-接口规范)
8. [测试策略](#8-测试策略)
9. [部署与运维](#9-部署与运维)
10. [风险与应对](#10-风险与应对)
11. [附录](#11-附录)

---

## 1. 项目概述

### 1.1 背景

Home Manager 是一款基于 Flutter + Supabase 的家庭管理应用，当前所有数据操作直接请求云端数据库。随着用户量增长，面临以下问题：

- **服务器负载高**：每次查询都经过云端
- **离线不可用**：无网络时无法使用
- **响应延迟**：网络波动影响用户体验

### 1.2 目标

实现本地与云端数据同步，达成：

| 目标 | 指标 |
|------|------|
| 降低服务器负载 | 查询请求减少 90%+ |
| 离线可用 | 100% 核心功能离线可用 |
| 响应速度 | 本地查询 < 50ms |
| 数据一致性 | 最终一致，冲突率 < 1% |

### 1.3 核心方案

```
本地 SQLite (Drift) ←→ 同步引擎 ←→ Supabase PostgreSQL
```

- **本地优先**：所有读写操作先走本地数据库
- **增量同步**：基于版本号，只同步变更数据
- **冲突处理**：最后写入获胜（LWW）
- **分模块同步**：各业务模块独立同步，互不影响

---

## 2. 架构设计

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     UI Layer                             │   │
│  │   TasksPage │ ItemsPage │ PetsPage │ ...                │   │
│  └────────────────────────┬────────────────────────────────┘   │
│                           │                                     │
│  ┌────────────────────────▼────────────────────────────────┐   │
│  │                 Riverpod Providers                      │   │
│  │   tasksProvider │ itemsProvider │ petsProvider          │   │
│  └────────────────────────┬────────────────────────────────┘   │
│                           │                                     │
│  ┌────────────────────────▼────────────────────────────────┐   │
│  │              Unified Repository Layer                    │   │
│  │   - 优先读本地 SQLite                                    │   │
│  │   - 写操作：本地 + 标记待同步                            │   │
│  │   - 暴露 Stream 响应式更新                               │   │
│  └──────────┬────────────────────────────┬─────────────────┘   │
│             │                            │                     │
│  ┌──────────▼──────────┐    ┌────────────▼────────────────┐   │
│  │   Local Database    │    │      Sync Engine            │   │
│  │   (Drift + SQLite)  │◄──►│  - 版本检查                 │   │
│  │   - 数据存储        │    │  - 增量拉取                 │   │
│  │   - CRUD 操作       │    │  - 变更推送                 │   │
│  │   - 响应式查询      │    │  - 冲突解决                 │   │
│  └─────────────────────┘    └────────────┬────────────────┘   │
│                                          │                     │
├──────────────────────────────────────────┼─────────────────────┤
│                                          │                     │
│                           ┌──────────────▼────────────────┐   │
│                           │        Supabase Cloud         │   │
│                           │   - PostgreSQL                │   │
│                           │   - Auth                      │   │
│                           │   - Storage                   │   │
│                           └───────────────────────────────┘   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 2.2 模块职责

| 模块 | 职责 | 关键技术 |
|------|------|----------|
| UI Layer | 展示数据，响应用户操作 | Flutter Widgets |
| Providers | 状态管理，业务逻辑 | Riverpod |
| Repository | 统一数据访问入口 | Dart |
| Local Database | 本地数据存储 | Drift + SQLite |
| Sync Engine | 数据同步核心 | Dart + Supabase SDK |
| Supabase Cloud | 云端数据存储 | PostgreSQL |

### 2.3 数据流

**读取流程**：
```
UI → Provider → Repository → Local DB → 返回数据 → UI 更新
```

**写入流程**：
```
UI → Provider → Repository → Local DB (写入 + 标记待同步)
                                    ↓
                           返回成功 → UI 更新
                                    ↓
                           后台 Sync Engine → Supabase (推送)
```

**同步流程**：
```
定时触发 → Sync Engine → 检查版本号 → 增量拉取 → 更新 Local DB
                                    ↓
                           推送待同步数据 → 更新同步状态
```

---

## 3. 技术选型

### 3.1 核心依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| drift | ^2.x | 本地 SQLite ORM |
| sqlite3_flutter_libs | ^0.5.x | SQLite 原生库 |
| supabase_flutter | ^2.5.0 | 云端通信（已有） |
| flutter_riverpod | ^2.5.1 | 状态管理（已有） |

### 3.2 选型理由

**为什么选 Drift？**

| 对比项 | sqflite | drift | isar |
|--------|---------|-------|------|
| 类型安全 | ❌ | ✅ | ✅ |
| 自动迁移 | ❌ | ✅ | ⚠️ |
| 响应式查询 | ❌ | ✅ | ✅ |
| SQL 支持 | 手写 | 自动生成 | NoSQL |
| 生态成熟度 | 高 | 高 | 中 |

Drift 提供最佳的类型安全和自动迁移支持，适合需要与 PostgreSQL 同步的场景。

---

## 4. 数据库设计

### 4.1 云端改造（Supabase）

#### 4.1.1 表结构变更

为每张业务表添加版本控制字段：

```sql
-- 任务表
ALTER TABLE tasks 
  ADD COLUMN version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 物品表
ALTER TABLE household_items
  ADD COLUMN version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 宠物表
ALTER TABLE pets
  ADD COLUMN version BIGINT NOT NULL DEFAULT 1,
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 其他表依此类推...
```

#### 4.1.2 同步版本追踪表

```sql
CREATE TABLE sync_versions (
  table_name TEXT PRIMARY KEY,
  max_version BIGINT NOT NULL DEFAULT 0,
  row_count BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 初始化每张表的版本记录
INSERT INTO sync_versions (table_name) VALUES
  ('tasks'),
  ('household_items'),
  ('item_locations'),
  ('pets'),
  ('members');
```

#### 4.1.3 自动更新触发器

```sql
-- 通用版本更新函数
CREATE OR REPLACE FUNCTION increment_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = COALESCE(OLD.version, 0) + 1;
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为每张表创建触发器
CREATE TRIGGER tasks_version_trigger
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION increment_version();

CREATE TRIGGER household_items_version_trigger
  BEFORE UPDATE ON household_items
  FOR EACH ROW EXECUTE FUNCTION increment_version();

-- 其他表依此类推...
```

#### 4.1.4 版本同步函数

```sql
-- 更新 sync_versions 表的函数
CREATE OR REPLACE FUNCTION update_sync_version()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE sync_versions 
  SET 
    max_version = NEW.version,
    row_count = (SELECT COUNT(*) FROM tasks), -- 动态计算
    updated_at = NOW()
  WHERE table_name = TG_TABLE_NAME;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为每张表创建触发器
CREATE TRIGGER tasks_sync_version_trigger
  AFTER INSERT OR UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_sync_version();
```

### 4.2 本地数据库（Drift）

#### 4.2.1 表定义

```dart
// lib/data/local_db/tables/tasks.dart

import 'package:drift/drift.dart';

class Tasks extends Table {
  // 主键
  TextColumn get id => text()();
  
  // 业务字段
  TextColumn get householdId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get assignedTo => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get recurrence => text()();
  TextColumn get status => text()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  
  // 同步字段
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}
```

#### 4.2.2 数据库定义

```dart
// lib/data/local_db/app_database.dart

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'tables/tasks.dart';
import 'tables/household_items.dart';
import 'tables/pets.dart';
// ... 其他表导入

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Tasks,
  HouseholdItems,
  Pets,
  // ... 其他表
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // 版本迁移逻辑
      if (from < 2) {
        // v1 -> v2 迁移
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'home_manager.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

### 4.3 Schema 版本管理

#### 4.3.1 云端 Schema 版本表

```sql
CREATE TABLE schema_versions (
  version INTEGER PRIMARY KEY,
  description TEXT,
  migration_sql TEXT,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- 记录每次 schema 变更
INSERT INTO schema_versions (version, description, migration_sql) VALUES
  (1, '初始版本', NULL),
  (2, '添加 budgets 表', 'CREATE TABLE budgets (...);');
```

#### 4.3.2 本地 Schema 同步

App 启动时检查云端 schema 版本，如有更新则下载迁移脚本并执行。

---

## 5. 同步引擎设计

### 5.1 核心组件

```
┌─────────────────────────────────────────────────────────┐
│                    Sync Engine                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  Version    │  │   Pull      │  │     Push        │ │
│  │  Checker    │  │   Manager   │  │     Manager     │ │
│  │             │  │             │  │                 │ │
│  │ • 检查版本  │  │ • 增量拉取  │  │ • 推送变更      │ │
│  │ • 对比差异  │  │ • 合并数据  │  │ • 冲突检测      │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  Conflict   │  │   Retry     │  │    Scheduler    │ │
│  │  Resolver   │  │   Manager   │  │                 │ │
│  │             │  │             │  │ • 定时触发      │ │
│  │ • LWW 策略  │  │ • 失败重试  │  │ • 手动触发      │ │
│  │ • 错误处理  │  │ • 指数退避  │  │ • 优先级队列    │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 5.2 同步策略

#### 5.2.1 版本号机制

| 概念 | 说明 |
|------|------|
| `version` | 每条记录的版本号，修改时 +1 |
| `max_version` | 某张表的最高版本号 |
| `local_version` | 本地上次同步到的版本号 |

#### 5.2.2 增量拉取

```
本地 version = 100
云端 max_version = 150

拉取条件：WHERE version > 100
结果：拉取 50 条变更记录
```

#### 5.2.3 变更推送

```
本地标记 syncPending = true 的记录
  ↓
逐条推送到云端
  ↓
成功 → syncPending = false
失败 → 保留待同步，稍后重试
```

### 5.3 冲突解决（LWW）

```
本地记录：updated_at = 10:00:00
云端记录：updated_at = 09:59:59

判断：本地更新
操作：推送覆盖云端
```

```
本地记录：updated_at = 10:00:00
云端记录：updated_at = 10:00:01

判断：云端更新
操作：拉取覆盖本地
```

### 5.4 同步时机

| 触发方式 | 说明 |
|----------|------|
| App 启动 | 检查版本，增量同步 |
| 定时同步 | 每 5 分钟检查一次 |
| 手动同步 | 用户下拉刷新 |
| 写入后 | 标记待同步，后台推送 |
| 网络恢复 | 检测到网络恢复时触发 |

### 5.5 分模块同步

```dart
enum SyncModule {
  tasks('tasks'),
  items('household_items'),
  itemLocations('item_locations'),
  pets('pets'),
  members('members');
  
  final String tableName;
  const SyncModule(this.tableName);
}

class ModuleSyncManager {
  // 按模块独立同步
  Future<void> syncModule(SyncModule module) async {
    await pullChanges(module.tableName);
    await pushChanges(module.tableName);
  }
  
  // 全量同步
  Future<void> syncAll() async {
    for (final module in SyncModule.values) {
      await syncModule(module);
    }
  }
}
```

---

## 6. 实现步骤

### Phase 1: 基础设施（3-4 天）

#### 6.1.1 添加依赖

```yaml
# pubspec.yaml
dependencies:
  drift: ^2.14.1
  sqlite3_flutter_libs: ^0.5.18
  path_provider: ^2.1.3  # 已有
  path: ^1.8.3

dev_dependencies:
  drift_dev: ^2.14.1
  build_runner: ^2.4.8  # 已有
```

#### 6.1.2 创建本地数据库

**任务清单**：
- [ ] 创建 `lib/data/local_db/` 目录结构
- [ ] 定义所有业务表的 Drift 表定义
- [ ] 创建 AppDatabase 类
- [ ] 配置 build_runner 生成代码
- [ ] 验证数据库创建成功

**目录结构**：
```
lib/data/local_db/
├── app_database.dart
├── app_database.g.dart  (自动生成)
├── tables/
│   ├── tasks.dart
│   ├── household_items.dart
│   ├── item_locations.dart
│   ├── pets.dart
│   └── members.dart
└── daos/
    ├── tasks_dao.dart
    ├── items_dao.dart
    └── pets_dao.dart
```

#### 6.1.3 云端数据库改造

**任务清单**：
- [ ] 为每张业务表添加 `version` 和 `updated_at` 字段
- [ ] 创建 `sync_versions` 追踪表
- [ ] 创建自动更新版本的触发器
- [ ] 测试触发器工作正常

### Phase 2: 同步引擎核心（3-4 天）

#### 6.2.1 版本管理

**任务清单**：
- [ ] 实现本地版本号存储和读取
- [ ] 实现云端版本号查询
- [ ] 实现版本对比逻辑

#### 6.2.2 拉取逻辑

**任务清单**：
- [ ] 实现增量数据拉取
- [ ] 实现数据合并（upsert）
- [ ] 实现本地版本号更新

#### 6.2.3 推送逻辑

**任务清单**：
- [ ] 实现待同步数据查询
- [ ] 实现数据推送
- [ ] 实现同步状态更新

#### 6.2.4 冲突处理

**任务清单**：
- [ ] 实现 LWW 比较逻辑
- [ ] 实现冲突解决
- [ ] 实现错误处理

### Phase 3: 集成与适配（2-3 天）

#### 6.3.1 Repository 层改造

**任务清单**：
- [ ] 创建 SyncRepository 基类
- [ ] 改造 TaskRepository 使用本地数据库
- [ ] 改造 ItemRepository 使用本地数据库
- [ ] 改造 PetRepository 使用本地数据库
- [ ] 保留原有 Supabase 调用作为回退

#### 6.3.2 同步调度器

**任务清单**：
- [ ] 实现定时同步调度
- [ ] 实现网络状态监听
- [ ] 实现手动同步触发

### Phase 4: 扩展与优化（2-3 天）

#### 6.4.1 Schema 自动迁移

**任务清单**：
- [ ] 创建云端 schema 版本表
- [ ] 实现本地 schema 版本检查
- [ ] 实现自动迁移逻辑

#### 6.4.2 性能优化

**任务清单**：
- [ ] 批量操作优化
- [ ] 索引优化
- [ ] 大数据量测试

#### 6.4.3 监控与日志

**任务清单**：
- [ ] 添加同步日志
- [ ] 添加错误上报
- [ ] 添加性能监控

---

## 7. API 接口规范

### 7.1 Repository 接口

```dart
abstract class SyncRepository<T> {
  // 读取（优先本地）
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Stream<List<T>> watchAll();
  Stream<T?> watchById(String id);
  
  // 写入（本地 + 标记待同步）
  Future<T> create(T item);
  Future<T> update(T item);
  Future<void> delete(String id);
  
  // 同步相关
  Future<int> getLocalVersion();
  Future<List<T>> getSyncPending();
  Future<void> markSynced(String id);
}
```

### 7.2 Sync Engine 接口

```dart
class SyncEngine {
  // 版本检查
  Future<int> getRemoteVersion(String tableName);
  Future<int> getLocalVersion(String tableName);
  Future<bool> needsSync(String tableName);
  
  // 拉取
  Future<void> pull(String tableName);
  Future<void> pullSince(String tableName, int version);
  
  // 推送
  Future<void> push(String tableName);
  Future<void> pushItem(String tableName, Map<String, dynamic> item);
  
  // 完整同步
  Future<SyncResult> sync(String tableName);
  Future<SyncResult> syncAll();
}

class SyncResult {
  final bool success;
  final int pulled;
  final int pushed;
  final int conflicts;
  final List<String> errors;
}
```

### 7.3 同步调度器接口

```dart
class SyncScheduler {
  // 定时同步
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)});
  void stopPeriodicSync();
  
  // 手动触发
  Future<SyncResult> syncNow();
  Future<SyncResult> syncModule(SyncModule module);
  
  // 状态查询
  bool get isSyncing;
  DateTime? get lastSyncTime;
  Stream<SyncStatus> get statusStream;
}
```

---

## 8. 测试策略

### 8.1 单元测试

| 模块 | 测试重点 |
|------|----------|
| 表定义 | 字段类型、约束、默认值 |
| DAO | CRUD 操作、查询正确性 |
| Sync Engine | 版本比较、增量拉取、冲突解决 |
| Conflict Resolver | LWW 逻辑、边界情况 |

### 8.2 集成测试

| 场景 | 测试内容 |
|------|----------|
| 首次同步 | 全量拉取、数据完整性 |
| 增量同步 | 版本号正确、数据一致 |
| 离线写入 | 本地写入成功、待同步标记 |
| 上线同步 | 待同步数据推送、状态更新 |
| 冲突处理 | LWW 正确、数据不丢失 |

### 8.3 端到端测试

| 场景 | 测试步骤 |
|------|----------|
| 正常流程 | 启动 → 同步 → 使用 → 同步 |
| 离线流程 | 断网 → 使用 → 联网 → 同步 |
| 冲突流程 | 设备A修改 → 设备B修改 → 同步 → 验证 |
| 异常流程 | 同步失败 → 重试 → 成功 |

### 8.4 性能测试

| 指标 | 目标 |
|------|------|
| 本地查询 | < 50ms |
| 首次全量同步 | < 30s（1000条数据） |
| 增量同步 | < 5s（100条变更） |
| 内存占用 | < 100MB |

---

## 9. 部署与运维

### 9.1 部署流程

```
1. 云端数据库改造（SQL 迁移）
   ↓
2. 代码合并到主分支
   ↓
3. App 构建与测试
   ↓
4. 灰度发布（10% 用户）
   ↓
5. 全量发布
```

### 9.2 监控指标

| 指标 | 告警阈值 |
|------|----------|
| 同步失败率 | > 5% |
| 同步延迟 | > 10 分钟 |
| 冲突率 | > 1% |
| 本地 DB 大小 | > 50MB |

### 9.3 回滚方案

| 场景 | 操作 |
|------|------|
| 同步引擎异常 | 切换回纯云端模式 |
| 本地数据库损坏 | 清除本地数据，重新同步 |
| 数据不一致 | 手动对账，修复数据 |

---

## 10. 风险与应对

### 10.1 技术风险

| 风险 | 影响 | 应对 |
|------|------|------|
| 同步冲突 | 数据丢失 | LWW + 日志记录 |
| 本地存储空间不足 | 同步失败 | 监控 + 清理策略 |
| 网络不稳定 | 同步延迟 | 重试机制 + 指数退避 |
| Schema 变更 | 迁移失败 | 版本化迁移 + 回滚 |

### 10.2 业务风险

| 风险 | 影响 | 应对 |
|------|------|------|
| 用户数据丢失 | 用户投诉 | 定期备份 + 恢复机制 |
| 同步延迟 | 数据不一致 | 实时同步关键数据 |

---

## 11. 附录

### 11.1 术语表

| 术语 | 说明 |
|------|------|
| Drift | Flutter 的类型安全 SQLite ORM |
| LWW | Last Write Wins，最后写入获胜 |
| Sync Engine | 同步引擎，负责数据同步 |
| Version | 版本号，用于追踪数据变更 |

### 11.2 参考资料

- [Drift 官方文档](https://drift.simonbinder.eu/)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/dart/introduction)
- [Flutter 离线优先架构](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple)

### 11.3 变更记录

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| v1.0 | 2026-03-21 | Sisyphus | 初始版本 |

---

**文档结束**
