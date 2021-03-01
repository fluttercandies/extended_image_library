import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/painting.dart';

/// cache raw image data for edit
Map<ExtendedImageProvider<dynamic>, Uint8List> rawImageDataMap =
    <ExtendedImageProvider<dynamic>, Uint8List>{};

mixin ExtendedImageProvider<T> on ImageProvider<T> {
  //raw data of image
  Uint8List get rawImageData {
    final Uint8List raw = rawImageDataMap[this];
    assert(
      raw != null,
      'raw image data is not already now!',
    );
    return raw;
  }

  ///override this method, so that you can handle raw image data,
  ///for example, compress
  Future<ui.Codec> instantiateImageCodec(
      Uint8List data, DecoderCallback decode) async {
    rawImageDataMap[this] = data;
    return await decode(data);
  }

  @override
  Future<bool> evict(
      {ImageCache cache,
      ImageConfiguration configuration = ImageConfiguration.empty}) {
    rawImageDataMap.remove(this);
    return super.evict(cache: cache, configuration: configuration);
  }
}
