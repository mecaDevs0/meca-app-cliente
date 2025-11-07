import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/cpf_formatter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _canEditCpf = false; // Se CPF pode ser editado

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getUserProfile();
      if (result['success'] == true) {
        final userData = result['data'] as Map<String, dynamic>;
        
        // Debug: imprimir dados recebidos
        print('🔍 Dados do perfil recebidos: $userData');
        
        // Tentar diferentes formatos de campos
        _firstNameController.text = (userData['first_name'] ?? userData['firstName'] ?? userData['name'] ?? '').toString();
        _lastNameController.text = (userData['last_name'] ?? userData['lastName'] ?? '').toString();
        _emailController.text = (userData['email'] ?? '').toString();
        _phoneController.text = (userData['phone'] ?? userData['phone_number'] ?? '').toString();
        
        // Tentar múltiplos formatos para CPF
        final cpfValue = userData['cpf'] ?? 
                        userData['document'] ?? 
                        userData['cpf_number'] ?? 
                        userData['document_number'] ?? 
                        '';
        
        // Formatar CPF se tiver valor (000.000.000-00)
        String cpfFormatted = cpfValue.toString().replaceAll(RegExp(r'\D'), '');
        if (cpfFormatted.length == 11) {
          cpfFormatted = '${cpfFormatted.substring(0, 3)}.${cpfFormatted.substring(3, 6)}.${cpfFormatted.substring(6, 9)}-${cpfFormatted.substring(9)}';
        }
        
        _cpfController.text = cpfFormatted;
        
        // Debug: imprimir CPF encontrado
        print('🔍 CPF encontrado: ${_cpfController.text}');
        
        // Determinar se CPF pode ser editado (se estiver vazio ou null)
        final canEditCpf = cpfValue == null || 
                          cpfValue.toString().trim().isEmpty || 
                          cpfValue.toString() == 'null' ||
                          cpfFormatted.isEmpty;
        
        // Forçar atualização do estado após setar valores
        if (mounted) {
          setState(() {
            _canEditCpf = canEditCpf;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${result['error']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Erro ao carregar perfil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await _apiService.updateProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'cpf': _canEditCpf ? _cpfController.text.trim().replaceAll(RegExp(r'\D'), '') : null,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
        await _loadProfileData();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Editar Perfil',
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00C977),
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Informações Pessoais'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'Nome',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu nome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Sobrenome',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu sobrenome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Por favor, insira um email válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Telefone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [PhoneInputFormatter()],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu telefone';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documentos'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cpfController,
                          label: _canEditCpf ? 'CPF *' : 'CPF',
                          icon: Icons.badge,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CpfFormatter(),
                            LengthLimitingTextInputFormatter(14), // 000.000.000-00 = 14 caracteres
                          ],
                          enabled: _canEditCpf,
                          validator: (value) {
                            if (_canEditCpf && (value == null || value.isEmpty)) {
                              return 'Por favor, insira seu CPF';
                            }
                            if (_canEditCpf && value != null) {
                              // Remove pontos e traços para contar apenas dígitos
                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length != 11) {
                                return 'CPF deve ter 11 dígitos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00C977),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF00C977)),
            filled: true,
            fillColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00C977),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
              ),
            ),
            labelStyle: TextStyle(
              color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Salvar Alterações',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/cpf_formatter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _canEditCpf = false; // Se CPF pode ser editado

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getUserProfile();
      if (result['success'] == true) {
        final userData = result['data'] as Map<String, dynamic>;
        
        // Debug: imprimir dados recebidos
        print('🔍 Dados do perfil recebidos: $userData');
        
        // Tentar diferentes formatos de campos
        _firstNameController.text = (userData['first_name'] ?? userData['firstName'] ?? userData['name'] ?? '').toString();
        _lastNameController.text = (userData['last_name'] ?? userData['lastName'] ?? '').toString();
        _emailController.text = (userData['email'] ?? '').toString();
        _phoneController.text = (userData['phone'] ?? userData['phone_number'] ?? '').toString();
        
        // Tentar múltiplos formatos para CPF
        final cpfValue = userData['cpf'] ?? 
                        userData['document'] ?? 
                        userData['cpf_number'] ?? 
                        userData['document_number'] ?? 
                        '';
        
        // Formatar CPF se tiver valor (000.000.000-00)
        String cpfFormatted = cpfValue.toString().replaceAll(RegExp(r'\D'), '');
        if (cpfFormatted.length == 11) {
          cpfFormatted = '${cpfFormatted.substring(0, 3)}.${cpfFormatted.substring(3, 6)}.${cpfFormatted.substring(6, 9)}-${cpfFormatted.substring(9)}';
        }
        
        _cpfController.text = cpfFormatted;
        
        // Debug: imprimir CPF encontrado
        print('🔍 CPF encontrado: ${_cpfController.text}');
        
        // Determinar se CPF pode ser editado (se estiver vazio ou null)
        final canEditCpf = cpfValue == null || 
                          cpfValue.toString().trim().isEmpty || 
                          cpfValue.toString() == 'null' ||
                          cpfFormatted.isEmpty;
        
        // Forçar atualização do estado após setar valores
        if (mounted) {
          setState(() {
            _canEditCpf = canEditCpf;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${result['error']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Erro ao carregar perfil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await _apiService.updateProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'cpf': _canEditCpf ? _cpfController.text.trim().replaceAll(RegExp(r'\D'), '') : null,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
        await _loadProfileData();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Editar Perfil',
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00C977),
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Informações Pessoais'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'Nome',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu nome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Sobrenome',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu sobrenome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Por favor, insira um email válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Telefone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [PhoneInputFormatter()],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu telefone';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documentos'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cpfController,
                          label: _canEditCpf ? 'CPF *' : 'CPF',
                          icon: Icons.badge,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CpfFormatter(),
                            LengthLimitingTextInputFormatter(14), // 000.000.000-00 = 14 caracteres
                          ],
                          enabled: _canEditCpf,
                          validator: (value) {
                            if (_canEditCpf && (value == null || value.isEmpty)) {
                              return 'Por favor, insira seu CPF';
                            }
                            if (_canEditCpf && value != null) {
                              // Remove pontos e traços para contar apenas dígitos
                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length != 11) {
                                return 'CPF deve ter 11 dígitos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00C977),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF00C977)),
            filled: true,
            fillColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00C977),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
              ),
            ),
            labelStyle: TextStyle(
              color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Salvar Alterações',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/cpf_formatter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _canEditCpf = false; // Se CPF pode ser editado

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getUserProfile();
      if (result['success'] == true) {
        final userData = result['data'] as Map<String, dynamic>;
        
        // Debug: imprimir dados recebidos
        print('🔍 Dados do perfil recebidos: $userData');
        
        // Tentar diferentes formatos de campos
        _firstNameController.text = (userData['first_name'] ?? userData['firstName'] ?? userData['name'] ?? '').toString();
        _lastNameController.text = (userData['last_name'] ?? userData['lastName'] ?? '').toString();
        _emailController.text = (userData['email'] ?? '').toString();
        _phoneController.text = (userData['phone'] ?? userData['phone_number'] ?? '').toString();
        
        // Tentar múltiplos formatos para CPF
        final cpfValue = userData['cpf'] ?? 
                        userData['document'] ?? 
                        userData['cpf_number'] ?? 
                        userData['document_number'] ?? 
                        '';
        
        // Formatar CPF se tiver valor (000.000.000-00)
        String cpfFormatted = cpfValue.toString().replaceAll(RegExp(r'\D'), '');
        if (cpfFormatted.length == 11) {
          cpfFormatted = '${cpfFormatted.substring(0, 3)}.${cpfFormatted.substring(3, 6)}.${cpfFormatted.substring(6, 9)}-${cpfFormatted.substring(9)}';
        }
        
        _cpfController.text = cpfFormatted;
        
        // Debug: imprimir CPF encontrado
        print('🔍 CPF encontrado: ${_cpfController.text}');
        
        // Determinar se CPF pode ser editado (se estiver vazio ou null)
        final canEditCpf = cpfValue == null || 
                          cpfValue.toString().trim().isEmpty || 
                          cpfValue.toString() == 'null' ||
                          cpfFormatted.isEmpty;
        
        // Forçar atualização do estado após setar valores
        if (mounted) {
          setState(() {
            _canEditCpf = canEditCpf;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${result['error']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Erro ao carregar perfil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await _apiService.updateProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'cpf': _canEditCpf ? _cpfController.text.trim().replaceAll(RegExp(r'\D'), '') : null,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
        await _loadProfileData();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Editar Perfil',
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00C977),
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Informações Pessoais'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'Nome',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu nome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Sobrenome',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu sobrenome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Por favor, insira um email válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Telefone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [PhoneInputFormatter()],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu telefone';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documentos'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cpfController,
                          label: _canEditCpf ? 'CPF *' : 'CPF',
                          icon: Icons.badge,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CpfFormatter(),
                            LengthLimitingTextInputFormatter(14), // 000.000.000-00 = 14 caracteres
                          ],
                          enabled: _canEditCpf,
                          validator: (value) {
                            if (_canEditCpf && (value == null || value.isEmpty)) {
                              return 'Por favor, insira seu CPF';
                            }
                            if (_canEditCpf && value != null) {
                              // Remove pontos e traços para contar apenas dígitos
                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length != 11) {
                                return 'CPF deve ter 11 dígitos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00C977),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF00C977)),
            filled: true,
            fillColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00C977),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
              ),
            ),
            labelStyle: TextStyle(
              color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Salvar Alterações',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/cpf_formatter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _canEditCpf = false; // Se CPF pode ser editado

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getUserProfile();
      if (result['success'] == true) {
        final userData = result['data'] as Map<String, dynamic>;
        
        // Debug: imprimir dados recebidos
        print('🔍 Dados do perfil recebidos: $userData');
        
        // Tentar diferentes formatos de campos
        _firstNameController.text = (userData['first_name'] ?? userData['firstName'] ?? userData['name'] ?? '').toString();
        _lastNameController.text = (userData['last_name'] ?? userData['lastName'] ?? '').toString();
        _emailController.text = (userData['email'] ?? '').toString();
        _phoneController.text = (userData['phone'] ?? userData['phone_number'] ?? '').toString();
        
        // Tentar múltiplos formatos para CPF
        final cpfValue = userData['cpf'] ?? 
                        userData['document'] ?? 
                        userData['cpf_number'] ?? 
                        userData['document_number'] ?? 
                        '';
        
        // Formatar CPF se tiver valor (000.000.000-00)
        String cpfFormatted = cpfValue.toString().replaceAll(RegExp(r'\D'), '');
        if (cpfFormatted.length == 11) {
          cpfFormatted = '${cpfFormatted.substring(0, 3)}.${cpfFormatted.substring(3, 6)}.${cpfFormatted.substring(6, 9)}-${cpfFormatted.substring(9)}';
        }
        
        _cpfController.text = cpfFormatted;
        
        // Debug: imprimir CPF encontrado
        print('🔍 CPF encontrado: ${_cpfController.text}');
        
        // Determinar se CPF pode ser editado (se estiver vazio ou null)
        final canEditCpf = cpfValue == null || 
                          cpfValue.toString().trim().isEmpty || 
                          cpfValue.toString() == 'null' ||
                          cpfFormatted.isEmpty;
        
        // Forçar atualização do estado após setar valores
        if (mounted) {
          setState(() {
            _canEditCpf = canEditCpf;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${result['error']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Erro ao carregar perfil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await _apiService.updateProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'cpf': _canEditCpf ? _cpfController.text.trim().replaceAll(RegExp(r'\D'), '') : null,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
        await _loadProfileData();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Editar Perfil',
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00C977),
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Informações Pessoais'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'Nome',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu nome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Sobrenome',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu sobrenome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Por favor, insira um email válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Telefone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [PhoneInputFormatter()],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu telefone';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documentos'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cpfController,
                          label: _canEditCpf ? 'CPF *' : 'CPF',
                          icon: Icons.badge,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CpfFormatter(),
                            LengthLimitingTextInputFormatter(14), // 000.000.000-00 = 14 caracteres
                          ],
                          enabled: _canEditCpf,
                          validator: (value) {
                            if (_canEditCpf && (value == null || value.isEmpty)) {
                              return 'Por favor, insira seu CPF';
                            }
                            if (_canEditCpf && value != null) {
                              // Remove pontos e traços para contar apenas dígitos
                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length != 11) {
                                return 'CPF deve ter 11 dígitos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00C977),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF00C977)),
            filled: true,
            fillColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00C977),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
              ),
            ),
            labelStyle: TextStyle(
              color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Salvar Alterações',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/cpf_formatter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _canEditCpf = false; // Se CPF pode ser editado

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getUserProfile();
      if (result['success'] == true) {
        final userData = result['data'] as Map<String, dynamic>;
        
        // Debug: imprimir dados recebidos
        print('🔍 Dados do perfil recebidos: $userData');
        
        // Tentar diferentes formatos de campos
        _firstNameController.text = (userData['first_name'] ?? userData['firstName'] ?? userData['name'] ?? '').toString();
        _lastNameController.text = (userData['last_name'] ?? userData['lastName'] ?? '').toString();
        _emailController.text = (userData['email'] ?? '').toString();
        _phoneController.text = (userData['phone'] ?? userData['phone_number'] ?? '').toString();
        
        // Tentar múltiplos formatos para CPF
        final cpfValue = userData['cpf'] ?? 
                        userData['document'] ?? 
                        userData['cpf_number'] ?? 
                        userData['document_number'] ?? 
                        '';
        
        // Formatar CPF se tiver valor (000.000.000-00)
        String cpfFormatted = cpfValue.toString().replaceAll(RegExp(r'\D'), '');
        if (cpfFormatted.length == 11) {
          cpfFormatted = '${cpfFormatted.substring(0, 3)}.${cpfFormatted.substring(3, 6)}.${cpfFormatted.substring(6, 9)}-${cpfFormatted.substring(9)}';
        }
        
        _cpfController.text = cpfFormatted;
        
        // Debug: imprimir CPF encontrado
        print('🔍 CPF encontrado: ${_cpfController.text}');
        
        // Determinar se CPF pode ser editado (se estiver vazio ou null)
        final canEditCpf = cpfValue == null || 
                          cpfValue.toString().trim().isEmpty || 
                          cpfValue.toString() == 'null' ||
                          cpfFormatted.isEmpty;
        
        // Forçar atualização do estado após setar valores
        if (mounted) {
          setState(() {
            _canEditCpf = canEditCpf;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: ${result['error']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Erro ao carregar perfil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await _apiService.updateProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'cpf': _canEditCpf ? _cpfController.text.trim().replaceAll(RegExp(r'\D'), '') : null,
      });

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
        await _loadProfileData();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Editar Perfil',
              style: TextStyle(
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: themeService.isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00C977),
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Informações Pessoais'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'Nome',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu nome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Sobrenome',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu sobrenome';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Por favor, insira um email válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Telefone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [PhoneInputFormatter()],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor, insira seu telefone';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Documentos'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cpfController,
                          label: _canEditCpf ? 'CPF *' : 'CPF',
                          icon: Icons.badge,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CpfFormatter(),
                            LengthLimitingTextInputFormatter(14), // 000.000.000-00 = 14 caracteres
                          ],
                          enabled: _canEditCpf,
                          validator: (value) {
                            if (_canEditCpf && (value == null || value.isEmpty)) {
                              return 'Por favor, insira seu CPF';
                            }
                            if (_canEditCpf && value != null) {
                              // Remove pontos e traços para contar apenas dígitos
                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length != 11) {
                                return 'CPF deve ter 11 dígitos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00C977),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: themeService.isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF00C977)),
            filled: true,
            fillColor: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00C977),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: themeService.isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
              ),
            ),
            labelStyle: TextStyle(
              color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Salvar Alterações',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
