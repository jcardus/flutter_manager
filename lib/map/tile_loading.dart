import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http/http.dart' as http;
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path_provider/path_provider.dart';

/// Provides disk-cached, cancellable tile loading with automatic fallback.
///
/// Tile requests are cached to disk so previously visited map areas load
/// instantly (0 ms) without hitting the network or being throttled.
/// Tile requests are cancelled the moment they leave the viewport.
class TileLoading {
  TileLoading._();

  static CacheStore? _store;
  static final _attempts = Expando<int>('tileRetryAttempts');
  static const _tileRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  /// Initialize the disk cache store during app startup.
  static Future<void> init() async {
    if (kIsWeb) {
      _store = MemCacheStore();
      return;
    }
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final tilesDir = Directory('${cacheDir.path}/map_tiles');
      if (!tilesDir.existsSync()) {
        tilesDir.createSync(recursive: true);
      }
      _store = FileCacheStore(tilesDir.path);
    } catch (e) {
      debugPrint('Failed to initialize FileCacheStore: $e');
      _store = MemCacheStore();
    }
  }

  /// Returns a [CachedTileProvider] with persistent disk cache and cancellation.
  static TileProvider provider() {
    final store = _store ?? MemCacheStore();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': 'com.fleetmap.fleetmanager',
        },
      ),
    );

    return CachedTileProvider(
      store: store,
      dio: dio,
      cachePolicy: CachePolicy.forceCache,
      maxStale: const Duration(days: 30),
      hitCacheOnNetworkFailure: true,
      keyBuilder: ({required Uri url, Map<String, String>? headers, Object? body}) {
        // Normalize Google mt0, mt1, mt2, mt3 subdomains so tiles are shared
        final host = url.host.replaceAll(RegExp(r'mt[0-3]\.google\.com'), 'mt.google.com');
        final normalized = url.replace(host: host);
        return CacheOptions.defaultCacheKeyBuilder(url: normalized, headers: headers, body: body);
      },
    );
  }

  @visibleForTesting
  static bool isRetryableStatus(int status) =>
      status == 408 || status == 429 || status >= 500;

  @visibleForTesting
  static bool isRetryableError(Object error) =>
      error is! http.RequestAbortedException &&
      (error is TimeoutException ||
          error is SocketException ||
          error is HttpException ||
          error is http.ClientException);

  /// Reloads a failed tile after a delay, a few times.
  static void onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    final attempt = _attempts[tile] ?? 0;
    if (attempt >= _tileRetryDelays.length) return;
    _attempts[tile] = attempt + 1;
    Timer(_tileRetryDelays[attempt], () {
      if (tile.cancelLoading.isCompleted || !tile.loadError) return;
      tile.load();
    });
  }
}
