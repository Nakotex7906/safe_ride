import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyEmail = 'emergency_contact_email';

  /// Guarda el correo de emergencia
  Future<void> saveEmergencyEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
  }

  /// Obtiene el correo guardado (retorna null si no existe)
  Future<String?> getEmergencyEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }
}