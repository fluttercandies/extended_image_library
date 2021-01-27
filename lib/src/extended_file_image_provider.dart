import 'io/extended_file_image_provider.dart'
    if (dart.library.html) 'extended_file_image_provider.dart'
    as image_provider;

class ExtendedFileImageProvider
    extends image_provider.ExtendedFileImageProvider {
  ExtendedFileImageProvider(Object file, {double scale = 1.0})
      : super(file, scale: scale);
}
