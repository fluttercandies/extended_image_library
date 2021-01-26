import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';

String keyToMd5(String key) => md5.convert(utf8.encode(key)).toString();

///clear all of image in memory
void clearMemoryImageCache() {
  PaintingBinding.instance.imageCache.clear();
}

/// get ImageCache
ImageCache getMemoryImageCache() {
  return PaintingBinding.instance.imageCache;
}

/// get or set image cache result for image provider
class GetOrSetCacheImageResult {
  Uint8List data;
  Future<void> Function(Uint8List data) save = (_) async {};
}
