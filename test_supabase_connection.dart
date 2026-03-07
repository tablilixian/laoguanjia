// 测试 Supabase 连接的简单脚本
import 'package:supabase/supabase.dart';

void main() async {
  print('测试 Supabase 连接...');
  
  // 直接使用 Supabase 客户端
  final client = SupabaseClient(
    'https://tkllhxskjgbreqdswvcj.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbGxoeHNramdicmVxZHN3dmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3ODExNjEsImV4cCI6MjA4ODM1NzE2MX0.20vFkV_nOfY1jZNBFRimksy_hj4aQ0XXhPk3-RHnSyE',
  );
  
  try {
    print('测试 households 表...');
    final response = await client.from('households').select('id').limit(1);
    print('成功: $response');
  } catch (e) {
    print('错误: $e');
  }
  
  try {
    print('测试 members 表...');
    final response = await client.from('members').select('id').limit(1);
    print('成功: $response');
  } catch (e) {
    print('错误: $e');
  }
  
  print('测试完成');
}
