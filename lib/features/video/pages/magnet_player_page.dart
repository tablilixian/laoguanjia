import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart' if (dart.library.html) '../../../libtorrent_stub.dart';
import '../widgets/video_player_widget.dart';

/// 磁力链接播放页面
///
/// 支持输入磁力链接，边下边播视频
class MagnetPlayerPage extends StatefulWidget {
  const MagnetPlayerPage({super.key});

  @override
  State<MagnetPlayerPage> createState() => _MagnetPlayerPageState();
}

class _MagnetPlayerPageState extends State<MagnetPlayerPage> {
  final TextEditingController _magnetController = TextEditingController();
  // 延迟获取引擎实例，避免在初始化前访问
  LibtorrentFlutter? _engine;

  int? _torrentId;
  TorrentInfo? _torrentInfo;
  StreamInfo? _streamInfo;
  List<FileInfo>? _files;

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // 安全获取引擎实例
  LibtorrentFlutter get engine {
    if (_engine == null) {
      try {
        _engine = LibtorrentFlutter.instance;
      } catch (e) {
        throw StateError('LibtorrentFlutter.init() 未被调用，请重启应用');
      }
    }
    return _engine!;
  }

  @override
  void initState() {
    super.initState();
    // 依赖全局初始化，直接标记为已初始化
    _isInitialized = true;
  }

  @override
  void dispose() {
    _magnetController.dispose();
    _cleanupTorrent();
    super.dispose();
  }

  Future<void> _addMagnet() async {
    final magnet = _magnetController.text.trim();
    if (magnet.isEmpty || !magnet.startsWith('magnet:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的磁力链接')),
      );
      return;
    }

    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('引擎未初始化，请稍候...')),
      );
      return;
    }

    if (_error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先解决初始化错误: $_error')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _torrentInfo = null;
      _files = null;
      _streamInfo = null;
    });

    try {
      await _cleanupTorrent();

      final id = await engine.addMagnet(magnet);
      setState(() => _torrentId = id);

      engine.torrentUpdates.listen((torrents) {
        if (!mounted || _torrentId == null) return;

        final info = torrents[_torrentId!];
        if (info != null) {
          setState(() => _torrentInfo = info);

          if (info.totalSize > 0 && _files == null) {
            _loadFiles();
          }
        }
      });
    } catch (e) {
      String errorMsg = '添加失败';
      
      if (e.toString().contains('MissingPluginException')) {
        errorMsg = '插件未正确配置，请运行 flutter pub get';
      } else if (e.toString().contains('Invalid magnet')) {
        errorMsg = '无效的磁力链接格式';
      } else {
        errorMsg = '添加失败: $e';
      }
      
      setState(() {
        _error = errorMsg;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFiles() async {
    if (_torrentId == null) return;

    try {
      final files = await engine.getFiles(_torrentId!);
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '获取文件列表失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startStream(FileInfo file) async {
    if (_torrentId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stream = await engine.startStream(
        _torrentId!,
        file.index,
      );

      setState(() {
        _streamInfo = stream;
        _isLoading = false;
      });

      // 监听流状态
      engine.streamUpdates.listen((streams) {
        if (!mounted) return;
        if (stream != null) {
          final info = streams[stream!.id];
          if (info != null) {
            setState(() => _streamInfo = info);
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = '启动流失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupTorrent() async {
    if (_torrentId != null) {
      engine.stopAllStreamsForTorrent(_torrentId!);
      engine.removeTorrent(_torrentId!, deleteFiles: true);
      _torrentId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('磁力链接播放'),
        actions: [
          if (_torrentId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _cleanupTorrent();
                setState(() {
                  _torrentInfo = null;
                  _files = null;
                  _streamInfo = null;
                });
              },
              tooltip: '清除',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _error = null);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 正在播放
    if (_streamInfo != null && _streamInfo!.isReady) {
      return Column(
        children: [
          // 视频播放器
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayerWidget(
              videoUrl: _streamInfo!.url,
              autoPlay: true,
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('播放错误: $error')),
                );
              },
            ),
          ),

          // 下载进度
          if (_torrentInfo != null) _buildProgressCard(),

          // 返回按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () {
                engine.stopAllStreamsForTorrent(_torrentId!);
                setState(() => _streamInfo = null);
              },
              icon: const Icon(Icons.stop),
              label: const Text('停止播放'),
            ),
          ),
        ],
      );
    }

    // 正在加载元数据或下载
    if (_torrentInfo != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 种子信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _torrentInfo!.name.isNotEmpty
                          ? _torrentInfo!.name
                          : '加载中...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 文件列表
            if (_files != null) ...[
              Text(
                '选择要播放的文件',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._files!.where((f) => f.isStreamable).map((file) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.videocam),
                    title: Text(file.name),
                    subtitle: Text(_formatSize(file.size)),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    onTap: _isLoading ? null : () => _startStream(file),
                  ),
                );
              }),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              const Center(child: Text('正在获取文件列表...')),
            ],
          ],
        ),
      );
    }

    // 初始状态：输入磁力链接
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '输入磁力链接',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _magnetController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'magnet:?xt=urn:btih:...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _addMagnet,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(_isLoading ? '添加中...' : '添加并解析'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _magnetController.text = data!.text!;
                          }
                        },
                        icon: const Icon(Icons.paste),
                        tooltip: '粘贴',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 使用说明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使用说明',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('1. 复制磁力链接（magnet:?xt=urn:btih:...）'),
                  const Text('2. 粘贴到输入框，点击"添加并解析"'),
                  const Text('3. 等待元数据加载完成'),
                  const Text('4. 选择视频文件开始播放'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '首次播放可能需要等待几秒到几分钟，取决于种子热度',
                            style: TextStyle(color: Colors.amber[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (_torrentInfo == null) return const SizedBox.shrink();

    final progress = (_torrentInfo!.progress * 100).toStringAsFixed(1);
    final downloadRate = _formatSpeed(_torrentInfo!.downloadRate);
    final uploadRate = _formatSpeed(_torrentInfo!.uploadRate);

    return Column(
      children: [
        LinearProgressIndicator(value: _torrentInfo!.progress),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$progress%'),
            Text('↓ $downloadRate'),
            Text('↑ $uploadRate'),
            Text('${_torrentInfo!.numPeers} 节点'),
          ],
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
}
