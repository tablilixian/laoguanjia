// 地产大亨游戏入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/game_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MonopolyGameApp(),
    ),
  );
}

class MonopolyGameApp extends StatelessWidget {
  const MonopolyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '地产大亨',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const MonopolyGamePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
