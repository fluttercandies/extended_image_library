import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http_client_helper/http_client_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'extended_image_provider.dart';
import 'extended_network_image_provider.dart' as image_provider;
import 'platform.dart';

class ExtendedNetworkImageProvider
    extends ImageProvider<image_provider.ExtendedNetworkImageProvider>
    with ExtendedImageProvider<image_provider.ExtendedNetworkImageProvider>
    implements image_provider.ExtendedNetworkImageProvider {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments must not be null.
  ExtendedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.cache = false,
    this.retries = 3,
    this.timeLimit,
    this.timeRetry = const Duration(milliseconds: 100),
    this.cacheKey,
    this.printError = true,
    this.cacheRawData = false,
    this.cancelToken,
    this.imageCacheName,
    this.cacheMaxAge,
  });

  static final Map<String, String> _lockCache = <String, String>{};

  // Do not access this field directly; use [_httpClient] instead.
  // We set `autoUncompress` to false to ensure that we can trust the value of
  // the `Content-Length` HTTP header. We automatically uncompress the content
  // in our call to [consolidateHttpClientResponseBytes].
  static final HttpClient _sharedHttpClient = HttpClient()
    ..autoUncompress = false;

  static HttpClient get httpClient {
    HttpClient client = _sharedHttpClient;
    assert(() {
      if (debugNetworkImageHttpClientProvider != null) {
        client = debugNetworkImageHttpClientProvider!();
      }
      return true;
    }());
    return client;
  }

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  /// The time limit to request image
  @override
  final Duration? timeLimit;

  /// The time to retry to request
  @override
  final int retries;

  /// The time duration to retry to request
  @override
  final Duration timeRetry;

  /// Whether cache image to local
  @override
  final bool cache;

  /// The URL from which the image will be fetched.
  @override
  final String url;

  /// The scale to place in the [ImageInfo] object of the image.
  @override
  final double scale;

  /// The HTTP headers that will be used with [HttpClient.get] to fetch image from network.
  @override
  final Map<String, String>? headers;

  /// The token to cancel network request
  @override
  final CancellationToken? cancelToken;

  /// Custom cache key
  @override
  final String? cacheKey;

  /// print error
  @override
  final bool printError;

  /// The max duration to cache image.
  /// After this time the cache is expired and the image is reloaded.
  @override
  final Duration? cacheMaxAge;

  @override
  ImageStreamCompleter load(
      image_provider.ExtendedNetworkImageProvider key, DecoderCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(
        key as ExtendedNetworkImageProvider,
        chunkEvents,
        decode,
      ),
      scale: key.scale,
      debugLabel: key.url,
      chunkEvents: chunkEvents.stream,
      informationCollector: () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<image_provider.ExtendedNetworkImageProvider>(
              'Image key', key),
        ];
      },
    );
  }

  @override
  Future<ExtendedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<ExtendedNetworkImageProvider>(this);
  }

  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
    bool includeLive = true,
  }) async {
    rawImageDataMap.remove(this);
    cache ??= this.imageCache;
    final ExtendedNetworkImageProvider key = await obtainKey(configuration);
    _lockCache.remove(key.url);
    return cache.evict(key, includeLive: includeLive);
  }

  Future<ui.Codec> _loadAsync(
    ExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) async {
    assert(key == this);
    final Uint8List? uint8list = await _(key.url, chunkEvents);
    if (uint8list == null) {
      return Future<ui.Codec>.error(StateError('Failed to load $url.'));
    }
    try {
      return await instantiateImageCodec(uint8list, decode);
    } catch (e) {
      if (printError) {
        print(e);
      }
      return Future<ui.Codec>.error(StateError('Failed to load $url.'));
    }
  }

  Future<Directory> _getCacheDir() async {
    final Directory dir = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _childFile(Directory parentDir, String fileName) {
    return File(join(parentDir.path, fileName));
  }

  Future<Uint8List?> _(
    String url,
    StreamController<ImageChunkEvent>? chunkEvents,
  ) async {
    final Uri uri = Uri.parse(url);

    final bool noCache = !cache;
    final HttpClientResponse? checkResp =
        await _retryRequest(uri, withBody: noCache);

    final String rawFileKey = cacheKey ?? keyToMd5(url);
    final Directory parentDir = await _getCacheDir();
    final File rawFile = _childFile(parentDir, rawFileKey);

    // if request error, use cache.
    if (checkResp == null || checkResp.statusCode != HttpStatus.ok) {
      if (rawFile.existsSync()) {
        return await rawFile.readAsBytes();
      }
      return null;
    }

    if (noCache) {
      return await _rw(checkResp, rawFile, null, chunkEvents: chunkEvents);
    }

    // consuming response.
    checkResp.listen(null);

    bool isExpired = false;
    final String? cacheControl =
        checkResp.headers.value(HttpHeaders.cacheControlHeader);
    if (cacheControl != null) {
      if (cacheControl.contains('no-store')) {
        // no cache, download now.
        return await _nrw(uri, rawFile, null, chunkEvents: chunkEvents);
      } else {
        String maxAgeKey = 'max-age';
        if (cacheControl.contains(maxAgeKey)) {
          // if exist s-maxage, override max-age, use cdn max-age
          if (cacheControl.contains('s-maxage')) {
            maxAgeKey = 's-maxage';
          }
          final String maxAgeStr = cacheControl
              .split(' ')
              .firstWhere((String str) => str.contains(maxAgeKey))
              .split('=')[1]
              .trim();
          final String seconds = RegExp(r'\d+').stringMatch(maxAgeStr)!;
          final int maxAge = int.parse(seconds) * 1000;
          final String newFlag =
              '${checkResp.headers.value(HttpHeaders.etagHeader).toString()}_${checkResp.headers.value(HttpHeaders.lastModifiedHeader).toString()}';
          final File lockFile = _childFile(parentDir, '$rawFileKey.lock');
          String? lockStr = _lockCache[url];
          if (lockStr == null) {
            // never empty or blank.
            if (lockFile.existsSync()) {
              lockStr = await lockFile.readAsString();
            } else {
              await lockFile.create();
            }
          }
          final int millis = DateTime.now().millisecondsSinceEpoch;
          if (lockStr != null) {
            //never empty or blank
            final List<String> split = lockStr.split('@');
            final String flag = split[1];
            final int lastReqAt = int.parse(split[0]);
            if (flag != newFlag || lastReqAt + maxAge < millis) {
              isExpired = true;
            }
          }
          final String newLockStr = <dynamic>[millis, newFlag].join('@');
          _lockCache[url] = newLockStr;
          // we don't care lock str already written in file.
          lockFile.writeAsString(newLockStr);
        }
      }
    }
    if (!isExpired) {
      // if not expired and exist file, just return.
      if (rawFile.existsSync()) {
        if (cacheMaxAge != null) {
          final FileStat fs = rawFile.statSync();
          if (DateTime.now().subtract(cacheMaxAge!).isBefore(fs.changed)) {
            return await rawFile.readAsBytes();
          }
        } else {
          return await rawFile.readAsBytes();
        }
      }
    }

    final bool breakpointTransmission =
        checkResp.headers.value(HttpHeaders.acceptRangesHeader) == 'bytes' &&
            checkResp.contentLength > 0;
    final File tempFile = _childFile(parentDir, '$rawFileKey.temp');
    // if not expired && is support breakpoint transmission && temp file exists
    if (!isExpired && breakpointTransmission && tempFile.existsSync()) {
      final int length = await tempFile.length();
      final HttpClientResponse? resp = await _retryRequest(
        uri,
        beforeRequest: (HttpClientRequest req) {
          req.headers.add(HttpHeaders.rangeHeader, 'bytes=$length-');
          final String? flag =
              checkResp.headers.value(HttpHeaders.etagHeader) ??
                  checkResp.headers.value(HttpHeaders.lastModifiedHeader);
          if (flag != null) {
            req.headers.add(HttpHeaders.ifRangeHeader, flag);
          }
        },
      );
      if (resp == null) {
        return null;
      }
      if (resp.statusCode == HttpStatus.partialContent) {
        // is ok, continue download.
        return await _rw(
          resp,
          rawFile,
          tempFile,
          chunkEvents: chunkEvents,
          loadedLength: length,
          fileMode: FileMode.append,
        );
      } else if (resp.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        // 416 Requested Range Not Satisfiable
        return await _nrw(
          uri,
          rawFile,
          tempFile,
          chunkEvents: chunkEvents,
        );
      } else if (resp.statusCode == HttpStatus.ok) {
        return await _rw(resp, rawFile, tempFile, chunkEvents: chunkEvents);
      } else {
        // request error.
        resp.listen(null);
        return null;
      }
    } else {
      return await _nrw(
        uri,
        rawFile,
        tempFile,
        chunkEvents: chunkEvents,
      );
    }
  }

  Future<Uint8List?> _nrw(
    Uri uri,
    File rawFile,
    File? tempFile, {
    StreamController<ImageChunkEvent>? chunkEvents,
  }) async {
    final HttpClientResponse? resp = await _retryRequest(uri);
    return resp == null
        ? null
        : await _rw(resp, rawFile, tempFile, chunkEvents: chunkEvents);
  }

  late StreamSubscription<List<int>> _subscription;

  Future<Uint8List> _rw(
    HttpClientResponse response,
    File rawFile,
    File? tempFile, {
    StreamController<ImageChunkEvent>? chunkEvents,
    int loadedLength = 0,
    FileMode fileMode = FileMode.write,
  }) async {
    final Completer<Uint8List> completer = Completer<Uint8List>();
    if (tempFile != null) {
      int received = loadedLength;
      final bool compressed = response.compressionState ==
          HttpClientResponseCompressionState.compressed;
      final int? total = compressed || response.contentLength < 0
          ? null
          : response.contentLength;
      final RandomAccessFile raf = await tempFile.open(mode: fileMode);
      _subscription = response.listen(
        (List<int> bytes) {
          _subscription.pause();
          raf.setPositionSync(received);
          raf.writeFrom(bytes).then((RandomAccessFile _raf) {
            received += bytes.length;
            chunkEvents?.add(ImageChunkEvent(
              cumulativeBytesLoaded: received,
              expectedTotalBytes: total,
            ));
            _subscription.resume();
          }).catchError((dynamic err, StackTrace stackTrace) async {
            await _subscription.cancel();
          });
        },
        onDone: () async {
          try {
            await raf.close();
            Uint8List buffer = await tempFile.readAsBytes();
            if (compressed) {
              final List<int> convert = gzip.decoder.convert(buffer);
              buffer = Uint8List.fromList(convert);
              await tempFile.writeAsBytes(convert);
              chunkEvents?.add(ImageChunkEvent(
                cumulativeBytesLoaded: buffer.length,
                expectedTotalBytes: buffer.length,
              ));
            }
            await tempFile.rename(rawFile.path);
            completer.complete(buffer);
          } catch (e) {
            completer.completeError(e);
          }
        },
        onError: (Object err, StackTrace stackTrace) async {
          try {
            await raf.close();
          } finally {
            completer.completeError(err, stackTrace);
          }
        },
        cancelOnError: true,
      );
    } else {
      final Uint8List bytes = await consolidateHttpClientResponseBytes(
        response,
        onBytesReceived: chunkEvents != null
            ? (int cumulative, int? total) {
                chunkEvents.add(ImageChunkEvent(
                  cumulativeBytesLoaded: cumulative,
                  expectedTotalBytes: total,
                ));
              }
            : null,
      );
      completer.complete(bytes);
    }
    return completer.future;
  }

  Future<HttpClientResponse> _createNewRequest(
    Uri uri, {
    bool withBody = true,
    _BeforeRequest? beforeRequest,
  }) async {
    final HttpClientRequest request =
        await (withBody ? httpClient.getUrl(uri) : httpClient.headUrl(uri));
    headers?.forEach((String key, Object value) {
      request.headers.add(key, value);
    });
    beforeRequest?.call(request);
    final HttpClientResponse response = await request.close();
    if (timeLimit != null) {
      response.timeout(
        timeLimit!,
      );
    }
    return response;
  }

  Future<HttpClientResponse?> _retryRequest(
    Uri uri, {
    bool withBody = true,
    _BeforeRequest? beforeRequest,
  }) async {
    cancelToken?.throwIfCancellationRequested();
    return await RetryHelper.tryRun<HttpClientResponse>(
      () {
        return CancellationTokenSource.register(
          cancelToken,
          _createNewRequest(
            uri,
            withBody: withBody,
            beforeRequest: beforeRequest,
          ),
        );
      },
      cancelToken: cancelToken,
      timeRetry: timeRetry,
      retries: retries,
    );
  }

  /// Get network image data from cached
  @override
  Future<Uint8List?> getNetworkImageData({
    StreamController<ImageChunkEvent>? chunkEvents,
  }) async {
    return await _(url, chunkEvents);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedNetworkImageProvider &&
        url == other.url &&
        scale == other.scale &&
        cacheRawData == other.cacheRawData &&
        timeLimit == other.timeLimit &&
        cancelToken == other.cancelToken &&
        timeRetry == other.timeRetry &&
        cache == other.cache &&
        cacheKey == other.cacheKey &&
        headers == other.headers &&
        retries == other.retries &&
        imageCacheName == other.imageCacheName &&
        cacheMaxAge == other.cacheMaxAge;
  }

  @override
  int get hashCode => hashValues(
        url,
        scale,
        cacheRawData,
        timeLimit,
        cancelToken,
        timeRetry,
        cache,
        cacheKey,
        headers,
        retries,
        imageCacheName,
        cacheMaxAge,
      );

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}

typedef _BeforeRequest = void Function(HttpClientRequest request);
