import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'app.dart';
import 'data/supabase/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Supabase
  await SupabaseClientManager.initialize();

  // 初始化 Libtorrent Flutter
  try {
    await LibtorrentFlutter.init();
    print('LibtorrentFlutter 初始化成功');
  } catch (e) {
    print('LibtorrentFlutter 初始化失败: $e');
  }

  runApp(const ProviderScope(child: HomeManagerApp()));
}
