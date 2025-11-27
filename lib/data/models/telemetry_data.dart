/// Modelo que representa los datos a enviar a ThingsBoard.
/// Sigue el principio de inmutabilidad.
class TelemetryData {
  final double latitude;
  final double longitude;
  final bool? fallDetected; // Opcional, por si la app también detecta o reporta

  TelemetryData({
    required this.latitude,
    required this.longitude,
    this.fallDetected,
  });

  /// Convierte el modelo a un mapa JSON para la API de ThingsBoard.
  Map<String, dynamic> toJson() {
    final data = {
      'latitude': latitude,
      'longitude': longitude,
    };
    if (fallDetected != null) {
      data['fallDetected'] = fallDetected as double;
    }
    return data;
  }
}