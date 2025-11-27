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
}