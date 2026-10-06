import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:manager/map/tile_loading.dart';

/// Always fails to load, counting attempts. Like flutter_map's network
/// provider, it evicts itself from the image cache when it fails.
class _FailingImage extends ImageProvider<_FailingImage> {
  int loads = 0;

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(Future<ImageInfo>.microtask(() {
      imageCache.evict(key);
      throw Exception('tile failed');
    }));
  }
}

void main() {
  test('retries throttling, server errors and dropped connections', () {
    expect(TileLoading.isRetryableStatus(429), isTrue);
    expect(TileLoading.isRetryableStatus(503), isTrue);
    expect(TileLoading.isRetryableStatus(404), isFalse);
    expect(TileLoading.isRetryableError(TimeoutException('slow')), isTrue);
    expect(TileLoading.isRetryableError(http.ClientException('reset')), isTrue);
    expect(
      TileLoading.isRetryableError(http.RequestAbortedException()),
      isFalse,
    );
  });

  testWidgets('reloads a failed tile with backoff, then gives up', (tester) async {
    final image = _FailingImage();
    late TileImage tile;
    tile = TileImage(
      vsync: const TestVSync(),
      coordinates: const TileCoordinates(0, 0, 0),
      imageProvider: image,
      onLoadComplete: (_) {},
      onLoadError: (_, error, stack) => TileLoading.onTileError(tile, error, stack),
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: null,
      cancelLoading: Completer<void>(),
    );

    tile.load();
    await tester.pump();
    expect(image.loads, 1);
    expect(tile.loadError, isTrue);

    for (final (delay, loads) in [(2, 2), (5, 3), (15, 4), (30, 5)]) {
      await tester.pump(Duration(seconds: delay));
      await tester.pump();
      expect(image.loads, loads);
    }

    await tester.pump(const Duration(minutes: 5));
    expect(image.loads, 5, reason: 'stops after the last retry');
    tile.dispose();
  });

  testWidgets('skips the retry when the tile was disposed', (tester) async {
    final image = _FailingImage();
    late TileImage tile;
    tile = TileImage(
      vsync: const TestVSync(),
      coordinates: const TileCoordinates(1, 1, 1),
      imageProvider: image,
      onLoadComplete: (_) {},
      onLoadError: (_, error, stack) => TileLoading.onTileError(tile, error, stack),
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: null,
      cancelLoading: Completer<void>(),
    );

    tile.load();
    await tester.pump();
    tile.dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(image.loads, 1);
  });
}
