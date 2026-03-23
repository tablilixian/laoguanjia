import 'dart:io';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' if (dart.library.html) 'libtorrent_stub.dart';

Future<void> initLibtorrent() async {
  try {
    await LibtorrentFlutter.init();
    print('LibtorrentFlutter 初始化成功');
  } catch (e) {
    print('LibtorrentFlutter 初始化失败: $e');
  }
}
