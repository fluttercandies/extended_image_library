import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http_client_helper/http_client_helper.dart';
import '../extended_image_provider.dart';
import '../extended_image_utils.dart';
import '../extended_network_image_provider.dart' as image_provider;
import 'extended_network_image_utils.dart'
    if (dart.library.html) '_extended_network_image_utils_web.dart'
    as network_utils;

class ExtendedNetworkImageProvider
    extends ImageProvider<image_provider.ExtendedNetworkImageProvider>
    with ExtendedImageProvider
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
    CancellationToken cancelToken,
  })  : assert(url != null),
        assert(scale != null),
        cancelToken = cancelToken ?? CancellationToken();

  ///time limit to request image
  @override
  final Duration timeLimit;

  ///the time to retry to request
  @override
  final int retries;

  ///the time duration to retry to request
  @override
  final Duration timeRetry;

  ///whether cache image to local
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
  final Map<String, String> headers;

  ///token to cancel network request
  @override
  final CancellationToken cancelToken;

//  /// cancel network request by extended image
//  /// if false, cancel by user
//  final bool autoCancel;

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

  Future<ui.Codec> _loadAsync(
      ExtendedNetworkImageProvider key,
      StreamController<ImageChunkEvent> chunkEvents,
      DecoderCallback decode) async {
    assert(key == this);
    ui.Codec result;
    if (cache) {
      try {
        final Uint8List data = await _loadCache(
          key,
          chunkEvents,
          key.url,
        );
        if (data != null) {
          result = await instantiateImageCodec(data, decode);
        }
      } catch (e) {
        print(e);
      }
    }

    if (result == null) {
      try {
        final Uint8List data = await _loadNetwork(
          key,
          chunkEvents,
        );
        if (data != null) {
          result = await instantiateImageCodec(data, decode);
        }
      } catch (e) {
        print(e);
      }
    }

    //Failed to load
    if (result == null) {
      //result = await ui.instantiateImageCodec(kTransparentImage);
      return Future<ui.Codec>.error(StateError('Failed to load $url.'));
    }

    return result;
  }

  ///get the image from cache folder.
  Future<Uint8List> _loadCache(
    ExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    String url,
  ) async {
    final GetOrSetCacheImageResult result =
        await network_utils.getOrSetCachedImage(url);
    if (result.data != null) {
      return result.data;
    }

    //load from network
    final Uint8List data = await _loadNetwork(
      key,
      chunkEvents,
    );
    if (data != null) {
      //cache image file
      result?.save(data);
      return data;
    }

    return null;
  }

  /// get the image from network.
  Future<Uint8List> _loadNetwork(
    ExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    try {
      final Uri resolved = Uri.base.resolve(key.url);
      final HttpClientResponse response = await _tryGetResponse(resolved);
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final Uint8List bytes = await consolidateHttpClientResponseBytes(
        response,
        onBytesReceived: chunkEvents != null
            ? (int cumulative, int total) {
                chunkEvents.add(ImageChunkEvent(
                  cumulativeBytesLoaded: cumulative,
                  expectedTotalBytes: total,
                ));
              }
            : null,
      );
      if (bytes.lengthInBytes == 0) {
        return Future<Uint8List>.error(
            StateError('NetworkImage is an empty file: $resolved'));
      }

      return bytes;
    } on OperationCanceledError catch (_) {
      print('User cancel request $url.');
      return Future<Uint8List>.error(StateError('User cancel request $url.'));
    } catch (e) {
      print(e);
    } finally {
      await chunkEvents?.close();
    }
    return null;
  }

  Future<HttpClientResponse> _getResponse(Uri resolved) async {
    final HttpClientRequest request = await httpClient.getUrl(resolved);
    headers?.forEach((String name, String value) {
      request.headers.add(name, value);
    });
    final HttpClientResponse response = await request.close();
    if (timeLimit != null) {
      response?.timeout(
        timeLimit,
      );
    }
    return response;
  }

  //http get with cancel, delay try again
  Future<HttpClientResponse> _tryGetResponse(
    Uri resolved,
  ) async {
    cancelToken?.throwIfCancellationRequested();
    return await RetryHelper.tryRun<HttpClientResponse>(
      () {
        return CancellationTokenSource.register(
          cancelToken,
          _getResponse(resolved),
        );
      },
      cancelToken: cancelToken,
      timeRetry: timeRetry,
      retries: retries,
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is ExtendedNetworkImageProvider &&
        url == other.url &&
        scale == other.scale) {
      imageData.data ??= other.rawImageData;
      return true;
    }
    return false;
  }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';

  @override

  ///get network image data from cached
  Future<Uint8List> getNetworkImageData({
    StreamController<ImageChunkEvent> chunkEvents,
  }) async {
    final String uId = keyToMd5(url);

    if (cache) {
      return await _loadCache(
        this,
        chunkEvents,
        uId,
      );
    }

    return await _loadNetwork(
      this,
      chunkEvents,
    );
  }

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
        client = debugNetworkImageHttpClientProvider();
      }
      return true;
    }());
    return client;
  }
}

///save network image to photo
//Future<bool> saveNetworkImageToPhoto(String url, {bool useCache: true}) async {
//  var data = await getNetworkImageData(url, useCache: useCache);
//  var filePath = await ImagePickerSaver.saveFile(fileData: data);
//  return filePath != null && filePath != "";
//}
