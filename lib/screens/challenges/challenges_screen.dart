import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _challenges = [];
  String? _month;
  String? _error;

  static const _green = Color(0xFF00C977);
  static const _darkBg = Color(0xFF0A0A0A);
  static const _darkCard = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.get('/customer/challenges');
      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : result;
        setState(() {
          _challenges = List.from(data['challenges'] ?? []);
          _month = data['month']?.toString();
        });
      } else {
        setState(() => _error = result['error'] ?? 'Erro ao carregar desafios');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro de conexão');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMonth(String? month) {
    if (month == null || month.length < 7) return '';
    final parts = month.split('-');
    if (parts.length < 2) return month;
    final months = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return month;
    return '${months[m]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final isDark = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDark ? _darkBg : Colors.grey[50],
          appBar: AppBar(
            title: const Text('Desafios do Mês'),
            backgroundColor: isDark ? _darkBg : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black87,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : _error != null
                  ? _buildError(isDark)
                  : RefreshIndicator(
                      color: _green,
                      onRefresh: _loadChallenges,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeader(isDark),
                          const SizedBox(height: 20),
                          ..._challenges.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildChallengeCard(isDark, c),
                          )),
                          if (_challenges.isEmpty) _buildEmpty(isDark),
                          const SizedBox(height: 16),
                          _buildHowItWorks(isDark),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadChallenges,
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final completedCount = _challenges.where((c) {
      final p = c['progress'];
      return p is Map && p['completed'] == true;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C977), Color(0xFF00A063)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 40, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            _formatMonth(_month),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount de ${_challenges.length} concluídos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete desafios para ganhar pontos bônus!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(bool isDark, dynamic challenge) {
    final title = challenge['title'] ?? '';
    final description = challenge['description'] ?? '';
    final rewardPoints = challenge['reward_points'] ?? 0;
    final progress = challenge['progress'] is Map
        ? challenge['progress'] as Map<String, dynamic>
        : <String, dynamic>{};
    final current = progress['current'] ?? 0;
    final target = progress['target'] ?? 1;
    final percent = progress['percent'] ?? 0;
    final completed = progress['completed'] == true;
    final rewardGranted = progress['reward_granted'] == true;
    final fraction = (percent / 100).clamp(0.0, 1.0).toDouble();

    IconData goalIcon;
    switch (challenge['goal_type']) {
      case 'bookings_count':
        goalIcon = Icons.calendar_month;
        break;
      case 'reviews_count':
        goalIcon = Icons.star;
        break;
      default:
        goalIcon = Icons.flag;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? _green.withOpacity(0.4)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: completed
                      ? _green.withOpacity(0.15)
                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completed ? Icons.check_circle : goalIcon,
                  size: 22,
                  color: completed ? _green : (isDark ? Colors.white54 : Colors.black38),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withOpacity(completed ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$rewardPoints pts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: completed ? _green : _green.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              color: completed ? _green : _green.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $target',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              if (completed && rewardGranted)
                Row(
                  children: [
                    Icon(Icons.check, size: 14, color: _green),
                    const SizedBox(width: 4),
                    Text(
                      'Pontos recebidos!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                )
              else if (completed)
                Text(
                  'Concluído!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                )
              else
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            'Nenhum desafio disponível',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Novos desafios serão criados no próximo mês!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: _green),
              const SizedBox(width: 8),
              Text(
                'Como funciona',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep(isDark, '1', 'Novos desafios aparecem todo mês'),
          _buildStep(isDark, '2', 'Complete as metas agendando serviços ou avaliando'),
          _buildStep(isDark, '3', 'Ganhe pontos bônus automaticamente ao concluir'),
        ],
      ),
    );
  }

  Widget _buildStep(bool isDark, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
