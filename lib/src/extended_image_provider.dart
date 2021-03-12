import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/painting.dart';

/// The cached raw image data
Map<ExtendedImageProvider<dynamic>, Uint8List> rawImageDataMap =
    <ExtendedImageProvider<dynamic>, Uint8List>{};

mixin ExtendedImageProvider<T extends Object> on ImageProvider<T> {
  // /// Whether cache raw data if you need to get raw data directly.
  // /// For example, we need raw image data to edit,
  // /// but [ui.Image.toByteData()] is very slow. So we cache the image
  // /// data here.
  // ///
  // bool get cacheRawData;

  /// The raw data of image
  Uint8List get rawImageData {
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
    rawImageDataMap[this] = data;
    return await decode(data);
  }

  /// Evicts an entry from the image cache.
  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) {
    rawImageDataMap.remove(this);
    return super.evict(cache: cache, configuration: configuration);
  }
}
