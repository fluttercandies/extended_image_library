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
class ExtendedResizeImage extends ImageProvider<_SizeAwareCacheKey>
    with ExtendedImageProvider<_SizeAwareCacheKey> {
  const ExtendedResizeImage(
    this.imageProvider, {
    this.compressionRatio,
    this.maxBytes = 500 << 10,
    this.width,
    this.height,
    this.allowUpscaling = false,
    this.cacheRawData = false,
    this.imageCacheName,
  }) : assert((compressionRatio != null &&
                compressionRatio > 0 &&
                compressionRatio < 1) ||
            (maxBytes != null && maxBytes > 0) ||
            width != null ||
            height != null);

  /// The [ImageProvider] that this class wraps.
  final ImageProvider imageProvider;

  /// [ExtendedResizeImage] will compress the image to a size
  /// that is smaller than [maxBytes]. The default size is 500KB.
  final int? maxBytes;

  /// The image`s size will resize to original * [compressionRatio].
  /// It's ExtendedResizeImage`s first pick.
  /// The compressionRatio`s range is from 0.0 (exclusive), to
  /// 1.0 (exclusive).
  final double? compressionRatio;

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

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// Composes the `provider` in a [ResizeImage] only when `cacheWidth` and
  /// `cacheHeight` are not both null.
  ///
  /// When `cacheWidth` and `cacheHeight` are both null, this will return the
  /// `provider` directly.
  ///
  /// Extended with `scaling` and `maxBytes`.
  static ImageProvider<Object> resizeIfNeeded({
    required ImageProvider<Object> provider,
    int? cacheWidth,
    int? cacheHeight,
    double? compressionRatio,
    int? maxBytes,
    bool cacheRawData = false,
    String? imageCacheName,
  }) {
    if ((compressionRatio != null &&
            compressionRatio > 0 &&
            compressionRatio < 1) ||
        (maxBytes != null && maxBytes > 0) ||
        cacheWidth != null ||
        cacheHeight != null) {
      return ExtendedResizeImage(
        provider,
        width: cacheWidth,
        height: cacheHeight,
        maxBytes: maxBytes,
        compressionRatio: compressionRatio,
        cacheRawData: cacheRawData,
        imageCacheName: imageCacheName,
      );
    }
    return provider;
  }

  @override
  ImageStreamCompleter load(_SizeAwareCacheKey key, DecoderCallback decode) {
    final DecoderCallback decodeResize = (
      Uint8List bytes, {
      int? cacheWidth,
      int? cacheHeight,
      bool? allowUpscaling,
    }) {
      assert(
        cacheWidth == null && cacheHeight == null && allowUpscaling == null,
        'ResizeImage cannot be composed with another ImageProvider that applies '
        'cacheWidth, cacheHeight, or allowUpscaling.',
      );
      return _instantiateImageCodec(
        bytes,
        compressionRatio: compressionRatio,
        maxBytes: maxBytes,
        targetWidth: width,
        targetHeight: height,
      );
    };
    final ImageStreamCompleter completer = imageProvider.load(
      key.providerCacheKey,
      decodeResize,
    );
    if (!kReleaseMode) {
      completer.debugLabel =
          '${completer.debugLabel} - Resized(compressionRatio:'
          ' ${key.compressionRatio} maxBytes:${key.maxBytes} size:${key.width}*${key.height})';
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
        result = SynchronousFuture<_SizeAwareCacheKey>(_SizeAwareCacheKey(
          key,
          compressionRatio,
          maxBytes,
          width,
          height,
          cacheRawData,
          imageCacheName,
        ));
      } else {
        // This future did not synchronously complete.
        completer.complete(_SizeAwareCacheKey(
          key,
          compressionRatio,
          maxBytes,
          width,
          height,
          cacheRawData,
          imageCacheName,
        ));
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
    double? compressionRatio,
    int? maxBytes,
    int? targetWidth,
    int? targetHeight,
  }) async {
    final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(list);
    final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);
    if (compressionRatio != null) {
      final _IntSize size = _resize(
        descriptor.width,
        descriptor.height,
        (descriptor.width * descriptor.height * 4 * compressionRatio).toInt(),
      );
      targetWidth = size.width;
      targetHeight = size.height;
    } else if (maxBytes != null) {
      final _IntSize size = _resize(
        descriptor.width,
        descriptor.height,
        maxBytes,
      );
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
    return descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
  }

  /// Calculate fittest size.
  /// [width] The image's original width.
  /// [height] The image's original height.
  /// [maxBytes] The size that image will resize to.
  ///
  _IntSize _resize(int width, int height, int maxBytes) {
    final double ratio = width / height;
    final int maxSize_1_4 = maxBytes >> 2;
    final int targetHeight = sqrt(maxSize_1_4 / ratio).floor();
    final int targetWidth = (ratio * targetHeight).floor();
    return _IntSize(targetWidth, targetHeight);
  }
}

@immutable
class _IntSize {
  const _IntSize(this.width, this.height);

  final int width;
  final int height;
}

@immutable
class _SizeAwareCacheKey {
  const _SizeAwareCacheKey(
    this.providerCacheKey,
    this.compressionRatio,
    this.maxBytes,
    this.width,
    this.height,
    this.cacheRawData,
    this.imageCacheName,
  );

  final Object providerCacheKey;

  final int? maxBytes;

  final double? compressionRatio;

  final int? width;

  final int? height;

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.

  final String? imageCacheName;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _SizeAwareCacheKey &&
        other.providerCacheKey == providerCacheKey &&
        other.maxBytes == maxBytes &&
        other.compressionRatio == compressionRatio &&
        other.width == width &&
        other.height == height &&
        cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => hashValues(
        providerCacheKey,
        maxBytes,
        compressionRatio,
        width,
        height,
        cacheRawData,
        imageCacheName,
      );
}
