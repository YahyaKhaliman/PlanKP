import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<bool> downloadBytesImpl({
  required List<int> bytes,
  required String fileName,
}) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final targetDir = dir ?? await getApplicationDocumentsDirectory();
    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
    return true;
  } catch (_) {
    return false;
  }
}
