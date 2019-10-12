import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui show Codec;
import 'extended_image_provider.dart';

class ExtendedExactAssetImageProvider extends ExactAssetImage
    with ExtendedImageProvider {
  ExtendedExactAssetImageProvider(
    String assetName, {
    AssetBundle bundle,
    String package,
    double scale = 1.0,
  }) : super(assetName, bundle: bundle, package: package, scale: scale);

  @override
  ImageStreamCompleter load(AssetBundleImageKey key) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AssetBundleImageKey>('Image key', key);
      },
    );
  }

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<ui.Codec> _loadAsync(AssetBundleImageKey key) async {
    final ByteData data = await key.bundle.load(key.name);
    if (data == null) throw 'Unable to read data';
    return await instantiateImageCodec(data.buffer.asUint8List());
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ExtendedExactAssetImageProvider typedOther = other;
    bool result = keyName == typedOther.keyName &&
        scale == typedOther.scale &&
        bundle == typedOther.bundle;
    if (result) {
      rawImageData ??= typedOther.rawImageData;
    }
    return result;
  }

  @override
  int get hashCode => hashValues(keyName, scale, bundle);
}

class ExtendedAssetImageProvider extends AssetImage with ExtendedImageProvider {
  ExtendedAssetImageProvider(
    String assetName, {
    AssetBundle bundle,
    String package,
  }) : super(assetName, bundle: bundle, package: package);

  @override
  ImageStreamCompleter load(AssetBundleImageKey key) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AssetBundleImageKey>('Image key', key);
      },
    );
  }

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<ui.Codec> _loadAsync(AssetBundleImageKey key) async {
    final ByteData data = await key.bundle.load(key.name);
    if (data == null) throw 'Unable to read data';
    return await instantiateImageCodec(data.buffer.asUint8List());
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ExtendedAssetImageProvider typedOther = other;
    bool result = keyName == typedOther.keyName && bundle == typedOther.bundle;
    if (result) {
      rawImageData ??= typedOther.rawImageData;
    }
    return result;
  }

  @override
  int get hashCode => hashValues(keyName, bundle);
}
