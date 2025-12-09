import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  final String _username = dotenv.env['EMAIL_USER'] ?? '';
  final String _password = dotenv.env['EMAIL_PASS'] ?? '';

  // Ahora pedimos el destinatario como argumento
  Future<bool> sendEmergencyEmail(double lat, double lng, String recipient) async {
    if (_username.isEmpty || _password.isEmpty) {
      print("ERROR: Credenciales de correo no configuradas en .env");
      return false;
    }

    // Validación extra
    if (recipient.isEmpty || !recipient.contains('@')) {
      print("ERROR: Correo de destinatario inválido: $recipient");
      return false;
    }

    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'Safe Ride App')
      ..recipients.add(recipient)
      ..subject = 'ALERTA: Caída Detectada - Safe Ride'
      ..text = 'Se ha detectado una caída.\n\n'
          'Ubicación actual:\n'
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng\n\n' // URL mejorada para abrir directo en maps
          'Por favor verificar estado del ciclista.';

    try {
      final sendReport = await send(message, smtpServer);
      print('Correo enviado a $recipient: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error enviando correo: $e');
      return false;
    }
  }
}