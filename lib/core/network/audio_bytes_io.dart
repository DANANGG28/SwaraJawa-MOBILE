// Implementasi baca byte audio untuk platform non-web.
//
// Berkas ini hanya dikompilasi di luar web (lihat conditional import).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readAudioBytes(String path) {
  return File(path).readAsBytes();
}

Future<String> audioBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}
