import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/meca_toast.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final _faqItems = <_FaqSection>[
    _FaqSection(
      title: 'Agendamentos',
      icon: Icons.calendar_today_rounded,
      items: [
        _FaqItem(
          'Como faço um agendamento?',
          'Busque uma oficina no mapa ou lista, escolha o serviço, selecione data e horário e confirme. Você receberá uma confirmação quando a oficina aprovar.',
        ),
        _FaqItem(
          'Posso cancelar um agendamento?',
          'Sim. Você pode cancelar até 2 horas antes do horário agendado pelo app. Após isso, entre em contato com a oficina.',
        ),
        _FaqItem(
          'A oficina sugeriu outro horário. O que fazer?',
          'Você verá uma notificação e na tela do agendamento os botões "Aceitar" ou "Recusar" a nova sugestão. Aceite para confirmar ou recuse para manter/cancelar.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Pagamento',
      icon: Icons.payment_rounded,
      items: [
        _FaqItem(
          'Como funciona o pagamento?',
          'Após a oficina finalizar o serviço e você aprovar o orçamento, o pagamento é feito no app por PIX ou cartão de crédito. O valor é repassado automaticamente à oficina.',
        ),
        _FaqItem(
          'Posso pagar com PIX?',
          'Sim. Na tela de pagamento escolha PIX, gere o código e pague pelo app do seu banco. A confirmação é quase instantânea.',
        ),
        _FaqItem(
          'O cartão pode ser parcelado?',
          'Depende da oficina. Na tela de pagamento você verá as opções de parcelamento disponíveis para aquele serviço.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Veículos e conta',
      icon: Icons.directions_car_rounded,
      items: [
        _FaqItem(
          'Como adiciono um veículo?',
          'Em "Meus Veículos" toque em adicionar. Você pode buscar pela placa para preencher modelo e dados automaticamente, ou preencher manualmente.',
        ),
        _FaqItem(
          'Como altero minha senha?',
          'No Perfil, toque em "Alterar senha". Informe a senha atual e a nova (mínimo 6 caracteres).',
        ),
        _FaqItem(
          'Como recebo notificações do agendamento?',
          'Ative as permissões de notificação do app. Você recebe avisos de confirmação, sugestão de horário, orçamento e pagamento.',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqSection> get _filteredSections {
    if (_searchQuery.trim().isEmpty) return _faqItems;
    final q = _searchQuery.trim().toLowerCase();
    return _faqItems.map((section) {
      final filtered = section.items
          .where((item) =>
              item.question.toLowerCase().contains(q) ||
              item.answer.toLowerCase().contains(q))
          .toList();
      if (filtered.isEmpty) return null;
      return _FaqSection(title: section.title, icon: section.icon, items: filtered);
    }).whereType<_FaqSection>().toList();
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'contato@mecabr.com',
      query: 'subject=Suporte MECA - App Cliente',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      MecaToast.show(context, 'Não foi possível abrir o e-mail.');
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+551130644243');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      MecaToast.show(context, 'Não foi possível abrir o telefone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF5F6F8);
    final surface = isDark ? const Color(0xFF151B23) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1D24);
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    const green = Color(0xFF00C977);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0B0F14) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryText),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                'Central de Ajuda',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [green.withOpacity(0.12), green.withOpacity(0.04)]
                        : [green.withOpacity(0.08), green.withOpacity(0.02)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 52, right: 16),
                      child: Icon(Icons.support_agent_rounded, size: 64, color: green.withOpacity(0.4)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Buscar dúvidas...',
                  hintStyle: TextStyle(color: secondaryText),
                  prefixIcon: Icon(Icons.search_rounded, color: secondaryText),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: secondaryText),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                style: TextStyle(color: primaryText, fontSize: 16),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                'Perguntas frequentes',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = _filteredSections[index];
                return _SectionCard(
                  section: section,
                  isDark: isDark,
                  surface: surface,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  green: green,
                );
              },
              childCount: _filteredSections.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Fale conosco',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  _ContactCard(
                    icon: Icons.email_outlined,
                    title: 'E-mail',
                    subtitle: 'contato@mecabr.com',
                    onTap: _launchEmail,
                    isDark: isDark,
                    surface: surface,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    green: green,
                  ),
                  const SizedBox(height: 12),
                  _ContactCard(
                    icon: Icons.phone_outlined,
                    title: 'Telefone',
                    subtitle: '(11) 3064-4243',
                    onTap: _launchPhone,
                    isDark: isDark,
                    surface: surface,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    green: green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;
  _FaqSection({required this.title, required this.icon, required this.items});
}

class _FaqItem {
  final String question;
  final String answer;
  _FaqItem(this.question, this.answer);
}

class _SectionCard extends StatelessWidget {
  final _FaqSection section;
  final bool isDark;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color green;

  const _SectionCard({
    required this.section,
    required this.isDark,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(section.icon, color: green, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  section.title,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...section.items.map(
            (item) => _FaqItemBlock(
              question: item.question,
              answer: item.answer,
              primaryText: primaryText,
              secondaryText: secondaryText,
              isLast: item == section.items.last,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItemBlock extends StatelessWidget {
  final String question;
  final String answer;
  final Color primaryText;
  final Color secondaryText;
  final bool isLast;

  const _FaqItemBlock({
    required this.question,
    required this.answer,
    required this.primaryText,
    required this.secondaryText,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isLast)
          Divider(height: 1, indent: 20, endIndent: 20, color: primaryText.withOpacity(0.08)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                answer,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color green;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: green.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: secondaryText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
