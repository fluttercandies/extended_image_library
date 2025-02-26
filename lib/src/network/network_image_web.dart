// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:extended_image_library/src/extended_image_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:http_client_helper/http_client_helper.dart';
import 'package:web/web.dart' as web;
import 'extended_network_image_provider.dart' as extended_image_provider;
// ignore: directives_ordering
import 'package:flutter/src/painting/image_provider.dart' as image_provider;

/// Creates a type for an overridable factory function for testing purposes.
typedef HttpRequestFactory = web.XMLHttpRequest Function();

/// The type for an overridable factory function for creating HTML elements to
/// display images, used for testing purposes.
typedef HtmlElementFactory = web.HTMLImageElement Function();

// Method signature for _loadAsync decode callbacks.
typedef _SimpleDecoderCallback =
    Future<ui.Codec> Function(ui.ImmutableBuffer buffer);

/// The default HTTP client.
web.XMLHttpRequest _httpClient() {
  return web.XMLHttpRequest();
}

/// Creates an overridable factory function.
@visibleForTesting
HttpRequestFactory httpRequestFactory = _httpClient;

/// Restores the default HTTP request factory.
@visibleForTesting
void debugRestoreHttpRequestFactory() {
  httpRequestFactory = _httpClient;
}

/// The default HTML element factory.
web.HTMLImageElement _imgElementFactory() {
  return web.document.createElement('img') as web.HTMLImageElement;
}

/// The factory function that creates HTML elements, can be overridden for
/// tests.
@visibleForTesting
HtmlElementFactory imgElementFactory = _imgElementFactory;

/// Restores the default HTML element factory.
@visibleForTesting
void debugRestoreImgElementFactory() {
  imgElementFactory = _imgElementFactory;
}

