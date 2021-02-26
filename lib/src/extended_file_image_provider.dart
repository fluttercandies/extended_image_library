import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/widgets.dart';

import 'extended_image_provider.dart';

class ExtendedFileImageProvider extends FileImage with ExtendedImageProvider {
  ExtendedFileImageProvider(
    File file, {
    double scale = 1.0,
  }) : super(file, scale: scale);

  @override
  ImageStreamCompleter load(FileImage key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () sync* {
        yield ErrorDescription('Path: ${file.path}');
      },
    );
  }

  Future<ui.Codec> _loadAsync(FileImage key, DecoderCallback decode) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.lengthInBytes == 0) {
      // The file may become available later.
      PaintingBinding.instance!.imageCache!.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }

    return await instantiateImageCodec(bytes, decode);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is ExtendedFileImageProvider &&
        file.path == other.file.path &&
        scale == other.scale) {
      imageData.data ??= other.rawImageData;
      return true;
    }
    return false;
  }

  @override
  int get hashCode => hashValues(file.path, scale);
}
