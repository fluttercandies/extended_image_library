import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/painting.dart';


class ExtendedImageProvider {
  //raw data of image
  Uint8List rawImageData;

  ///override this method, so that you can handle raw image data,
  ///for example, compress
  Future<ui.Codec> instantiateImageCodec(
      Uint8List data, DecoderCallback decode) async {
    rawImageData = data;
    return await decode(data);
  }
}
