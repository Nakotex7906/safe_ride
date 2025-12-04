import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/services/thingsboard_service.dart';
import 'package:safe_ride/core/services/email_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  LatLng? _startPosition; // Coordenada de inicio
  LatLng? _endPosition;

  // Servicios
  final _tbService = ThingsboardService();
  final _emailService = EmailService();

  // Estados
  bool _isTracking = false;
  String _log = "Presiona INICIAR para monitorear";
  Timer? _monitorTimer; // Timer para GPS y ThingsBoard

  // Control de Emergencia
  bool _isEmergencyActive = false; // Para saber si ya estamos en cuenta regresiva

  // Mapa
  final List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(-38.73, -72.59);
  int _selectedIndex = 0;

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // LÓGICA DE MONITOREO

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    Position initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _startPosition = LatLng(initialPos.latitude, initialPos.longitude);
      _endPosition = null;
      _routePoints.add(_startPosition!);
      _isEmergencyActive = false;
      _log = "Ruta Iniciada, Grabando";
    });

    // Bucle principal: Cada 5 segundos
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        if (_isEmergencyActive) return; // Si hay una emergencia en curso, pausamos el monitoreo normal

        //  GPS y ThingsBoard
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final newPoint = LatLng(pos.latitude, pos.longitude);
        await _tbService.sendLocation(pos.latitude, pos.longitude);

        //  Verificar Caída
        bool caidaDetectada = await _tbService.checkFallStatus();

        if (caidaDetectada && !_isEmergencyActive) {
          // INICIAR PROTOCOLO DE EMERGENCIA (Cuenta regresiva)
          _startEmergencyCountdown(pos);
        }

        // C. Actualizar UI
        if (mounted && !_isEmergencyActive) {
          setState(() {
            _currentLocation = newPoint;
            _routePoints.add(newPoint);
            _log = "Lat: ${pos.latitude.toStringAsFixed(4)} | Lng: ${pos.longitude.toStringAsFixed(4)}";
            if (_selectedIndex == 1) _mapController.move(newPoint, 16.0);
          });
        }
      } catch (e) {
        print("Error bucle: $e");
      }
    });
  }

  void _stopTracking() {
    _monitorTimer?.cancel();

    if (_routePoints.isNotEmpty) {
      //  Marcar el final
      setState(() {
        _isTracking = false;
        _endPosition = _routePoints.last;
        _log = "Ruta finalizada. Distancia visualizada.";
      });

      //  Ajustar la cámara para ver toda la ruta (Fit Bounds)
      // Usamos LatLngBounds para calcular el recuadro que contiene todos los puntos
      if (_routePoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(_routePoints);
        // CameraFit.bounds es la forma moderna en flutter_map v6/v7
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0), // Margen para que no quede pegado al borde
          ),
        );
      }
    } else {
      setState(() {
        _isTracking = false;
        _log = "Monitoreo detenido sin ruta.";
      });
    }
  }

  // LÓGICA DE EMERGENCIA

  void _startEmergencyCountdown(Position pos) {
    setState(() => _isEmergencyActive = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return EmergencyDialog(
          onCancel: () async {
            // 1. Cerrar diálogo
            Navigator.of(context).pop();

            // 2. Resetear la alarma en ThingsBoard para no volver a dispararla
            //    inmediatamente en el próximo ciclo del timer.
            await _tbService.resetFallStatus();

            setState(() {
              _isEmergencyActive = false;
              _log = "Alerta cancelada por el usuario.";
            });
          },
          onTimeout: () async {
            Navigator.of(context).pop();
            setState(() => _log = "Enviando ayuda...");

            // Enviar correo
            bool sent = await _emailService.sendEmergencyEmail(pos.latitude, pos.longitude);

            // IMPORTANTE: Resetear la alarma en ThingsBoard también aquí,
            // porque la emergencia ya fue procesada.
            await _tbService.resetFallStatus();

            if (mounted) {
              setState(() {
                _isEmergencyActive = false;
                _log = sent ? "AYUDA SOLICITADA \nCorreo enviado." : "Error al enviar ayuda.";
              });
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(sent ? "CORREO ENVIADO CON ÉXITO" : "ERROR DE ENVÍO"),
                    backgroundColor: sent ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 10),
                  )
              );
            }
          },
        );
      },
    );
  }

  // SOS Manual (Sin cuenta regresiva, inmediato)
  Future<void> _sendPanicAlert() async {
    if (_routePoints.isNotEmpty) {
      final last = _routePoints.last;
      bool sent = await _emailService.sendEmergencyEmail(last.latitude, last.longitude);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent ? "Alerta enviada" : "Error")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sin señal GPS")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Ride'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Pestaña Monitor
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isTracking ? Icons.security : Icons.security_update_warning, size: 80, color: Colors.indigo),
                const SizedBox(height: 20),
                Text(_log, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? "DETENER" : "INICIAR RUTA"),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _sendPanicAlert,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  icon: const Icon(Icons.sos),
                  label: const Text("SOS MANUAL"),
                )
              ],
            ),
          ),
          // Pestaña Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              // Opcional: interactionOptions para mejorar la experiencia táctil
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.safe_ride',
              ),

              // La Línea de la Ruta
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: Colors.blue,
                  ),
                ],
              ),

              // Marcadores (Inicio, Fin y Actual)
              MarkerLayer(
                markers: [
                  // MARCADOR DE INICIO (Verde) - Solo si existe
                  if (_startPosition != null)
                    Marker(
                      point: _startPosition!,
                      width: 60,
                      height: 60,
                      child: const Icon(Icons.flag, color: Colors.green, size: 40),
                      alignment: Alignment.topCenter, // Para que el palo de la bandera toque el punto
                    ),

                  // MARCADOR DE FIN (Rojo/Bandera) - Solo si terminamos
                  if (_endPosition != null && !_isTracking)
                    Marker(
                      point: _endPosition!,
                      width: 60,
                      height: 60,
                      child: const Icon(Icons.sports_score, color: Colors.black, size: 40),
                    ),

                  // MARCADOR DE POSICIÓN ACTUAL (Solo mientras rastreamos)
                  if (_isTracking)
                    Marker(
                      point: _currentLocation,
                      width: 60,
                      height: 60,
                      child: const Icon(Icons.directions_bike, color: Colors.indigo, size: 40),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Monitor'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        ],
      ),
    );
  }
}

// WIDGET DIÁLOGO DE EMERGENCIA
class EmergencyDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onTimeout;

  const EmergencyDialog({super.key, required this.onCancel, required this.onTimeout});

  @override
  State<EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<EmergencyDialog> {
  int _secondsRemaining = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _countdownTimer?.cancel();
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.red.shade50,
      title: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: const Text(
              "¿CAÍDA DETECTADA?",
              style: TextStyle(fontWeight: FontWeight.bold), // Texto en negrita se ve mejor
              maxLines: 2, // Permite hasta 2 líneas
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Se ha detectado un impacto fuerte.",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Text(
            "Enviando ayuda en:",
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            "$_secondsRemaining",
            style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const Text("segundos"),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: widget.onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("ESTOY BIEN, CANCELAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}