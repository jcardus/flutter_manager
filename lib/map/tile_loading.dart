import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Makes map tiles recover from the occasional failed download.
///
/// The tile servers sometimes throttle (429), fail (5xx) or drop the
/// connection. flutter_map only retries 503s and then leaves the tile blank
/// until it scrolls out of view, so failures are retried at two levels:
/// - each request, quickly, by [httpClient];
/// - each failed tile, with a longer backoff, by [onTileError].
class TileLoading {
  TileLoading._();

  static const _requestTimeout = Duration(seconds: 15);
  static const _tileRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  static final http.Client httpClient = RetryClient(
    _TimeoutClient(http.Client(), _requestTimeout),
    retries: 3,
    when: (response) => isRetryableStatus(response.statusCode),
    whenError: (error, _) => isRetryableError(error),
  );

  static final _attempts = Expando<int>('tileRetryAttempts');

  /// A new provider using [httpClient]; keep one per map so tiles share it.
  static NetworkTileProvider provider() =>
      NetworkTileProvider(httpClient: httpClient);

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

  /// Reloads a failed tile after a delay, a few times. A tile that is
  /// disposed meanwhile (scrolled away, zoomed) is skipped.
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

/// Fails requests whose response doesn't start within [timeout], so a
/// stalled connection is retried instead of leaving the tile loading forever.
class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_timeout);

  @override
  void close() => _inner.close();
}
