import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Opens the platform "save file" dialog. Returns false if the user cancelled.
/// Android/iOS write the bytes themselves; desktop only returns the chosen
/// path, so the bytes are written here.
Future<bool> saveBytesAsFile({required Uint8List bytes, required String fileName, required String mimeType}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save $fileName',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [fileName.split('.').last],
    bytes: bytes,
  );
  if (path == null) return false;
  if (!(Platform.isAndroid || Platform.isIOS)) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return true;
}
