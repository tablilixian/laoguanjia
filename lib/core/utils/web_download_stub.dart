import 'dart:convert';

void downloadJson(String jsonString, String tableName) {
  // 在非 Web 平台（Android/iOS）上不支持下载，打印到控制台
  print('📥 [下载功能仅支持 Web 平台] 表名: $tableName');
  print('数据预览: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}...');
}
