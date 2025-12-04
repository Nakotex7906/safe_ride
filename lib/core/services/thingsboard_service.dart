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
    // Usamos el endpoint para leer atributos del cliente (lo que envía el ESP8266)
    final url = Uri.parse('${AppConfig.tbBaseUrl}/${AppConfig.deviceToken}/attributes?clientKeys=estado_caida');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        // ThingsBoard devuelve algo como: {"client": {"estado_caida": true}}
        if (data.containsKey('client') && data['client'].containsKey('estado_caida')) {
          // Convertimos a string y comparamos por si llega como "true" o true booleano
          return data['client']['estado_caida'].toString() == 'true';
        }
      }
    } catch (e) {
      print('Error consultando caída: $e');
    }
    return false; // Si falla o no hay datos, asumimos que no hay caída
  }

  /// Resetea la alarma en ThingsBoard después de atenderla
  Future<void> resetFallStatus() async {
    final url = Uri.parse('${AppConfig.tbBaseUrl}/${AppConfig.deviceToken}/attributes');
    await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'estado_caida': false})
    );
  }

}