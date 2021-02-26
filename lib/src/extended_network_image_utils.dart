import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/painting.dart';

import 'extended_image_utils.dart';
import 'extended_network_image_provider.dart';
import 'io/extended_network_image_utils.dart'
    if (dart.library.html) '_extended_network_image_utils_web.dart' as utils;

/// clear the disk cache directory then return if it succeed.
///  <param name="duration">timespan to compute whether file has expired or not</param>
Future<bool> clearDiskCachedImages({Duration? duration}) async {
  return utils.clearDiskCachedImages(duration: duration);
}

/// clear the disk cache image then return if it succeed.
///  <param name="url">clear specific one</param>
Future<bool> clearDiskCachedImage(String url) async {
  return utils.clearDiskCachedImage(url);
}

///get the local file of the cached image
Future<String?> getCachedImageFilePath(String url) async {
  return utils.getCachedImageFilePath(url);
}

/// Getting cache data, if cache empty - callback with save
Future<GetOrSetCacheImageResult> getOrSetCachedImage(String url) async {
  return utils.getOrSetCachedImage(url);
}

///check if the image exists in cache
Future<bool> cachedImageExists(String url) async {
  return utils.cachedImageExists(url);
}

/// get total size of cached image
Future<int> getCachedSizeBytes() async {
  return utils.getCachedSizeBytes();
}

/// get network image data from cached
Future<Uint8List?> getNetworkImageData(
  String url, {
  bool useCache = true,
  StreamController<ImageChunkEvent>? chunkEvents,
}) async {
  return ExtendedNetworkImageProvider(url, cache: useCache).getNetworkImageData(
    chunkEvents: chunkEvents,
  );
}
