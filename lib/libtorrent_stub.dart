class LibtorrentFlutter {
  static Future<void> init() async {
    print('LibtorrentFlutter 不支持 Web 平台');
  }

  static LibtorrentFlutter get instance => LibtorrentFlutter();

  Future<int> addMagnet(String magnet) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<void> removeTorrent(int id, {bool deleteFiles = false}) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<TorrentInfo?> getTorrentInfo(int id) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<List<FileInfo>?> getTorrentFiles(int id) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<StreamInfo?> getStreamInfo(int id, int fileIndex) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<void> pauseTorrent(int id) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<void> resumeTorrent(int id) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<void> stopAllStreamsForTorrent(int id) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Stream<List<StreamInfo>> get streamUpdates => const Stream.empty();
  Stream<Map<int, TorrentInfo>> get torrentUpdates => const Stream.empty();

  Future<List<FileInfo>?> getFiles(int id) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }

  Future<StreamInfo?> startStream(int id, int fileIndex) async {
    throw UnsupportedError('LibtorrentFlutter 不支持 Web 平台');
  }
}

class TorrentInfo {
  final String name;
  final int totalSize;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int numPeers;
  final int numSeeds;

  TorrentInfo({
    required this.name,
    required this.totalSize,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.numPeers,
    required this.numSeeds,
  });
}

class FileInfo {
  final String name;
  final int size;
  final int index;
  final bool isStreamable;

  FileInfo({
    required this.name,
    required this.size,
    required this.index,
    this.isStreamable = false,
  });
}

class StreamInfo {
  final String url;
  final int fileSize;
  final int readHead;
  final int streamState;
  final double bufferSeconds;
  final int bufferPieces;
  final int readaheadWindow;
  final int activePeers;
  final int downloadRate;
  final bool isReady;
  final int id;

  StreamInfo({
    required this.url,
    required this.fileSize,
    required this.readHead,
    required this.streamState,
    required this.bufferSeconds,
    required this.bufferPieces,
    required this.readaheadWindow,
    required this.activePeers,
    required this.downloadRate,
    this.isReady = false,
    this.id = 0,
  });
}
