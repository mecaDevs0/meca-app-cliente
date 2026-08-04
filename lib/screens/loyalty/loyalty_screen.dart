import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({Key? key}) : super(key: key);

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRedeeming = false;
  Map<String, dynamic>? _data;
  List<dynamic> _promoCodes = [];
  String? _error;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  static const _green = Color(0xFF00C977);
  static const _darkBg = Color(0xFF0A0A0A);
  static const _darkCard = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimation =
        Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    _loadAll();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.get('/customer/loyalty'),
        _apiService.get('/customer/promo-codes'),
      ]);

      if (!mounted) return;

      final loyaltyResult = results[0];
      final promoResult = results[1];

      if (loyaltyResult['success'] == true) {
        final d = loyaltyResult['data'] is Map<String, dynamic>
            ? loyaltyResult['data'] as Map<String, dynamic>
            : loyaltyResult;
        setState(() => _data = d);

        final totalEarned = (d['total_earned'] ?? 0) as int;
        final nextMin = d['next_level_min'] as int?;
        if (nextMin != null && nextMin > 0) {
          final currentLevelMin = _getLevelMin(d['level'] as int? ?? 0);
          final range = nextMin - currentLevelMin;
          final progress = totalEarned - currentLevelMin;
          final fraction = range > 0 ? (progress / range).clamp(0.0, 1.0) : 1.0;
          _progressAnimation =
              Tween<double>(begin: 0, end: fraction).animate(CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ));
        } else {
          _progressAnimation =
              Tween<double>(begin: 0, end: 1.0).animate(CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ));
        }
        _progressController.forward(from: 0);
      } else {
        setState(() => _error = loyaltyResult['error'] ?? 'Erro ao carregar pontos');
      }

      if (promoResult['success'] == true) {
        final promoData = promoResult['data'];
        if (promoData is Map && promoData['promo_codes'] is List) {
          setState(() => _promoCodes = promoData['promo_codes'] as List);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro de conexão');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getLevelMin(int level) {
    const mins = [0, 300, 1000];
    return level < mins.length ? mins[level] : 1000;
  }

  Future<void> _redeemPoints() async {
    setState(() => _isRedeeming = true);
    try {
      final result = await _apiService.post('/customer/loyalty/redeem', {});
      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;
        _showRedeemSuccess(data?['code'] ?? '', (data?['percent'] ?? 1).toInt());
        _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erro ao resgatar')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro de conexão')),
      );
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  void _showRedeemSuccess(String code, int percent) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ThemeService>(
        builder: (_, theme, __) {
          final isDark = theme.isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? _darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cupom Resgatado!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Desconto de $percent%',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Código copiado!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(Icons.copy, size: 20, color: _green),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Use na hora de pagar seu próximo serviço.\nVálido por 90 dias. Mínimo R\$100.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar', style: TextStyle(color: _green)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          backgroundColor: isDark ? _darkBg : Colors.grey[50],
          appBar: AppBar(
            title: const Text('Meus Pontos'),
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
                      onRefresh: _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildBalanceCard(isDark),
                          const SizedBox(height: 24),
                          _buildCouponsSection(isDark),
                          const SizedBox(height: 24),
                          _buildHowItWorks(isDark),
                          const SizedBox(height: 24),
                          _buildLevelsCard(isDark),
                          const SizedBox(height: 24),
                          _buildEarnWays(isDark),
                          const SizedBox(height: 24),
                          _buildTransactionHistory(isDark),
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
            onPressed: _loadAll,
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── BALANCE + LEVEL CARD ──────────────────────────────────────

  Widget _buildBalanceCard(bool isDark) {
    final balance = _data?['points_balance'] ?? 0;
    final levelName = _data?['level_name'] ?? 'Bronze';
    final multiplier = (_data?['points_multiplier'] ?? 1.0).toDouble();
    final nextLevelName = _data?['next_level_name'];
    final pointsToNext = _data?['points_to_next_level'] ?? 0;
    final redeemThreshold = _data?['redeem_threshold'] ?? 100;
    final canRedeem = balance >= redeemThreshold;
    final redeemablePercent = (_data?['redeemable_percent'] ?? 0) as int;
    final maxRedeemPercent = (_data?['max_redeem_percent'] ?? 10) as int;
    final percentPerThreshold = (_data?['percent_per_threshold'] ?? 1) as int;

    final levelEmoji = levelName == 'Ouro' ? '🥇' : levelName == 'Prata' ? '🥈' : '🥉';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2F1A), const Color(0xFF0D1F0D)]
              : [const Color(0xFFE8F9F0), const Color(0xFFD0F0E0)],
        ),
        border: Border.all(
          color: _green.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(levelEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    levelName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${multiplier}x pontos',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (nextLevelName != null) ...[
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  color: _green,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Faltam $pointsToNext pts para $nextLevelName',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 1.0,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                color: _green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nível máximo atingido',
              style: TextStyle(
                fontSize: 12,
                color: _green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '$balance',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            'pontos',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canRedeem
                ? 'Equivale a $redeemablePercent% de desconto'
                : 'Faltam ${redeemThreshold - balance} pontos para resgatar $percentPerThreshold%',
            style: TextStyle(
              fontSize: 14,
              color: canRedeem ? _green : (isDark ? Colors.white54 : Colors.black45),
              fontWeight: canRedeem ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: canRedeem && !_isRedeeming ? _redeemPoints : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : _green.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isRedeeming
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      canRedeem ? 'Resgatar $redeemablePercent%' : 'Resgatar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: canRedeem ? Colors.white : (isDark ? Colors.white30 : _green.withValues(alpha: 0.3)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── COUPONS SECTION ───────────────────────────────────────────

  Widget _buildCouponsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.confirmation_number_outlined, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              'Meus Cupons',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (_promoCodes.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_promoCodes.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_promoCodes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Icon(Icons.redeem, size: 36, color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(height: 12),
                Text(
                  'Você ainda não tem cupons',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resgate pontos ou avalie oficinas para ganhar!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          )
        else
          ..._promoCodes.map((pc) => _buildCouponCard(pc, isDark)),
      ],
    );
  }

  Widget _buildCouponCard(dynamic pc, bool isDark) {
    final code = pc['code'] ?? '';
    final value = (pc['value'] ?? 0).toDouble();
    final source = pc['source'] ?? 'fidelidade';
    final daysRemaining = pc['days_remaining'] as int?;
    final description = pc['description'] ?? '';
    final isExpiringSoon = daysRemaining != null && daysRemaining <= 7;

    Color sourceColor;
    String sourceLabel;
    switch (source) {
      case 'indicacao':
        sourceColor = Colors.blue;
        sourceLabel = 'Indicação';
        break;
      case 'avaliacao':
        sourceColor = Colors.amber[700]!;
        sourceLabel = 'Avaliação';
        break;
      default:
        sourceColor = _green;
        sourceLabel = 'Fidelidade';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpiringSoon
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      pc['type'] == 'percentage' ? '${value.toStringAsFixed(0)}%' : 'R\$${value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sourceColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sourceLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sourceColor),
                      ),
                    ),
                    if (daysRemaining != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        isExpiringSoon ? 'Expira em breve' : '${daysRemaining}d restantes',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpiringSoon ? Colors.red : (isDark ? Colors.white38 : Colors.black38),
                          fontWeight: isExpiringSoon ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Código $code copiado!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.copy, size: 20, color: isDark ? Colors.white38 : Colors.black38),
            tooltip: 'Copiar código',
          ),
        ],
      ),
    );
  }

  // ── HOW IT WORKS ──────────────────────────────────────────────

  Widget _buildHowItWorks(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.help_outline, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              'Como funciona',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? _darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              _buildStep(1, 'Ganhe pontos', 'Pague serviços, avalie oficinas ou indique amigos', Icons.star_outline, isDark),
              Divider(height: 24, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              _buildStep(2, 'Suba de nível', 'Quanto mais pontos acumular, maior seu multiplicador', Icons.trending_up, isDark),
              Divider(height: 24, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              _buildStep(3, 'Resgate recompensas', 'Cada 100 pontos = 1% de desconto (máx 10%)', Icons.redeem, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int number, String title, String subtitle, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _green),
            ),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, size: 22, color: _green.withValues(alpha: 0.6)),
      ],
    );
  }

  // ── LEVELS CARD ───────────────────────────────────────────────

  Widget _buildLevelsCard(bool isDark) {
    final currentLevel = _data?['level'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              'Níveis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? _darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              _buildLevelRow('🥉', 'Bronze', '1.0x', '0 pts', 0, currentLevel, isDark),
              const SizedBox(height: 10),
              _buildLevelRow('🥈', 'Prata', '1.2x', '300 pts', 1, currentLevel, isDark),
              const SizedBox(height: 10),
              _buildLevelRow('🥇', 'Ouro', '1.5x', '1000 pts', 2, currentLevel, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelRow(String emoji, String name, String mult, String requirement, int level, int currentLevel, bool isDark) {
    final isActive = level == currentLevel;
    final isLocked = level > currentLevel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? _green.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: _green.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 22, color: isLocked ? Colors.grey : null)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isLocked
                        ? (isDark ? Colors.white30 : Colors.black26)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  requirement,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? _green.withValues(alpha: 0.2)
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              mult,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? _green : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, size: 18, color: _green),
          ],
        ],
      ),
    );
  }

  // ── EARN WAYS ─────────────────────────────────────────────────

  Widget _buildEarnWays(bool isDark) {
    final multiplier = (_data?['points_multiplier'] ?? 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              'Formas de ganhar pontos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEarnItem(
          Icons.payment,
          'Pagamentos',
          'R\$1 gasto = ${multiplier > 1 ? "${multiplier.toStringAsFixed(1)} pontos" : "1 ponto"}',
          isDark,
        ),
        const SizedBox(height: 8),
        _buildEarnItem(
          Icons.star,
          'Avalie oficinas',
          '+5 pontos por avaliação',
          isDark,
        ),
        const SizedBox(height: 8),
        _buildEarnItem(
          Icons.people,
          'Indique amigos',
          '+15 pontos por indicação',
          isDark,
        ),
      ],
    );
  }

  Widget _buildEarnItem(IconData icon, String title, String subtitle, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TRANSACTION HISTORY ───────────────────────────────────────

  Widget _buildTransactionHistory(bool isDark) {
    final transactions = (_data?['recent_transactions'] as List?) ?? [];
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              'Histórico',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 36, color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma transação ainda',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agende um serviço para começar a acumular pontos!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
              ),
              itemBuilder: (_, i) {
                final tx = transactions[i];
                final isEarn = tx['type'] == 'earn';
                final points = tx['points'] ?? tx['amount'] ?? 0;
                final desc = tx['description'] ?? '';
                String dateStr = '';
                if (tx['created_at'] != null) {
                  try {
                    dateStr = dateFormat.format(DateTime.parse(tx['created_at'].toString()));
                  } catch (_) {}
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isEarn
                              ? _green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEarn ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                          color: isEarn ? _green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${isEarn ? "+" : "-"}$points',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isEarn ? _green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
