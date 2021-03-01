import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'extended_image_provider.dart';

class ExtendedExactAssetImageProvider extends ExactAssetImage
    with ExtendedImageProvider<AssetBundleImageKey> {
  const ExtendedExactAssetImageProvider(
    String assetName, {
    AssetBundle bundle,
    String package,
    double scale = 1.0,
  }) : super(assetName, bundle: bundle, package: package, scale: scale);

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    final Completer<AssetBundleImageKey> completer =
        Completer<AssetBundleImageKey>();
    super.obtainKey(configuration).then((AssetBundleImageKey value) {
      if (value != null) {
        completer.complete(AssetBundleImageKey(
            bundle: value.bundle, scale: value.scale, name: value.name));
      }
    });
    return completer.future;
  }

  @override
  ImageStreamCompleter load(AssetBundleImageKey key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
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
  Future<ui.Codec> _loadAsync(
      AssetBundleImageKey key, DecoderCallback decode) async {
    ByteData data;
    // Hot reload/restart could change whether an asset bundle or key in a
    // bundle are available, or if it is a network backed bundle.
    try {
      data = await key.bundle.load(key.name);
    } on FlutterError {
      PaintingBinding.instance?.imageCache?.evict(key);
      rethrow;
    }
    final Uint8List result = data.buffer.asUint8List();
    return await instantiateImageCodec(result, decode);
  }
}

class ExtendedAssetImageProvider extends AssetImage
    with ExtendedImageProvider<AssetBundleImageKey> {
  const ExtendedAssetImageProvider(
    String assetName, {
    AssetBundle bundle,
    String package,
  }) : super(assetName, bundle: bundle, package: package);
  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    final Completer<AssetBundleImageKey> completer =
        Completer<AssetBundleImageKey>();
    super.obtainKey(configuration).then((AssetBundleImageKey value) {
      if (value != null) {
        completer.complete(AssetBundleImageKey(
            bundle: value.bundle, scale: value.scale, name: value.name));
      }
    });
    return completer.future;
  }

  @override
  ImageStreamCompleter load(AssetBundleImageKey key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
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
  Future<ui.Codec> _loadAsync(
      AssetBundleImageKey key, DecoderCallback decode) async {
    ByteData data;
    // Hot reload/restart could change whether an asset bundle or key in a
    // bundle are available, or if it is a network backed bundle.
    try {
      data = await key.bundle.load(key.name);
    } on FlutterError {
      PaintingBinding.instance?.imageCache?.evict(key);
      rethrow;
    }
    final Uint8List result = data.buffer.asUint8List();
    return await instantiateImageCodec(result, decode);
  }
}

class ExtendedAssetBundleImageKey extends AssetBundleImageKey {
  const ExtendedAssetBundleImageKey({
    @required AssetBundle bundle,
    @required String name,
    @required double scale,
  })  : assert(bundle != null),
        assert(name != null),
        assert(scale != null),
        super(bundle: bundle, name: name, scale: scale);
  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is ExtendedAssetBundleImageKey &&
        bundle == other.bundle &&
        name == other.name &&
        scale == other.scale) {
      return true;
    }

    return false;
  }

  @override
  int get hashCode => hashValues(bundle, name, scale);
}
