import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

/// Sube imagenes de propiedades a ImgBB (gratuito) y devuelve sus URLs.
/// Funciona igual en Web y Android porque envia los bytes codificados.
class StorageService {
  StorageService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://api.imgbb.com/1/upload');

  /// Sube cada imagen y devuelve sus URLs publicas en el mismo orden.
  Future<List<String>> uploadPropertyImages({
    required String ownerId,
    required List<XFile> images,
  }) async {
    if (!AppConfig.hasImgbbKey) {
      throw StateError(
        'Falta la API key de ImgBB. Configurala en lib/config/app_config.dart',
      );
    }

    final urls = <String>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      final response = await _client.post(
        _endpoint.replace(queryParameters: {'key': AppConfig.imgbbApiKey}),
        body: {'image': base64Encode(bytes)},
      );

      if (response.statusCode != 200) {
        throw Exception('ImgBB respondio ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = (data['data'] as Map<String, dynamic>)['url'] as String;
      urls.add(url);
    }
    return urls;
  }
}
