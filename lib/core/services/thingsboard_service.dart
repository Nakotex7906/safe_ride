import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';

class ThingsboardService {
  /// Envía latitud y longitud a ThingsBoard
  Future<bool> sendLocation(double lat, double lng) async {
    final url = Uri.parse('${AppConfig.tbBaseUrl}/${AppConfig.deviceToken}/telemetry');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng,
          'gps_source': 'mobile_app' // Para saber que vino del celu
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error enviando datos: $e');
      return false;
    }
  }

  /// Consulta a ThingsBoard si el dispositivo reportó una caída
  Future<bool> checkFallStatus() async {
    // URL para obtener atributos de cliente
    final url = Uri.parse('${AppConfig.tbBaseUrl}/${AppConfig.deviceToken}/attributes?clientKeys=estado_caida');

    try {
      print("--- CONSULTANDO THINGSBOARD ---"); // Debug
      final response = await http.get(url);

      print("Status: ${response.statusCode}"); // Debug: Debe ser 200
      print("Cuerpo: ${response.body}");       // Debug: Aquí veremos qué llega exactamente

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Verificamos si la respuesta tiene la estructura {"client": { ... }}
        if (data.containsKey('client') && data['client'].containsKey('estado_caida')) {
          final valor = data['client']['estado_caida'];
          print("Valor encontrado: $valor (Tipo: ${valor.runtimeType})"); // Debug

          // Lógica robusta: Acepta true (bool), "true" (string), 1 (int), "1" (string)
          return valor == true ||
              valor.toString().toLowerCase() == 'true' ||
              valor == 1 ||
              valor.toString() == '1';
        } else {
          print("AVISO: La llave 'estado_caida' no vino en la respuesta.");
        }
      } else {
        print("ERROR: La petición falló. Revisa tu Token en el archivo .env");
      }
    } catch (e) {
      print('Excepción consultando caída: $e');
    }
    return false;
  }

  /// Resetea la alarma en ThingsBoard estableciendo 'estado_caida' en false.
  /// Esto es crucial para evitar que la App entre en un bucle de alertas
  /// si el dispositivo no resetea la variable automáticamente.
  Future<bool> resetFallStatus() async {
    final url = Uri.parse('${AppConfig.tbBaseUrl}/${AppConfig.deviceToken}/attributes');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'estado_caida': false}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error reseteando estado de caída: $e');
      return false;
    }
  }

}