import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class EmailService {
  static String get _apiUrl => AppConfig.apiBaseUrl;
  
  // Templates de email com logo MECA
  static const String _emailTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MECA - Seu carro em boas mãos</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
            background: linear-gradient(135deg, #00C977 0%, #00B369 100%);
            padding: 30px 20px;
            text-align: center;
        }
        .logo {
            width: 80px;
            height: 80px;
            background-color: #ffffff;
            border-radius: 50%;
            margin: 0 auto 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 32px;
            font-weight: bold;
            color: #00C977;
        }
        .header h1 {
            color: #ffffff;
            margin: 0;
            font-size: 28px;
            font-weight: bold;
        }
        .content {
            padding: 40px 30px;
        }
        .content h2 {
            color: #00C977;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .content p {
            color: #333333;
            line-height: 1.6;
            margin-bottom: 15px;
        }
        .button {
            display: inline-block;
            background-color: #00C977;
            color: #ffffff;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin: 20px 0;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666666;
            font-size: 14px;
        }
        .info-box {
            background-color: #f8f9fa;
            border-left: 4px solid #00C977;
            padding: 15px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">MECA</div>
            <h1>Seu carro em boas mãos</h1>
        </div>
        <div class="content">
            {{CONTENT}}
        </div>
        <div class="footer">
            <p>© 2024 MECA - Todos os direitos reservados</p>
            <p>Este é um email automático, não responda a esta mensagem.</p>
        </div>
    </div>
</body>
</html>
''';

  // Email de boas-vindas
  static Future<bool> sendWelcomeEmail({
    required String email,
    required String firstName,
  }) async {
    final content = '''
    <h2>Bem-vindo ao MECA! 🎉</h2>
    <p>Olá <strong>$firstName</strong>,</p>
    <p>Seja muito bem-vindo ao MECA! Estamos felizes em tê-lo conosco.</p>
    <p>Com o MECA, você pode:</p>
    <ul>
        <li>Encontrar oficinas próximas a você</li>
        <li>Agendar serviços de forma rápida e fácil</li>
        <li>Acompanhar seus agendamentos em tempo real</li>
        <li>Pagar com segurança via PIX ou cartão</li>
    </ul>
    <div class="info-box">
        <p><strong>Dica:</strong> Baixe nosso app para uma experiência ainda melhor!</p>
    </div>
    <p>Se precisar de ajuda, nossa equipe está sempre disponível.</p>
    <p>Bem-vindo à família MECA!</p>
    ''';

    return await _sendEmail(
      to: email,
      subject: 'Bem-vindo ao MECA! 🎉',
      content: content,
    );
  }

  // Email de confirmação de agendamento
  static Future<bool> sendBookingConfirmationEmail({
    required String email,
    required String customerName,
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
    required String workshopAddress,
    required String workshopPhone,
  }) async {
    final formattedDate = _formatDate(scheduledDate);
    
    final content = '''
    <h2>Agendamento Confirmado! ✅</h2>
    <p>Olá <strong>$customerName</strong>,</p>
    <p>Seu agendamento foi confirmado com sucesso!</p>
    <div class="info-box">
        <p><strong>Serviço:</strong> $serviceName</p>
        <p><strong>Oficina:</strong> $workshopName</p>
        <p><strong>Data e Hora:</strong> $formattedDate</p>
        <p><strong>Endereço:</strong> $workshopAddress</p>
        <p><strong>Telefone:</strong> $workshopPhone</p>
    </div>
    <p>Lembre-se de chegar no horário agendado. Em caso de necessidade de reagendamento, entre em contato conosco.</p>
    <p>Você receberá lembretes por email e push notification.</p>
    ''';

    return await _sendEmail(
      to: email,
      subject: 'Agendamento Confirmado - $serviceName',
      content: content,
    );
  }

  // Email de rejeição de agendamento
  static Future<bool> sendBookingRejectionEmail({
    required String email,
    required String customerName,
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
    String? reason,
  }) async {
    final formattedDate = _formatDate(scheduledDate);
    
    final content = '''
    <h2>Agendamento Rejeitado ❌</h2>
    <p>Olá <strong>$customerName</strong>,</p>
    <p>Infelizmente, seu agendamento não pôde ser confirmado.</p>
    <div class="info-box">
        <p><strong>Serviço:</strong> $serviceName</p>
        <p><strong>Oficina:</strong> $workshopName</p>
        <p><strong>Data:</strong> $formattedDate</p>
        ${reason != null ? '<p><strong>Motivo:</strong> $reason</p>' : ''}
    </div>
    <p>Você pode tentar agendar novamente em outra data ou com outra oficina.</p>
    <p>Desculpe pelo inconveniente.</p>
    ''';

    return await _sendEmail(
      to: email,
      subject: 'Agendamento Rejeitado - $serviceName',
      content: content,
    );
  }

  // Email de lembrete de agendamento
  static Future<bool> sendBookingReminderEmail({
    required String email,
    required String customerName,
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
  }) async {
    final formattedDate = _formatDate(scheduledDate);
    
    final content = '''
    <h2>Lembrete de Agendamento ⏰</h2>
    <p>Olá <strong>$customerName</strong>,</p>
    <p>Este é um lembrete do seu agendamento:</p>
    <div class="info-box">
        <p><strong>Serviço:</strong> $serviceName</p>
        <p><strong>Oficina:</strong> $workshopName</p>
        <p><strong>Data e Hora:</strong> $formattedDate</p>
    </div>
    <p>Não se esqueça de chegar no horário agendado!</p>
    ''';

    return await _sendEmail(
      to: email,
      subject: 'Lembrete: Seu agendamento é hoje!',
      content: content,
    );
  }

  // Email de recuperação de senha
  static Future<bool> sendPasswordResetEmail({
    required String email,
    required String customerName,
    required String resetToken,
  }) async {
    final resetUrl = 'https://mecabr.com/reset-password?token=$resetToken';
    
    final content = '''
    <h2>Recuperação de Senha 🔐</h2>
    <p>Olá <strong>$customerName</strong>,</p>
    <p>Recebemos uma solicitação para redefinir sua senha.</p>
    <p>Clique no botão abaixo para criar uma nova senha:</p>
    <a href="$resetUrl" class="button">Redefinir Senha</a>
    <p>Se você não solicitou esta alteração, ignore este email.</p>
    <p>Este link expira em 24 horas.</p>
    ''';

    return await _sendEmail(
      to: email,
      subject: 'Recuperação de Senha - MECA',
      content: content,
    );
  }

  // Email de aprovação de oficina
  static Future<bool> sendWorkshopApprovalEmail({
    required String email,
    required String workshopName,
    required String contactName,
  }) async {
    final content = '''
    <h2>Oficina Aprovada! 🎉</h2>
    <p>Olá <strong>$contactName</strong>,</p>
    <p>Parabéns! Sua oficina <strong>$workshopName</strong> foi aprovada e está ativa na plataforma MECA!</p>
    <p>Agora você pode:</p>
    <ul>
        <li>Receber agendamentos de clientes</li>
        <li>Gerenciar sua agenda</li>
        <li>Configurar seus serviços</li>
        <li>Receber pagamentos</li>
    </ul>
    <p>Baixe o app MECA Oficinas para começar a receber clientes!</p>
    <p>Bem-vindo à família MECA!</p>
    ''';

    return await _sendEmail(
      to: email,
      subject: 'Oficina Aprovada - Bem-vindo ao MECA!',
      content: content,
    );
  }

  // Método privado para enviar email
  static Future<bool> _sendEmail({
    required String to,
    required String subject,
    required String content,
  }) async {
    try {
      final emailContent = _emailTemplate.replaceAll('{{CONTENT}}', content);
      
      final response = await http.post(
        Uri.parse('$_apiUrl/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'html': emailContent,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao enviar email: $e');
      return false;
    }
  }

  static String _formatDate(DateTime date) {
    final months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    
    return '${date.day} de ${months[date.month - 1]} de ${date.year} às ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}






















