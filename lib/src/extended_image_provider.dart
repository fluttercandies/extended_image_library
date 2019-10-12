import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

class ExtendedImageProvider {
  //raw data of image
  Uint8List get rawImageData => _rawImageData;
  Uint8List _rawImageData;

  ///override this method, so that you can handle raw image data,
  ///for example, compress
  Future<ui.Codec> instantiateImageCodec(Uint8List data) async {
    _rawImageData = data;
    return await ui.instantiateImageCodec(data);
  }
}
