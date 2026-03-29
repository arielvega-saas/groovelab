import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web-specific download trigger using JS interop.
void triggerWebDownload(String url, [String filename = 'groovelab-loop.wav']) {
  try {
    final document = globalContext['document'] as JSObject;
    final anchor = document.callMethodVarArgs('createElement'.toJS, ['a'.toJS]) as JSObject;
    anchor['href'] = url.toJS;
    anchor['download'] = filename.toJS;
    (document['body'] as JSObject).callMethodVarArgs('appendChild'.toJS, [anchor]);
    anchor.callMethod('click'.toJS);
    (document['body'] as JSObject).callMethodVarArgs('removeChild'.toJS, [anchor]);
  } catch (_) {}
}
