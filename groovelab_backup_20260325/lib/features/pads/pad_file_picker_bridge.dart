// Fixed: was using dart.library.js_interop which fails on legacy web compilers.
// dart.library.html is universally available on all web platforms (matches SongLab pattern).
export 'pad_file_picker_stub.dart' if (dart.library.html) 'pad_file_picker_web.dart';
