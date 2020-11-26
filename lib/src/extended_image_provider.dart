import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/painting.dart';

class ExtendedImageProvider {
  //raw data of image
  Uint8List get rawImageData => imageData.data;
  final RawImageData imageData = RawImageData();

  ///override this method, so that you can handle raw image data,
  ///for example, compress
  Future<ui.Codec> instantiateImageCodec(
      Uint8List data, DecoderCallback decode) async {
    imageData.data = data;
    return await decode(data);
  }
}

class RawImageData {
  Uint8List data;
}
