import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web-specific file picker using dart:html FileUploadInputElement.
Future<Map<String, dynamic>?> pickAudioFileWeb() async {
  final completer = Completer<Map<String, dynamic>?>();
  final input = html.FileUploadInputElement()
    ..accept = '.mp3,.wav,.aac,.m4a,.ogg,.flac';
  input.click();
  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((e) {
      final bytes = reader.result as Uint8List;
      completer.complete({'bytes': bytes, 'name': file.name});
    });
    reader.onError.listen((e) => completer.complete(null));
  });
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => null,
  );
}
