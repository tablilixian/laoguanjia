import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' if (dart.library.html) 'libtorrent_stub.dart';

Future<void> initLibtorrent() async {
  try {
    await LibtorrentFlutter.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('LibtorrentFlutter 初始化超时');
      },
    );
    print('LibtorrentFlutter 初始化成功');
  } on TimeoutException {
    print('LibtorrentFlutter 初始化超时，将使用离线模式');
  } catch (e) {
    print('LibtorrentFlutter 初始化失败: $e，将使用离线模式');
  }
}
