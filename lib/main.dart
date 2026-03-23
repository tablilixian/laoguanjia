import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/supabase/supabase_client.dart';
import 'libtorrent_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseClientManager.initialize();

  await initLibtorrent();

  runApp(const ProviderScope(child: HomeManagerApp()));
}
