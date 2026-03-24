import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientManager {
  static SupabaseClient? _client;

  static const String _supabaseUrl = 'https://tkllhxskjgbreqdswvcj.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbGxoeHNramdicmVxZHN3dmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3ODExNjEsImV4cCI6MjA4ODM1NzE2MX0.20vFkV_nOfY1jZNBFRimksy_hj4aQ0XXhPk3-RHnSyE';

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
        debug: kDebugMode,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Supabase 初始化超时，请检查网络连接');
        },
      );
      _client = Supabase.instance.client;
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw Exception('Supabase 初始化失败: $e');
    }
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase 尚未初始化，请先调用 initialize()');
    }
    return _client!;
  }

  static bool get isInitialized => _client != null;
}
