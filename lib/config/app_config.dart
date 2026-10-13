/// Configuracion de servicios externos.
///
/// Para subir imagenes:
/// 1. Crea una cuenta gratuita en https://imgbb.com
/// 2. Entra a https://api.imgbb.com y copia tu API key.
/// 3. Pega la clave abajo (reemplaza el texto entre comillas).
class AppConfig {
  AppConfig._();

  static const String imgbbApiKey = 'e5462c96e15955d1ad345e1400e63eb2';

  static bool get hasImgbbKey =>
      imgbbApiKey.isNotEmpty && imgbbApiKey != 'PON_AQUI_TU_API_KEY';
}
