import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Central de Ajuda',
          style: TextStyle(color: Color(0xFF252940), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF252940)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection('Perguntas Frequentes'),
          _buildFAQItem(
            'Como faço um agendamento?',
            'Busque uma oficina, selecione os serviços desejados, escolha data/hora e confirme o agendamento.',
          ),
          _buildFAQItem(
            'Posso cancelar um agendamento?',
            'Sim, você pode cancelar até 2 horas antes do horário agendado.',
          ),
          _buildFAQItem(
            'Como adiciono um veículo?',
            'Vá em "Meus Veículos" e clique em adicionar. Você pode buscar pela placa para preencher automaticamente.',
          ),
          _buildFAQItem(
            'Como funciona o pagamento?',
            'O pagamento é realizado após a conclusão do serviço, diretamente na oficina ou pelo app.',
          ),

          const SizedBox(height: 30),

          _buildSection('Contato'),
          
          _buildContactItem(
            icon: Icons.email,
            title: 'Email',
            subtitle: 'contato@meca.com.br',
            onTap: () {},
          ),
          _buildContactItem(
            icon: Icons.phone,
            title: 'Telefone',
            subtitle: '(11) 3000-0000',
            onTap: () {},
          ),
          _buildContactItem(
            icon: Icons.chat,
            title: 'Chat ao Vivo',
            subtitle: 'Disponível 24/7',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF252940),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF252940)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00C977).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF00C977)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF252940)),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }
}