/// The web implementation of [image_provider.NetworkImage].
///
/// NetworkImage on the web does not support decoding to a specified size.
@immutable
class ExtendedNetworkImageProvider
    extends ImageProvider<extended_image_provider.ExtendedNetworkImageProvider>
    with
        ExtendedImageProvider<
          extended_image_provider.ExtendedNetworkImageProvider
        >
    implements extended_image_provider.ExtendedNetworkImageProvider {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  ExtendedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.cache = false,
    this.retries = 3,
    this.timeLimit,
    this.timeRetry = const Duration(milliseconds: 100),
    this.cancelToken,
    this.cacheKey,
    this.printError = true,
    this.cacheRawData = false,
    this.imageCacheName,
    this.cacheMaxAge,
    this.webHtmlElementStrategy = WebHtmlElementStrategy.never,
  });

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  @override
  final bool cache;

  @override
  final CancellationToken? cancelToken;

  @override
  final int retries;

  @override
  final Duration? timeLimit;

  @override
  final Duration timeRetry;

  @override
  final String? cacheKey;

  /// print error
  @override
  final bool printError;

  @override
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// The duration before local cache is expired.
  /// After this time the cache is expired and the image is reloaded.
  @override
  final Duration? cacheMaxAge;

  @override
  final WebHtmlElementStrategy webHtmlElementStrategy;

  @override
  Future<ExtendedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<ExtendedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    extended_image_provider.ExtendedNetworkImageProvider key,
    image_provider.ImageDecoderCallback decode,
  ) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return _ForwardingImageStreamCompleter(
      _loadAsync(key, decode, chunkEvents),
      informationCollector: _imageStreamInformationCollector(key),
      debugLabel: key.url,
    );
  }

  InformationCollector? _imageStreamInformationCollector(
    extended_image_provider.ExtendedNetworkImageProvider key,
  ) {
    InformationCollector? collector;
    assert(() {
      collector =
          () => <DiagnosticsNode>[
            DiagnosticsProperty<image_provider.ImageProvider>(
              'Image provider',
              this,
            ),
            DiagnosticsProperty<
              extended_image_provider.ExtendedNetworkImageProvider
            >('Image key', key),
          ];
      return true;
    }());
    return collector;
  }

  // Html renderer does not support decoding network images to a specified size. The decode parameter
  // here is ignored and `ui_web.createImageCodecFromUrl` will be used directly
  // in place of the typical `instantiateImageCodec` method.
  Future<ImageStreamCompleter> _loadAsync(
    extended_image_provider.ExtendedNetworkImageProvider key,
    _SimpleDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    assert(key == this);

    Future<ImageStreamCompleter> loadViaDecode() async {
      // Resolve the Codec before passing it to
      // [MultiFrameImageStreamCompleter] so any errors aren't reported
      // twice (once from the MultiFrameImageStreamCompleter and again
      // from the wrapping [ForwardingImageStreamCompleter]).
      final ui.Codec codec = await _fetchImageBytes(decode);
      return MultiFrameImageStreamCompleter(
        chunkEvents: chunkEvents.stream,
        codec: Future<ui.Codec>.value(codec),
        scale: key.scale,
        debugLabel: key.url,
        informationCollector: _imageStreamInformationCollector(key),
      );
    }

    Future<ImageStreamCompleter> loadViaImgElement() async {
      // If we failed to fetch the bytes, try to load the image in an <img>
      // element instead.
      final web.HTMLImageElement imageElement = imgElementFactory();
      imageElement.src = key.url;
      // Decode the <img> element before creating the ImageStreamCompleter
      // to avoid double reporting the error.
      await imageElement.decode().toDart;
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(
          WebImageInfo(imageElement, debugLabel: key.url),
        ),
        informationCollector: _imageStreamInformationCollector(key),
      )..debugLabel = key.url;
    }

    final bool containsNetworkImageHeaders = key.headers?.isNotEmpty ?? false;
    // When headers are set, the image can only be loaded by decoding.
    //
    // For the HTML renderer, `ui_web.createImageCodecFromUrl` method is not
    // capable of handling headers.
    //
    // For CanvasKit and Skwasm, it is not possible to load an <img> element and
    // pass the headers with the request to fetch the image. Since the user has
    // provided headers, this function should assume the headers are required to
    // resolve to the correct resource and should not attempt to load the image
    // in an <img> tag without the headers.
    if (containsNetworkImageHeaders) {
      return loadViaDecode();
    }

    if (!isSkiaWeb) {
      // This branch is only hit by the HTML renderer, which is deprecated. The
      // HTML renderer supports loading images with CORS restrictions, so we
      // don't need to catch errors and try loading the image in an <img> tag
      // in this case.

      // Resolve the Codec before passing it to
      // [MultiFrameImageStreamCompleter] so any errors aren't reported
      // twice (once from the MultiFrameImageStreamCompleter) and again
      // from the wrapping [ForwardingImageStreamCompleter].
      final Uri resolved = Uri.base.resolve(key.url);
      final ui.Codec codec = await ui_web.createImageCodecFromUrl(
        resolved,
        chunkCallback: (int bytes, int total) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: bytes,
              expectedTotalBytes: total,
            ),
          );
        },
      );
      return MultiFrameImageStreamCompleter(
        chunkEvents: chunkEvents.stream,
        codec: Future<ui.Codec>.value(codec),
        scale: key.scale,
        debugLabel: key.url,
        informationCollector: _imageStreamInformationCollector(key),
      );
    }

    switch (webHtmlElementStrategy) {
      case image_provider.WebHtmlElementStrategy.never:
        return loadViaDecode();
      case image_provider.WebHtmlElementStrategy.prefer:
        return loadViaImgElement();
      case image_provider.WebHtmlElementStrategy.fallback:
        try {
          // Await here so that errors occurred during the asynchronous process
          // of `loadViaDecode` are caught and triggers `loadViaImgElement`.
          return await loadViaDecode();
        } catch (e) {
          return loadViaImgElement();
        }
    }
  }

  Future<ui.Codec> _fetchImageBytes(_SimpleDecoderCallback decode) async {
    final Uri resolved = Uri.base.resolve(url);

    final bool containsNetworkImageHeaders = headers?.isNotEmpty ?? false;

    final Completer<web.XMLHttpRequest> completer =
        Completer<web.XMLHttpRequest>();
    final web.XMLHttpRequest request = httpRequestFactory();

    request.open('GET', url, true);
    request.responseType = 'arraybuffer';
    if (containsNetworkImageHeaders) {
      headers!.forEach((String header, String value) {
        request.setRequestHeader(header, value);
      });
    }

    request.addEventListener(
      'load',
      (web.Event e) {
        final int status = request.status;
        final bool accepted = status >= 200 && status < 300;
        final bool fileUri = status == 0; // file:// URIs have status of 0.
        final bool notModified = status == 304;
        final bool unknownRedirect = status > 307 && status < 400;
        final bool success =
            accepted || fileUri || notModified || unknownRedirect;

        if (success) {
          completer.complete(request);
        } else {
          completer.completeError(
            image_provider.NetworkImageLoadException(
              statusCode: status,
              uri: resolved,
            ),
          );
        }
      }.toJS,
    );

    request.addEventListener(
      'error',
      ((JSObject e) => completer.completeError(
            image_provider.NetworkImageLoadException(
              statusCode: request.status,
              uri: resolved,
            ),
          ))
          .toJS,
    );

    request.send();

    await completer.future;

    final Uint8List bytes =
        (request.response! as JSArrayBuffer).toDart.asUint8List();

    if (bytes.lengthInBytes == 0) {
      throw image_provider.NetworkImageLoadException(
        statusCode: request.status,
        uri: resolved,
      );
    }

    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedNetworkImageProvider &&
        url == other.url &&
        scale == other.scale &&
        //cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
    url,
    scale,
    //cacheRawData,
    imageCacheName,
  );

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';

  // not support on web
  @override
  Future<Uint8List?> getNetworkImageData({
    StreamController<ImageChunkEvent>? chunkEvents,
  }) {
    return Future<Uint8List>.error('not support on web');
  }

  static dynamic get httpClient => null;
}

