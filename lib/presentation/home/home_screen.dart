import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_ride/core/services/thingsboard_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tbService = ThingsboardService();
  bool _isTracking = false;
  String _log = "Presiona INICIAR para conectar";
  Timer? _timer;

  // Función para iniciar el rastreo
  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    // 1. Pedir permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _log = "Permisos denegados :(");
        return;
      }
    }

    setState(() {
      _isTracking = true;
      _log = "Iniciando GPS...";
    });

    // 2. Timer: Enviar datos cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Enviar a ThingsBoard
        bool sent = await _tbService.sendLocation(position.latitude, position.longitude);

        if (mounted) {
          setState(() {
            _log = sent
                ? "Enviado: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}"
                : "Error al enviar a la nube";
          });
        }
      } catch (e) {
        setState(() => _log = "Error GPS: $e");
      }
    });
  }

  void _stopTracking() {
    _timer?.cancel();
    setState(() {
      _isTracking = false;
      _log = "Rastreo detenido.";
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Ride GPS'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTracking ? Icons.satellite_alt : Icons.location_off,
              size: 100,
              color: _isTracking ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                _log,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _toggleTracking,
              icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
              label: Text(_isTracking ? "DETENER" : "INICIAR RUTA"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}