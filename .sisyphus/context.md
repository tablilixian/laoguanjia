# Laoguanjia Project Context

## Flutter
- Flutter SDK: `/Users/lilixian/jobs/env/flutter/bin`
- Run: `flutter` (use full path)
- Analyze: `flutter analyze`
- Build Web: `flutter build web`

## Project Structure
- Standard Flutter project with Riverpod state management
- GoRouter for navigation
- SharedPreferences for local storage

## Finance System
- Snapshot-based bookkeeping (compare snapshots to derive income/expenses)
- 8 account types: 银行卡, 支付宝, 微信支付, 现金, 信用卡, 花呗, 白条, 其他
- JSON + SharedPreferences storage (no Drift/SQLite)
- Entry: secondary card on home page (not a bottom tab)

## Key Config
- No cloud dependency — fully offline
- No `as any` / `@ts-ignore` / `@ts-expect-error` allowed
