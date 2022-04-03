## 3.1.4

* Use list instead of listSync to look for cached files

## 3.1.3

* Make abstract ExtendedNetworkImageProvider with ExtendedImageProvider

## 3.1.2

* Fix issue that using headers might cause a lot of rebuilds (#39)

## 3.1.1

* Fix socket leak (#38)

## 3.1.0

* Improve:

  1. add [ExtendedNetworkImageProvider.cacheMaxAge] to set max age to be cached.

## 3.0.0

* Breaking change:

  1. we cache raw image pixels as default behavior at previous versions, it's not good for heap memory usage. so add [ExtendedImageProvider.cacheRawData] to support whether should cache the raw image pixels. It's [false] now.

* Improve:

  1. add [ExtendedResizeImage] to support resize image more convenient.
  2. add [ExtendedImageProvider.imageCacheName] to support custom ImageCache to store ExtendedImageProvider.
## 2.0.2

* fix null-safety cast error
## 2.0.1

* add [ExtendedNetworkImageProvider.printError]

## 2.0.0

* support-null-safety
## 1.0.1

* add cache key for utils

## 1.0.0

* fix web capability at pub.dev
* add cache key #288

## 0.3.1

* support chunkEvents for network web
## 0.3.0

* export http_client_helper

## 0.2.3

* fix analysis_options.yaml base on flutter sdk

## 0.2.2

* add analysis_options.yaml
* fix null exception of chunkEvents

## 0.2.1

* support loading progress for network
* public HttpClient of ExtendedNetworkImageProvider
* add getCachedSizeBytes method

## 0.2.0

* web support

## 0.1.9

* fix breaking change for flutter 1.10.15 about miss load parameter

## 0.1.8

* add ExtendedAssetBundleImageKey to support to cache rawImageData

## 0.1.7

* override == method to set rawImageData

## 0.1.6

* add ExtendedImageProvider
      ExtendedExactAssetImageProvider
      ExtendedAssetImageProvider
      ExtendedFileImageProvider
      ExtendedMemoryImageProvider
  now we can get raw image data from ExtendedImageProvider

## 0.1.5

* add getCachedImageFile(url) method

## 0.1.4

* improve codes base on v1.7.8

## 0.1.3

* update path_provider 1.1.0

## 0.1.1

* disabled informationCollector to keep backwards compatibility for now

## 0.1.0

* add extended_network_image_provider.dart and extended_network_image_utils.dart
