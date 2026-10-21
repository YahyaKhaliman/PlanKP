import 'file_downloader_io.dart'
    if (dart.library.html) 'file_downloader_web.dart' as impl;

class FileDownloader {
  static Future<bool> downloadBytes({
    required List<int> bytes,
    required String fileName,
  }) {
    return impl.downloadBytesImpl(
      bytes: bytes,
      fileName: fileName,
    );
  }
}
