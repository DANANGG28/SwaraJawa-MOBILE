// Implementasi baca byte audio untuk platform Web.
//
// Di web, `record` mengembalikan `blob:` URL (bukan path berkas), sehingga
// byte audio diambil lewat XHR/dio.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<Uint8List> readAudioBytes(String path) async {
  if (path.startsWith('blob:') || path.startsWith('http')) {
    final res = await Dio().get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const <int>[]);
  }
  return Uint8List(0);
}

Future<String> audioBase64(String path) async {
  final bytes = await readAudioBytes(path);
  return base64Encode(bytes);
}
