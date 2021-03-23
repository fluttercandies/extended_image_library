import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/painting.dart' hide imageCache;

/// The cached raw image data
Map<ExtendedImageProvider<dynamic>, Uint8List> rawImageDataMap =
    <ExtendedImageProvider<dynamic>, Uint8List>{};

/// The imageCaches to store custom ImageCache
Map<String, ImageCache> imageCaches = <String, ImageCache>{};

mixin ExtendedImageProvider<T extends Object> on ImageProvider<T> {
  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  ///
  bool get cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this image.
  String? get imageCacheName;

  /// The [ImageCache] which this is stored in it.
  ImageCache get imageCache {
    if (imageCacheName != null) {
      return imageCaches.putIfAbsent(imageCacheName!, () => ImageCache());
    } else {
      return PaintingBinding.instance!.imageCache!;
    }
  }

  /// The raw data of image
  Uint8List get rawImageData {
    assert(cacheRawData,
        'you should set [ExtendedImageProvider.cacheRawData] to true, if you want to get rawImageData from provider.');

    assert(
      rawImageDataMap.containsKey(this),
      'raw image data is not already now!',
    );
    final Uint8List raw = rawImageDataMap[this]!;

    return raw;
  }

  /// Override this method, so that you can handle raw image data,
  /// for example, compress
  Future<ui.Codec> instantiateImageCodec(
    Uint8List data,
    DecoderCallback decode,
  ) async {
    if (cacheRawData) {
      rawImageDataMap[this] = data;
    }

    return await decode(data);
  }

  /// Called by [resolve] with the key returned by [obtainKey].
  ///
  /// Subclasses should override this method rather than calling [obtainKey] if
  /// they need to use a key directly. The [resolve] method installs appropriate
  /// error handling guards so that errors will bubble up to the right places in
  /// the framework, and passes those guards along to this method via the
  /// [handleError] parameter.
  ///
  /// It is safe for the implementation of this method to call [handleError]
  /// multiple times if multiple errors occur, or if an error is thrown both
  /// synchronously into the current part of the stack and thrown into the
  /// enclosing [Zone].
  ///
  /// The default implementation uses the key to interact with the [ImageCache],
  /// calling [ImageCache.putIfAbsent] and notifying listeners of the [stream].
  /// Implementers that do not call super are expected to correctly use the
  /// [ImageCache].
  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    T key,
    ImageErrorListener handleError,
  ) {
    // This is an unusual edge case where someone has told us that they found
    // the image we want before getting to this method. We should avoid calling
    // load again, but still update the image cache with LRU information.
    if (stream.completer != null) {
      final ImageStreamCompleter? completer = imageCache.putIfAbsent(
        key,
        () => stream.completer!,
        onError: handleError,
      );
      assert(identical(completer, stream.completer));
      return;
    }
    final ImageStreamCompleter? completer = imageCache.putIfAbsent(
      key,
      () => load(key, PaintingBinding.instance!.instantiateImageCodec),
      onError: handleError,
    );
    if (completer != null) {
      stream.setCompleter(completer);
    }
  }

  /// Evicts an entry from the image cache.
  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
    bool includeLive = true,
  }) async {
    rawImageDataMap.remove(this);

    cache ??= imageCache;
    final T key = await obtainKey(configuration);
    return cache.evict(key, includeLive: includeLive);
  }
}
