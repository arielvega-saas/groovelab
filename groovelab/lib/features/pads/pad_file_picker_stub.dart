import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Native file picker implementation for pad audio import.
/// Uses the file_picker package to open the system file browser.
/// On web, the bridge redirects to pad_file_picker_web.dart instead.
Future<Map<String, dynamic>?> pickPadAudioFileWeb() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'aiff'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) {
      debugPrint('PadFilePicker: File selected but bytes are null (file too large for withData on this platform)');
      return null;
    }
    return {
      'bytes': file.bytes! as Uint8List,
      'name': file.name,
    };
  } catch (e) {
    debugPrint('PadFilePicker: Native file picker error: $e');
    return null;
  }
}
