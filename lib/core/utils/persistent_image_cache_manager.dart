import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A [CacheManager] for banner/carousel images that stores files under the
/// app's Application Support directory instead of the OS temp directory.
///
/// `cached_network_image`'s default cache manager keeps files under
/// `getTemporaryDirectory()`. On iOS that maps to `NSTemporaryDirectory()`,
/// which the OS is free to purge at any time (much more aggressively than
/// Android's cache dir) — so banners/carousels can silently lose their cache
/// and re-download from the network on iOS even though nothing changed.
/// Using Application Support avoids that OS-level purge, so once an image is
/// cached it stays cached until it naturally expires (see [_config]).
class PersistentImageCacheManager {
  static const key = 'welfogPersistentImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 300,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
      fileSystem: _AppSupportFileSystem(key),
    ),
  );
}

class _AppSupportFileSystem implements FileSystem {
  _AppSupportFileSystem(this._cacheKey) : _fileDir = _createDirectory(_cacheKey);

  final Future<Directory> _fileDir;
  final String _cacheKey;

  static Future<Directory> _createDirectory(String key) async {
    final baseDir = await getApplicationSupportDirectory();
    final path = p.join(baseDir.path, key);

    const fs = LocalFileSystem();
    final directory = fs.directory(path);
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    final directory = await _fileDir;
    if (!(await directory.exists())) {
      await _createDirectory(_cacheKey);
    }
    return directory.childFile(name);
  }
}
