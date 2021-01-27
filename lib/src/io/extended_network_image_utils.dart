import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../extended_image_utils.dart';

const String cacheImageFolderName = 'cacheimage';

/// clear the disk cache directory then return if it succeed.
///  <param name="duration">timespan to compute whether file has expired or not</param>
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
            //print("remove expired cached image");
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

/// clear the disk cache image then return if it succeed.
///  <param name="url">clear specific one</param>
Future<bool> clearDiskCachedImage(String url) async {
  try {
    final String filePath = await getCachedImageFilePath(url);
    final File file = File(filePath);
    if (file != null) {
      await file.delete(recursive: true);
    }
  } catch (_) {
    return false;
  }
  return true;
}

///get the local file of the cached image
Future<String> getCachedImageFilePath(String url) async {
  try {
    final String key = keyToMd5(url);
    final Directory cacheImagesDirectory = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));
    if (cacheImagesDirectory.existsSync()) {
      for (final FileSystemEntity file in cacheImagesDirectory.listSync()) {
        if (file.path.endsWith(key)) {
          return file.path;
        }
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Getting cache data, if cache empty - callback with save
Future<GetOrSetCacheImageResult> getOrSetCachedImage(String url) async {
  try {
    final String key = keyToMd5(url);
    final Directory cacheImagesDirectory = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));

    final File cacheFile = File(join(cacheImagesDirectory.path, key));
    //exist, try to find cache image file
    if (cacheFile.existsSync()) {
      return GetOrSetCacheImageResult()..data = await cacheFile.readAsBytes();
    } else {
      return GetOrSetCacheImageResult()
        ..save = (Uint8List data) async {
          //create folder
          if (!cacheImagesDirectory.existsSync()) {
            await cacheImagesDirectory.create();
          }

          return cacheFile.writeAsBytes(data);
        };
    }
  } catch (_) {
    return GetOrSetCacheImageResult();
  }
}

///check if the image exists in cache
Future<bool> cachedImageExists(String url) async {
  try {
    final String key = keyToMd5(url);
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

/// get total size of cached image
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
