import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/supabase/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Supabase
  await SupabaseClientManager.initialize();

  runApp(const ProviderScope(child: HomeManagerApp()));
}
