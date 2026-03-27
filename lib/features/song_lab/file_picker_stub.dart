import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Native file picker implementation for iOS/Android/macOS.
/// Uses the file_picker package to open the system file browser.
Future<Map<String, dynamic>?> pickAudioFileWeb() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'aiff'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) return null;
    return {
      'bytes': file.bytes! as Uint8List,
      'name': file.name,
    };
  } catch (e) {
    return null;
  }
}
