import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'extended_image_provider.dart';

/// Instructs Flutter to decode the image at the specified dimensions
/// instead of at its native size.
///
/// This allows finer control of the size of the image in [ImageCache] and is
/// generally used to reduce the memory footprint of [ImageCache].
///
/// The decoded image may still be displayed at sizes other than the
/// cached size provided here.
///
/// [scailingRatio] If not null, the original image's width and height will
/// divide with it to calculate targetWidth.
/// [maxBytes] If not null, the image will resize to a size that nolarger
/// than [maxBytes]. Default size is 500KB.
class ExtendedResizeImage extends ImageProvider<_SizeAwareCacheKey>
    with ExtendedImageProvider<_SizeAwareCacheKey> {
  const ExtendedResizeImage(
    this.imageProvider, {
    this.scailingRatio,
    this.maxBytes = 500 << 10,
    this.width,
    this.height,
    this.allowUpscaling = false,
  })  : assert(scailingRatio != null ||
            maxBytes != null ||
            width != null ||
            height != null),
        assert(allowUpscaling != null);

  /// The [ImageProvider] that this class wraps.
  final ImageProvider imageProvider;

  /// The maxBytes the image should decode to and cache.
  final int? maxBytes;

  /// The scailingRatio the image should decode to and cache.
  final double? scailingRatio;

  /// The width the image should decode to and cache.
  final int? width;

  /// The height the image should decode to and cache.
  final int? height;

  /// Whether the [width] and [height] parameters should be clamped to the
  /// intrinsic width and height of the image.
  ///
  /// In general, it is better for memory usage to avoid scaling the image
  /// beyond its intrinsic dimensions when decoding it. If there is a need to
  /// scale an image larger, it is better to apply a scale to the canvas, or
  /// to use an appropriate [Image.fit].
  final bool allowUpscaling;

  /// Composes the `provider` in a [ResizeImage] only when `cacheWidth` and
  /// `cacheHeight` are not both null.
  ///
  /// When `cacheWidth` and `cacheHeight` are both null, this will return the
  /// `provider` directly.
  ///
  /// Extended with `scailingRatio` and `maxBytes`.
  static ImageProvider<Object> resizeIfNeeded(
    int? cacheWidth,
    int? cacheHeight,
    ImageProvider<Object> provider, {
    double? scailingRatio,
    int? maxBytes,
  }) {
    if (cacheWidth != null ||
        cacheHeight != null ||
        scailingRatio != null ||
        maxBytes != null) {
      return ExtendedResizeImage(
        provider,
        width: cacheWidth,
        height: cacheHeight,
        maxBytes: maxBytes,
        scailingRatio: scailingRatio,
      );
    }
    return provider;
  }

  @override
  ImageStreamCompleter load(_SizeAwareCacheKey key, DecoderCallback decode) {
    final DecoderCallback decodeResize = (Uint8List bytes,
        {int? cacheWidth, int? cacheHeight, bool? allowUpscaling}) {
      assert(
          cacheWidth == null && cacheHeight == null && allowUpscaling == null,
          'ResizeImage cannot be composed with another ImageProvider that applies '
          'cacheWidth, cacheHeight, or allowUpscaling.');
      return _instantiateImageCodec(
        bytes,
        scale: scailingRatio,
        maxBytes: maxBytes,
        targetWidth: width,
        targetHeight: height,
      );
    };
    final ImageStreamCompleter completer =
        imageProvider.load(key.providerCacheKey, decodeResize);
    if (!kReleaseMode) {
      completer.debugLabel =
          '${completer.debugLabel} - Resized(scale: ${key.scailingRatio} maxBytes${key.maxBytes})';
    }
    return completer;
  }

  @override
  Future<_SizeAwareCacheKey> obtainKey(ImageConfiguration configuration) {
    Completer<_SizeAwareCacheKey>? completer;
    // If the imageProvider.obtainKey future is synchronous, then we will be able to fill in result with
    // a value before completer is initialized below.
    SynchronousFuture<_SizeAwareCacheKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      if (completer == null) {
        // This future has completed synchronously (completer was never assigned),
        // so we can directly create the synchronous result to return.
        result = SynchronousFuture<_SizeAwareCacheKey>(
            _SizeAwareCacheKey(key, scailingRatio, maxBytes, width, height));
      } else {
        // This future did not synchronously complete.
        completer.complete(
            _SizeAwareCacheKey(key, scailingRatio, maxBytes, width, height));
      }
    });
    if (result != null) {
      return result!;
    }
    // If the code reaches here, it means the imageProvider.obtainKey was not
    // completed sync, so we initialize the completer for completion later.
    completer = Completer<_SizeAwareCacheKey>();
    return completer.future;
  }

  Future<Codec> _instantiateImageCodec(
    Uint8List list, {
    double? scale,
    int? maxBytes,
    int? targetWidth,
    int? targetHeight,
  }) async {
    final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(list);
    final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);
    if (scale != null) {
      targetWidth = descriptor.width ~/ scale;
      targetHeight = descriptor.height ~/ scale;
    } else if (maxBytes != null) {
      IntSize size = resizeWH(descriptor.width, descriptor.height, maxBytes);
      targetWidth = size.width;
      targetHeight = size.height;
    } else if (!allowUpscaling) {
      if (targetWidth != null && targetWidth > descriptor.width) {
        targetWidth = descriptor.width;
      }
      if (targetHeight != null && targetHeight > descriptor.height) {
        targetHeight = descriptor.height;
      }
    }
    if (kDebugMode) {
      print('origin size: ${descriptor.width}*${descriptor.height} '
          'scaled size: $targetWidth*$targetHeight');
    }
    return descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
  }

  ///Calculate fittest size.
  IntSize resizeWH(int width, int height, int maxSize) {
    int w_h = width * height;
    int outW = width;
    int outH = height;
    int maxSize_1_4 = maxSize >> 2;
    if (w_h > maxSize_1_4) {
      int gcd = _gcd(width, height);
      if (gcd != 1) {
        int gcdW = width ~/ gcd;
        int gcdH = height ~/ gcd;
        int scale = sqrt(maxSize_1_4 / (gcdW * gcdH)).toInt();
        outW = gcdW * scale;
        outH = gcdH * scale;
      }
    }
    return IntSize(outW, outH);
  }

  int _gcd(int a, int b) {
    int r = 1;
    do {
      r = a % b;
      a = b;
      b = r;
    } while (b != 0);
    return a;
  }
}

@immutable
class IntSize {
  const IntSize(this.width, this.height);

  final int width;
  final int height;
}

@immutable
class _SizeAwareCacheKey {
  const _SizeAwareCacheKey(
    this.providerCacheKey,
    this.scailingRatio,
    this.maxBytes,
    this.width,
    this.height,
  );

  final Object providerCacheKey;

  final int? maxBytes;

  final double? scailingRatio;

  final int? width;

  final int? height;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _SizeAwareCacheKey &&
        other.providerCacheKey == providerCacheKey &&
        other.maxBytes == maxBytes &&
        other.scailingRatio == scailingRatio &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode =>
      hashValues(providerCacheKey, maxBytes, scailingRatio, width, height);
}
