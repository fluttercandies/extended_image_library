import '../extended_image_provider.dart';

class ExtendedFileImageProvider with ExtendedImageProvider {
  ExtendedFileImageProvider(this.file);

  final Object file;
}
