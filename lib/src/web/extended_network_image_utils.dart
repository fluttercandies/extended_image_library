import 'dart:async';

import '../extended_image_utils.dart';

/// clear the disk cache directory then return if it succeed.
///  <param name="duration">timespan to compute whether file has expired or not</param>
Future<bool> clearDiskCachedImages({Duration? duration}) async {
  return true;
}

/// clear the disk cache image then return if it succeed.
///  <param name="url">clear specific one</param>
Future<bool> clearDiskCachedImage(String url) async {
  return true;
}

///get the local file of the cached image
Future<String?> getCachedImageFilePath(String url) async {
  return null;
}

/// Getting cache data, if cache empty - callback with save
Future<GetOrSetCacheImageResult> getOrSetCachedImage(String url) async {
  return GetOrSetCacheImageResult();
}

///check if the image exists in cache
Future<bool> cachedImageExists(String url) async {
  return false;
}

/// get total size of cached image
Future<int> getCachedSizeBytes() async {
  return 0;
}
