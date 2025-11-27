/// Configuración global de la aplicación.
/// Contiene las credenciales y endpoints para conectar con ThingsBoard.
class AppConfig {
  // Constructor privado para evitar instanciación
  AppConfig._();

  /// URL Base de la API de ThingsBoard.
  /// NOTA: Usamos 'https' en lugar de 'http' para cumplir con la seguridad de Android.
  static const String tbBaseUrl = 'https://demo.thingsboard.io/api/v1';

  /// Token de acceso del dispositivo (Device Access Token).
  /// Este token identifica a tu 'Safe Ride' (Casco/App) en la nube.
  static const String deviceToken = '4DjWTh4eSUn2B3gsgjWL';
}