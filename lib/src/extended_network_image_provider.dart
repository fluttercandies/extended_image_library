import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:http_client_helper/http_client_helper.dart';
import '_network_image_io.dart' if (dart.library.html) '_network_image_web.dart'
    as network_image;

abstract class ExtendedNetworkImageProvider
    extends ImageProvider<ExtendedNetworkImageProvider> {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  factory ExtendedNetworkImageProvider(
    String url, {
    double scale,
    Map<String, String> headers,
    bool cache,
    int retries,
    Duration timeLimit,
    Duration timeRetry,
    CancellationToken cancelToken,
  }) = network_image.ExtendedNetworkImageProvider;

  ///time Limit to request image
  Duration get timeLimit;

  ///the time to retry to request
  int get retries;

  ///the time duration to retry to request
  Duration get timeRetry;

  ///whether cache image to local
  bool get cache;

  /// The URL from which the image will be fetched.
  String get url;

  /// The scale to place in the [ImageInfo] object of the image.
  double get scale;

  /// The HTTP headers that will be used with [HttpClient.get] to fetch image from network.
  Map<String, String> get headers;

  ///token to cancel network request
  CancellationToken get cancelToken;

  @override
  ImageStreamCompleter load(
      ExtendedNetworkImageProvider key, DecoderCallback decode);

  ///get network image data from cached
  Future<Uint8List> getNetworkImageData({
    StreamController<ImageChunkEvent> chunkEvents,
  });

  ///HttpClient for network, it's null on web
  static dynamic get httpClient =>
      network_image.ExtendedNetworkImageProvider.httpClient;
}
