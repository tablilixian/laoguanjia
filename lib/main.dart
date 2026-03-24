import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/supabase/supabase_client.dart';
import 'libtorrent_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseClientManager.initialize();
    print('Supabase 初始化成功');
  } catch (e) {
    print('Supabase 初始化失败: $e');
  }

  try {
    await initLibtorrent();
  } catch (e) {
    print('Libtorrent 初始化失败: $e');
  }

  runApp(const ProviderScope(child: HomeManagerApp()));
}
