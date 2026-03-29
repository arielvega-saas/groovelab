// Conditional export: uses web file picker on web, stub on native.
export 'file_picker_stub.dart' if (dart.library.html) 'file_picker_web.dart';
