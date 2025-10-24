import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';
import 'service_detail_screen.dart';

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({Key? key}) : super(key: key);

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _filteredServices = [];
  bool _loading = true;
  String _error = '';
  
  // Filtros e pesquisa
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Todos';
  String _selectedPriceRange = 'Todos';
  String _selectedDuration = 'Todos';
  String _sortBy = 'nome';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getServices();
      if (result['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _filteredServices = List.from(_services);
          _loading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao carregar serviços';
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

  void _applyFilters() {
    setState(() {
      _filteredServices = _services.where((service) {
        // Filtro por pesquisa
        if (_searchController.text.isNotEmpty) {
          final searchText = _searchController.text.toLowerCase();
          final name = (service['name'] ?? '').toString().toLowerCase();
          final description = (service['description'] ?? '').toString().toLowerCase();
          if (!name.contains(searchText) && !description.contains(searchText)) {
            return false;
          }
        }

        // Filtro por categoria
        if (_selectedCategory != 'Todos') {
          final category = service['category'] ?? '';
          if (category != _selectedCategory) {
            return false;
          }
        }

        // Filtro por faixa de preço
        if (_selectedPriceRange != 'Todos') {
          final price = double.tryParse(service['price']?.toString() ?? '0') ?? 0;
          switch (_selectedPriceRange) {
            case 'Até R\$ 50':
              if (price > 50) return false;
              break;
            case 'R\$ 50 - R\$ 100':
              if (price < 50 || price > 100) return false;
              break;
            case 'R\$ 100 - R\$ 200':
              if (price < 100 || price > 200) return false;
              break;
            case 'Acima de R\$ 200':
              if (price < 200) return false;
              break;
          }
        }

        // Filtro por duração
        if (_selectedDuration != 'Todos') {
          final duration = int.tryParse(service['duration']?.toString() ?? '0') ?? 0;
          switch (_selectedDuration) {
            case 'Até 30 min':
              if (duration > 30) return false;
              break;
            case '30 - 60 min':
              if (duration < 30 || duration > 60) return false;
              break;
            case '60 - 120 min':
              if (duration < 60 || duration > 120) return false;
              break;
            case 'Acima de 120 min':
              if (duration < 120) return false;
              break;
          }
        }

        return true;
      }).toList();

      // Ordenação
      _filteredServices.sort((a, b) {
        switch (_sortBy) {
          case 'nome':
            final nameA = (a['name'] ?? '').toString().toLowerCase();
            final nameB = (b['name'] ?? '').toString().toLowerCase();
            return nameA.compareTo(nameB);
          case 'preco':
            final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceA.compareTo(priceB);
          case 'duracao':
            final durationA = int.tryParse(a['duration']?.toString() ?? '0') ?? 0;
            final durationB = int.tryParse(b['duration']?.toString() ?? '0') ?? 0;
            return durationA.compareTo(durationB);
          default:
            return 0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Serviços',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showFilterModal,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
          ),
        ],
      ),
      body: _loading
          ? const MecaApiLoadingWidget(message: 'Carregando serviços...')
          : _error.isNotEmpty
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildSearchBar(),
                    _buildFilterChips(),
                    Expanded(child: _buildServicesList()),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar serviços',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Tentar Novamente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _applyFilters(),
        decoration: InputDecoration(
          hintText: 'Pesquisar serviços...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF00C977)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF1E1E1E) 
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[700]! 
                  : Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[700]! 
                  : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('Categoria', _selectedCategory),
          const SizedBox(width: 8),
          _buildFilterChip('Preço', _selectedPriceRange),
          const SizedBox(width: 8),
          _buildFilterChip('Duração', _selectedDuration),
          const SizedBox(width: 8),
          _buildFilterChip('Ordenar', _getSortLabel()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return GestureDetector(
      onTap: () => _showFilterModal(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF00C977).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00C977).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: const TextStyle(
                color: Color(0xFF00C977),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF00C977),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'nome':
        return 'Nome';
      case 'preco':
        return 'Preço';
      case 'duracao':
        return 'Duração';
      default:
        return 'Nome';
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'Todos';
                        _selectedPriceRange = 'Todos';
                        _selectedDuration = 'Todos';
                        _sortBy = 'nome';
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Limpar',
                      style: TextStyle(color: Color(0xFF00C977)),
                    ),
                  ),
                ],
              ),
            ),
            // Filtros
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection(
                      'Categoria',
                      _selectedCategory,
                      ['Todos', 'Mecânica', 'Elétrica', 'Freios', 'Suspensão', 'Motor'],
                      (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterSection(
                      'Faixa de Preço',
                      _selectedPriceRange,
                      ['Todos', 'Até R\$ 50', 'R\$ 50 - R\$ 100', 'R\$ 100 - R\$ 200', 'Acima de R\$ 200'],
                      (value) {
                        setState(() => _selectedPriceRange = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterSection(
                      'Duração',
                      _selectedDuration,
                      ['Todos', 'Até 30 min', '30 - 60 min', '60 - 120 min', 'Acima de 120 min'],
                      (value) {
                        setState(() => _selectedDuration = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFilterSection(
                      'Ordenar por',
                      _sortBy,
                      ['nome', 'preco', 'duracao'],
                      (value) {
                        setState(() => _sortBy = value);
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // Botões
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00C977)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C977),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Aplicar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      },
    );
  }

  Widget _buildFilterSection(
    String title,
    String selectedValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option == selectedValue;
            return GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00C977)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00C977)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildServicesList() {
    if (_filteredServices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhum serviço encontrado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tente ajustar os filtros ou termo de pesquisa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredServices.length,
      itemBuilder: (context, index) {
        final service = _filteredServices[index];
        return _buildServiceCard(service);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToServiceDetail(service),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.build,
                    color: Color(0xFF00C977),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'] ?? 'Serviço',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service['description'] ?? 'Descrição não disponível',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${service['duration'] ?? 60} min',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'A partir de R\$ ${service['price'] ?? '0,00'}',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF00C977),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToServiceDetail(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(
          serviceId: service['id'] ?? '',
          workshopId: service['workshop_id'] ?? '',
        ),
      ),
    );
  }
}
