import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:extended_image_library/src/extended_image_provider.dart';
import 'package:flutter/widgets.dart';

class ExtendedMemoryImageProvider extends MemoryImage
    with ExtendedImageProvider<MemoryImage> {
  const ExtendedMemoryImageProvider(
    Uint8List bytes, {
    double scale = 1.0,
    this.cacheRawData = false,
  }) : super(bytes, scale: scale);

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  @override
  ImageStreamCompleter load(MemoryImage key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
    );
  }

  Future<ui.Codec> _loadAsync(MemoryImage key, DecoderCallback decode) {
    assert(key == this);
    return instantiateImageCodec(bytes, decode);
  }

  @override
  Uint8List get rawImageData => bytes;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedMemoryImageProvider &&
        other.bytes == bytes &&
        other.scale == scale &&
        cacheRawData == other.cacheRawData;
  }

  @override
  int get hashCode => hashValues(
        bytes.hashCode,
        scale,
        cacheRawData,
      );
}
