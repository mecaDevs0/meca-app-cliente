import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ApiService _apiService = ApiService();
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.get('/customer/referral');
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _data = result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : result);
      } else {
        setState(() => _error = result['error'] ?? 'Erro ao carregar');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro de conexão');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    final code = _data?['referral_code'] ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado!'),
        backgroundColor: Color(0xFF00C977),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareCode() async {
    final code = _data?['referral_code'] ?? '';
    if (code.isEmpty) return;
    final shareText = 'Agende serviços automotivos pelo MECA! Use meu código $code no cadastro. Baixe: https://www.mecabr.com/app/?ref=$code';
    try {
      Rect? shareOrigin;
      final renderObj = _shareButtonKey.currentContext?.findRenderObject();
      if (renderObj is RenderBox && renderObj.hasSize) {
        final pos = renderObj.localToGlobal(Offset.zero);
        shareOrigin = pos & renderObj.size;
      }
      await Share.share(
        shareText,
        subject: 'Código de indicação MECA',
        sharePositionOrigin: shareOrigin,
      );
    } catch (e) {
      debugPrint('[MECA] Share error: $e');
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texto copiado! Cole e envie para seus amigos.'),
          backgroundColor: Color(0xFF00C977),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final isDark = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
            title: Text(
              'Indique e Ganhe',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00C977)),
                  )
                : _error != null
                    ? _buildError(isDark)
                    : _buildContent(isDark),
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
          Icon(Icons.error_outline, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final code = _data?['referral_code'] ?? '';
    final totalReferred = _data?['total_referred'] ?? 0;
    final successfulReferrals = _data?['successful_referrals'] ?? 0;
    final pendingReferrals = _data?['pending_referrals'] ?? 0;
    final referrals = List<Map<String, dynamic>>.from(
      _data?['referrals'] ?? [],
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF00C977),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCodeCard(isDark, code),
            const SizedBox(height: 16),
            _buildStatsRow(isDark, totalReferred, successfulReferrals, pendingReferrals),
            const SizedBox(height: 24),
            _buildHowItWorks(isDark),
            const SizedBox(height: 24),
            if (referrals.isNotEmpty) ...[
              Text(
                'Suas Indicações',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              ...referrals.map((r) => _buildReferralTile(isDark, r)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(bool isDark, String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C977), Color(0xFF00A063)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'GANHE 10% OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Seu código de indicação',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: code.isNotEmpty
                ? Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  )
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: code.isNotEmpty ? _copyCode : null,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white38,
                    side: BorderSide(color: code.isNotEmpty ? Colors.white54 : Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  key: _shareButtonKey,
                  onPressed: code.isNotEmpty ? _shareCode : null,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Compartilhar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00C977),
                    disabledBackgroundColor: Colors.white38,
                    disabledForegroundColor: const Color(0xFF00C977).withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    bool isDark,
    int totalReferred,
    int successfulReferrals,
    int pendingReferrals,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(isDark, 'Indicados', '$totalReferred', Icons.people),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(isDark, 'Sucesso', '$successfulReferrals', Icons.check_circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(isDark, 'Pendentes', '$pendingReferrals', Icons.hourglass_empty),
        ),
      ],
    );
  }

  Widget _buildStatCard(bool isDark, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00C977)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
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
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como funciona',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          _buildStep(isDark, '1', 'Compartilhe seu código com amigos'),
          _buildStep(isDark, '2', 'Seu amigo se cadastra usando o código'),
          _buildStep(isDark, '3', 'Quando ele paga o 1º serviço, você ganha 10% OFF'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00C977).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFF00C977),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O cupom de 10% OFF vale em qualquer serviço acima de R\$100. Válido por 90 dias.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              color: const Color(0xFF00C977).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF00C977),
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

  Widget _buildReferralTile(bool isDark, Map<String, dynamic> r) {
    final status = r['status'] ?? 'pending';
    final referredName = r['referred_name'] ?? 'Amigo';
    final createdAt = r['created_at'] ?? '';
    final isGranted = status == 'granted';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isGranted ? const Color(0xFF00C977) : Colors.orange)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGranted ? Icons.check_circle : Icons.hourglass_empty,
              color: isGranted ? const Color(0xFF00C977) : Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referredName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isGranted ? const Color(0xFF00C977) : Colors.orange)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isGranted ? 'Concluído' : 'Pendente',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isGranted ? const Color(0xFF00C977) : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
