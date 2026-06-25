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

  Future<void> _toggleFavorite(int workshopId, int index) async {
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
              'Minhas Oficinas',
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

    final city = (workshop['city'] ?? '').toString();
    final neighborhood = (workshop['neighborhood'] ?? '').toString();
    final locationParts = [neighborhood, city].where((s) => s.isNotEmpty).toList();
    final locationText = locationParts.isNotEmpty ? locationParts.join(', ') : 'Localização não informada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: logoUrl != null
                        ? Image.network(
                            logoUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.store_outlined,
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                              size: 24,
                            ),
                          )
                        : Icon(
                            Icons.store_outlined,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (rating != null && rating > 0 && rating <= 5)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Heart + Arrow
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final id = workshop['id'];
                        if (id != null) {
                          _toggleFavorite(id is int ? id : int.tryParse(id.toString()) ?? 0, index);
                        }
                      },
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFF00C977),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
