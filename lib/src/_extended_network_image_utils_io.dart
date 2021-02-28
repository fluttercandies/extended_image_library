import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'extended_network_image_provider.dart';

const String cacheImageFolderName = 'cacheimage';

String keyToMd5(String key) => md5.convert(utf8.encode(key)).toString();

/// Clear the disk cache directory then return if it succeed.
Future<bool> clearDiskCachedImages({Duration duration}) async {
  try {
    final Directory cacheImagesDirectory = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));
    if (cacheImagesDirectory.existsSync()) {
      if (duration == null) {
        cacheImagesDirectory.deleteSync(recursive: true);
      } else {
        final DateTime now = DateTime.now();
        for (final FileSystemEntity file in cacheImagesDirectory.listSync()) {
          final FileStat fs = file.statSync();
          if (now.subtract(duration).isAfter(fs.changed)) {
            file.deleteSync(recursive: true);
          }
        }
      }
    }
  } catch (_) {
    return false;
  }
  return true;
}

/// Clear the disk cache image then return if it succeed.
Future<bool> clearDiskCachedImage(String url, {String cacheKey}) async {
  try {
    final File file = await getCachedImageFile(url, cacheKey: cacheKey);
    if (file != null) {
      await file.delete(recursive: true);
    }
  } catch (_) {
    return false;
  }
  return true;
}

/// Get the local file of the cached image

Future<File> getCachedImageFile(String url, {String cacheKey}) async {
  try {
    final String key = cacheKey ?? keyToMd5(url);
    final Directory cacheImagesDirectory = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));
    if (cacheImagesDirectory.existsSync()) {
      for (final FileSystemEntity file in cacheImagesDirectory.listSync()) {
        if (file.path.endsWith(key)) {
          return File(file.path);
        }
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Check if the image exists in cache
Future<bool> cachedImageExists(String url, {String cacheKey}) async {
  try {
    final String key = cacheKey ?? keyToMd5(url);
    final Directory cacheImagesDirectory = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));
    if (cacheImagesDirectory.existsSync()) {
      for (final FileSystemEntity file in cacheImagesDirectory.listSync()) {
        if (file.path.endsWith(key)) {
          return true;
        }
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

/// Clear all of image in memory
void clearMemoryImageCache() {
  PaintingBinding.instance.imageCache.clear();
}

/// get ImageCache
ImageCache getMemoryImageCache() {
  return PaintingBinding.instance.imageCache;
}

/// Get network image data from cached
Future<Uint8List> getNetworkImageData(
  String url, {
  bool useCache = true,
  StreamController<ImageChunkEvent> chunkEvents,
  String cacheKey,
}) async {
  return ExtendedNetworkImageProvider(url, cache: useCache, cacheKey: cacheKey)
      .getNetworkImageData(
    chunkEvents: chunkEvents,
  );
}

/// Get total size of cached image
Future<int> getCachedSizeBytes() async {
  int size = 0;
  final Directory cacheImagesDirectory = Directory(
      join((await getTemporaryDirectory()).path, cacheImageFolderName));
  if (cacheImagesDirectory.existsSync()) {
    for (final FileSystemEntity file in cacheImagesDirectory.listSync()) {
      size += file.statSync().size;
    }
  }
  return size;
}

/// Get the local file path of the cached image
Future<String> getCachedImageFilePath(String url, {String cacheKey}) async {
  final File file = await getCachedImageFile(url, cacheKey: cacheKey);
  return file?.path;
}
