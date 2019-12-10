import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui show Codec;
import 'extended_image_provider.dart';

class ExtendedExactAssetImageProvider extends ExactAssetImage
    with ExtendedImageProvider {
  ExtendedAssetBundleImageKey _extendedAssetBundleImageKey;
  ExtendedExactAssetImageProvider(
    String assetName, {
    AssetBundle bundle,
    String package,
    double scale = 1.0,
  }) : super(assetName, bundle: bundle, package: package, scale: scale);

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<ExtendedAssetBundleImageKey> completer =
        Completer<ExtendedAssetBundleImageKey>();
    super.obtainKey(configuration).then((value) {
      if (value != null) {
        _extendedAssetBundleImageKey = ExtendedAssetBundleImageKey(
            bundle: value.bundle, scale: value.scale, name: value.name);
      }
      completer.complete(_extendedAssetBundleImageKey);
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
    final ByteData data = await key.bundle.load(key.name);
    if (data == null) throw 'Unable to read data';
    var result = data.buffer.asUint8List();
    _extendedAssetBundleImageKey.data.value = result;
    return await instantiateImageCodec(result, decode);
  }

  @override
  Uint8List get rawImageData =>
      super.rawImageData ?? _extendedAssetBundleImageKey?.data?.value;
}

class ExtendedAssetImageProvider extends AssetImage with ExtendedImageProvider {
  ExtendedAssetBundleImageKey _extendedAssetBundleImageKey;
  ExtendedAssetImageProvider(
    String assetName, {
    AssetBundle bundle,
    String package,
  }) : super(assetName, bundle: bundle, package: package);

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<ExtendedAssetBundleImageKey> completer =
        Completer<ExtendedAssetBundleImageKey>();
    super.obtainKey(configuration).then((value) {
      if (value != null) {
        _extendedAssetBundleImageKey = ExtendedAssetBundleImageKey(
            bundle: value.bundle, scale: value.scale, name: value.name);
      }
      completer.complete(_extendedAssetBundleImageKey);
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
    final ByteData data = await key.bundle.load(key.name);
    if (data == null) throw 'Unable to read data';
    var result = data.buffer.asUint8List();
    _extendedAssetBundleImageKey.data.value = result;
    return await instantiateImageCodec(result, decode);
  }

  @override
  Uint8List get rawImageData =>
      super.rawImageData ?? _extendedAssetBundleImageKey?.data?.value;
}

class ExtendedAssetBundleImageKey extends AssetBundleImageKey {
  final _Data data;
  ExtendedAssetBundleImageKey({
    @required AssetBundle bundle,
    @required String name,
    @required double scale,
  })  : data = _Data(),
        assert(bundle != null),
        assert(name != null),
        assert(scale != null),
        super(bundle: bundle, name: name, scale: scale);

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ExtendedAssetBundleImageKey typedOther = other;
    var result = bundle == typedOther.bundle &&
        name == typedOther.name &&
        scale == typedOther.scale;
    if (result) {
      data.value ??= typedOther.data.value;
    }
    return result;
  }

  @override
  int get hashCode => hashValues(bundle, name, scale);
}

class _Data {
  Uint8List value;
  _Data();
}