/// An [ImageStreamCompleter] that delegates to another [ImageStreamCompleter]
/// that is loaded asynchronously.
///
/// This completer keeps its child completer alive until this completer is disposed.
class _ForwardingImageStreamCompleter extends ImageStreamCompleter {
  _ForwardingImageStreamCompleter(
    this.task, {
    InformationCollector? informationCollector,
    String? debugLabel,
  }) {
    this.debugLabel = debugLabel;
    task.then(
      (ImageStreamCompleter value) {
        resolved = true;
        if (_disposed) {
          // Add a listener since the delegate completer won't dispose if it never
          // had a listener.
          value.addListener(ImageStreamListener((_, _) {}));
          value.maybeDispose();
          return;
        }
        completer = value;
        handle = completer.keepAlive();
        completer.addListener(
          ImageStreamListener(
            (ImageInfo image, bool synchronousCall) {
              setImage(image);
            },
            onChunk: (ImageChunkEvent event) {
              reportImageChunkEvent(event);
            },
            onError: (Object exception, StackTrace? stackTrace) {
              reportError(exception: exception, stack: stackTrace);
            },
          ),
        );
      },
      onError: (Object error, StackTrace stack) {
        reportError(
          context: ErrorDescription('resolving an image stream completer'),
          exception: error,
          stack: stack,
          informationCollector: informationCollector,
          silent: true,
        );
      },
    );
  }

  final Future<ImageStreamCompleter> task;
  bool resolved = false;
  late final ImageStreamCompleter completer;
  late final ImageStreamCompleterHandle handle;

  bool _disposed = false;

  @override
  void onDisposed() {
    if (resolved) {
      handle.dispose();
    }
    _disposed = true;
    super.onDisposed();
  }
}

/// An [ImageInfo] object indicating that the image can only be displayed in
/// an HTML element, and no [dart:ui.Image] can be created for it.
///
/// This occurs on the web when the image resource is from a different origin
/// and is not configured for CORS. Since the image bytes cannot be directly
/// fetched, [Image]s cannot be created from it. However, the image can
/// still be displayed if an HTML element is used.
class WebImageInfo implements ImageInfo {
  /// Creates a new [WebImageInfo] from a given HTML element.
  WebImageInfo(this.htmlImage, {this.debugLabel});

  /// The HTML element used to display this image. This HTML element has already
  /// decoded the image, so size information can be retrieved from it.
  final web.HTMLImageElement htmlImage;

  @override
  final String? debugLabel;

  @override
  WebImageInfo clone() {
    // There is no need to actually clone the <img> element here. We create
    // another reference to the <img> element and let the browser garbage
    // collect it when there are no more live references.
    return WebImageInfo(htmlImage, debugLabel: debugLabel);
  }

  @override
  void dispose() {
    // There is nothing to do here. There is no way to delete an element
    // directly, the most we can do is remove it from the DOM. But the <img>
    // element here is never even added to the DOM. The browser will
    // automatically garbage collect the element when there are no longer any
    // live references to it.
  }

  @override
  Image get image =>
      throw UnsupportedError(
        'Could not create image data for this image because access to it is '
        'restricted by the Same-Origin Policy.\n'
        'See https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy',
      );

  @override
  bool isCloneOf(ImageInfo other) {
    if (other is! WebImageInfo) {
      return false;
    }

    // It is a clone if it points to the same <img> element.
    return other.htmlImage == htmlImage && other.debugLabel == debugLabel;
  }

  @override
  double get scale => 1.0;

  @override
  int get sizeBytes =>
      (4 * htmlImage.naturalWidth * htmlImage.naturalHeight).toInt();
}
