import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'dart:ui' as ui show Codec;

class ExtendedImageProvider {
  //raw data of image
  Uint8List _rawImageData;
  Uint8List get rawImageData => _rawImageData;
  set rawImageData(value) => _rawImageData = value;

  ///override this method, so that you can handle raw image data,
  ///for example, compress
  Future<ui.Codec> instantiateImageCodec(
      Uint8List data, DecoderCallback decode) async {
    _rawImageData = data;
    return await decode(data);
  }
}
