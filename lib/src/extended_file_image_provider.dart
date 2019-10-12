import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'dart:ui' as ui show Codec;

import 'extended_image_provider.dart';

class ExtendedFileImageProvider extends FileImage with ExtendedImageProvider {
  ExtendedFileImageProvider(File file, {double scale = 1.0})
      : super(file, scale: scale);
  @override
  ImageStreamCompleter load(FileImage key) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('Path: ${file?.path}');
      },
    );
  }

  Future<ui.Codec> _loadAsync(FileImage key) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.lengthInBytes == 0) return null;

    return await instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ExtendedFileImageProvider typedOther = other;
    bool result =
        file?.path == typedOther.file?.path && scale == typedOther.scale;
    if (result) {
      rawImageData ??= typedOther.rawImageData;
    }
    return result;
  }

  @override
  int get hashCode => hashValues(file?.path, scale);
}
