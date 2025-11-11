import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class BookingEvidenceScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> booking;

  const BookingEvidenceScreen({
    Key? key,
    required this.bookingId,
    required this.booking,
  }) : super(key: key);

  @override
  State<BookingEvidenceScreen> createState() => _BookingEvidenceScreenState();
}

class _BookingEvidenceScreenState extends State<BookingEvidenceScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _evidence = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getBookingEvidence(widget.bookingId);
      
      if (result['success']) {
        setState(() {
          final data = result['data'];
          if (data is List) {
            _evidence = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          } else if (data is Map && data['evidence'] is List) {
            _evidence = List<Map<String, dynamic>>.from(
              (data['evidence'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
            );
          } else {
            _evidence = [];
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar evidências';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: ${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Provas da Oficina',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando provas...')
          : _error.isNotEmpty
              ? _buildErrorView()
              : _buildEvidenceContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvidence,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C977)),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceContent() {
    if (_evidence.isEmpty) {
      return _buildEmptyEvidence();
    }

    return Column(
      children: [
        _buildBookingInfo(),
        Expanded(
          child: _buildEvidenceGrid(),
        ),
      ],
    );
  }

  Widget _buildBookingInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.booking['service']?['name'] ?? 'Serviço',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.booking['workshop']?['name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip('Data', _formatDate(widget.booking['scheduled_date'])),
              const SizedBox(width: 12),
              _buildInfoChip('Provas', '${_evidence.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyEvidence() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.photo_camera,
                size: 60,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhuma prova enviada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A oficina ainda não enviou provas\ndo serviço realizado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _evidence.length,
      itemBuilder: (context, index) {
        final evidence = _evidence[index];
        return _buildEvidenceCard(evidence, index);
      },
    );
  }

  Widget _buildEvidenceCard(Map<String, dynamic> evidence, int index) {
    return GestureDetector(
      onTap: () => _showEvidenceFullScreen(evidence, index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Imagem da evidência
              CachedNetworkImage(
                imageUrl: evidence['signedUrl'] ?? '',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C977),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 40,
                  ),
                ),
              ),
              
              // Overlay com informações
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        evidence['fileName'] ?? 'Arquivo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Toque para ampliar',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEvidenceFullScreen(Map<String, dynamic> evidence, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvidenceFullScreen(
          evidence: evidence,
          allEvidence: _evidence,
          initialIndex: index,
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}

class EvidenceFullScreen extends StatefulWidget {
  final Map<String, dynamic> evidence;
  final List<Map<String, dynamic>> allEvidence;
  final int initialIndex;

  const EvidenceFullScreen({
    Key? key,
    required this.evidence,
    required this.allEvidence,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<EvidenceFullScreen> createState() => _EvidenceFullScreenState();
}

class _EvidenceFullScreenState extends State<EvidenceFullScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Prova ${_currentIndex + 1} de ${widget.allEvidence.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.allEvidence.length,
        itemBuilder: (context, index) {
          final evidence = widget.allEvidence[index];
          return Center(
            child: CachedNetworkImage(
              imageUrl: evidence['signedUrl'] ?? '',
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00C977),
                ),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}












