import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  // Usamos getters estáticos para leer al momento de usar
  static String get tbBaseUrl => dotenv.env['TB_URL'] ?? 'https://demo.thingsboard.io/api/v1';
  static String get deviceToken => dotenv.env['TB_TOKEN'] ?? '';
}