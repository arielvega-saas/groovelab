import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Web-specific audio file picker for Pads using JS interop.
/// Returns {'bytes': Uint8List, 'name': String} or null if cancelled.
Future<Map<String, dynamic>?> pickPadAudioFileWeb() async {
  final completer = Completer<Map<String, dynamic>?>();

  try {
    final input = globalContext.callMethod('eval'.toJS,
      'document.createElement("input")'.toJS) as JSObject;
    input['type'] = 'file'.toJS;
    input['accept'] = 'audio/*,.mp3,.wav,.ogg,.m4a,.aac,.flac'.toJS;

    input['onchange'] = ((JSAny event) {
      try {
        final files = (input['files'] as JSObject);
        final length = (files['length'] as JSNumber).toDartInt;
        if (length == 0) { completer.complete(null); return; }

        final file = files.callMethodVarArgs('item'.toJS, [0.toJS]) as JSObject;
        final fileName = (file['name'] as JSString).toDart;
        final reader = globalContext.callMethod('eval'.toJS,
          'new FileReader()'.toJS) as JSObject;

        reader['onload'] = ((JSAny e) {
          try {
            final result = reader['result'] as JSArrayBuffer;
            final uint8 = result.toDart.asUint8List();
            completer.complete({'bytes': uint8, 'name': fileName});
          } catch (e) {
            completer.complete(null);
          }
        }).toJS;

        reader.callMethodVarArgs('readAsArrayBuffer'.toJS, [file]);
      } catch (e) {
        completer.complete(null);
      }
    }).toJS;

    input.callMethod('click'.toJS);
  } catch (e) {
    completer.complete(null);
  }

  return completer.future.timeout(const Duration(seconds: 60), onTimeout: () => null);
}
