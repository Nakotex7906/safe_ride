import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Configura esto con tu correo real y la contraseña de aplicación
  final String _username = dotenv.env['EMAIL_USER'] ?? '';
  final String _password = dotenv.env['EMAIL_PASS'] ?? '';

  Future<bool> sendEmergencyEmail(double lat, double lng) async {
    if (_username.isEmpty || _password.isEmpty) {
      print("ERROR: Credenciales de correo no configuradas en .env");
      return false;
    }
    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'Safe Ride App')
      ..recipients.add('i.essus01@ufromail.cl') // Destinatario
      ..subject = 'ALERTA: Caída Detectada - Safe Ride'
      ..text = 'Se ha detectado una caída.\n\n'
          'Ubicación actual:\n'
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng\n\n'
          'Por favor verificar estado del ciclista.';

    try {
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error enviando correo: $e');
      return false;
    }
  }
}