import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import 'workshop_detail_screen.dart';

class FavoriteWorkshopsScreen extends StatefulWidget {
  const FavoriteWorkshopsScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteWorkshopsScreen> createState() => _FavoriteWorkshopsScreenState();
}

class _FavoriteWorkshopsScreenState extends State<FavoriteWorkshopsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _favorites = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final workshops = await _apiService.getFavoriteWorkshops();
      if (!mounted) return;
      setState(() {
        _favorites = workshops;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar oficinas favoritas';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(String workshopId, int index) async {
    try {
      await _apiService.toggleWorkshopFavorite(workshopId);
      if (!mounted) return;
      setState(() {
        _favorites.removeAt(index);
      });
    } catch (e) {
      // Silenciar erro
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
            title: Text(
              'Oficinas Favoritas',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : _error.isNotEmpty
                  ? _buildErrorView(isDark)
                  : _favorites.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _loadFavorites,
                          color: const Color(0xFF00C977),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _favorites.length,
                            itemBuilder: (context, index) {
                              return _buildFavoriteCard(_favorites[index], index, isDark);
                            },
                          ),
                        ),
        );
      },
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFavorites,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                foregroundColor: Colors.white,
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma oficina favoritada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Você ainda não favoritou nenhuma oficina.\nToque no coração na página de uma oficina para adicioná-la aqui.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(dynamic workshop, int index, bool isDark) {
    final name = (workshop['name'] ?? 'Oficina').toString();
    final workshopId = workshop['id']?.toString() ?? '';
    final rawLogo = workshop['logo_url']?.toString() ?? '';
    final logoUrl = rawLogo.isNotEmpty && rawLogo.startsWith('http') ? rawLogo : null;

    final ratingRaw = workshop['rating'] ?? workshop['average_rating'];
    double? rating;
    if (ratingRaw is num) rating = ratingRaw.toDouble();
    if (ratingRaw is String) rating = double.tryParse(ratingRaw);

    final address = (workshop['address'] ?? '').toString();
    final city = (workshop['city'] ?? '').toString();
    final locationText = address.isNotEmpty ? address : (city.isNotEmpty ? city : 'Localização não informada');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFF00C977).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFF00C977).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkshopDetailScreen(workshopId: workshopId),
              ),
            ).then((_) {
              if (mounted) _loadFavorites();
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo — mesmo estilo da tela principal
                    Builder(
                      builder: (context) {
                        if (logoUrl == null) {
                          return Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.store_outlined,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                              size: 28,
                            ),
                          );
                        }
                        return Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00C977).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              width: 70,
                              height: 70,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.store_outlined,
                                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF00C977) : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF00C977),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationText,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  (rating != null && rating > 0 && rating <= 5)
                                      ? rating.toStringAsFixed(1)
                                      : '-',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final id = workshop['id'];
                        if (id != null) {
                          _toggleFavorite(id.toString(), index);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.favorite,
                          color: Color(0xFFFF4B6E),
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C977), Color(0xFF00B369)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ver Detalhes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
