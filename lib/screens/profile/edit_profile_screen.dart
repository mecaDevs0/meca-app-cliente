import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../utils/cpf_formatter.dart';
import '../../utils/email_formatter.dart';
import '../../utils/formatters.dart';
import '../../utils/phone_formatter.dart';
import '../../widgets/app_alerts.dart';

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
  bool _canEditCpf = false;
  String? _originalCpf;
  DateTime? _birthDate;

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

        _firstNameController.text =
            (userData['first_name'] ?? userData['firstName'] ?? userData['name'] ?? '').toString();
        _lastNameController.text = (userData['last_name'] ?? userData['lastName'] ?? '').toString();
        _emailController.text = (userData['email'] ?? '').toString();
        // Formatar telefone ao carregar
        final phoneValue = userData['phone'] ?? userData['phone_number'] ?? '';
        _phoneController.text = Formatters.formatPhone(phoneValue.toString());

        final cpfValue = userData['cpf'] ??
            userData['document'] ??
            userData['cpf_number'] ??
            userData['document_number'] ??
            '';

        String cpfFormatted = cpfValue.toString().replaceAll(RegExp(r'\D'), '');
        if (cpfFormatted.length == 11) {
          cpfFormatted =
              '${cpfFormatted.substring(0, 3)}.${cpfFormatted.substring(3, 6)}.${cpfFormatted.substring(6, 9)}-${cpfFormatted.substring(9)}';
        }

        _cpfController.text = cpfFormatted;

        final canEditCpf = cpfValue == null ||
            cpfValue.toString().trim().isEmpty ||
            cpfValue.toString() == 'null' ||
            cpfFormatted.isEmpty;

        // Armazenar CPF original (apenas dígitos) para sempre enviar
        final cpfDigits = cpfFormatted.replaceAll(RegExp(r'\D'), '');
        if (cpfDigits.length == 11) {
          _originalCpf = cpfDigits;
        } else {
          _originalCpf = null;
        }

        final birthDateRaw = userData['birth_date'] ?? userData['birthDate'];
        DateTime? parsedBirthDate;
        if (birthDateRaw != null && birthDateRaw.toString().isNotEmpty) {
          parsedBirthDate = DateTime.tryParse(birthDateRaw.toString());
        }

        if (mounted) {
          setState(() {
            _canEditCpf = canEditCpf;
            _birthDate = parsedBirthDate;
          });
        }
      } else {
        if (!mounted) return;
        AppAlerts.showError(
          context,
          message: result['error'] != null
              ? 'Não foi possível carregar seu perfil: ${result['error']}'
              : 'Não foi possível carregar seu perfil agora. Tente novamente.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível carregar seu perfil agora. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      // Preparar CPF: se pode editar, usar o valor do campo; senão, usar o original
      String? cpfValue;
      if (_canEditCpf) {
        final cpfDigits = _cpfController.text.trim().replaceAll(RegExp(r'\D'), '');
        if (cpfDigits.length == 11) {
          cpfValue = cpfDigits;
        }
      } else {
        // Se não pode editar, sempre enviar o CPF original para não perder
        cpfValue = _originalCpf;
      }
      
      final payload = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim().replaceAll(RegExp(r'\D'), ''),
        if (cpfValue != null) 'cpf': cpfValue,
        'birth_date': _birthDate != null
            ? DateFormat('yyyy-MM-dd').format(_birthDate!)
            : null,
      };

      final result = await _apiService.updateProfile(payload);

      if (!mounted) return;

      if (result['success'] == true) {
        // Invalidar cache ANTES de retornar para garantir dados atualizados
        _apiService.invalidateProfileCache();
        // Aguardar um pouco para garantir que o cache foi invalidado
        await Future.delayed(const Duration(milliseconds: 100));
        // Usar Future.microtask para evitar crash ao navegar
        Future.microtask(() {
          if (mounted) {
            Navigator.pop(context, true);
            // Mostrar sucesso após navegar
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                AppAlerts.showSuccess(
                  context,
                  message: 'Perfil atualizado com sucesso!',
                );
              }
            });
          }
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] != null
              ? 'Erro ao atualizar perfil: ${result['error']}'
              : 'Não foi possível atualizar seu perfil agora. Tente novamente.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível atualizar seu perfil agora. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Editar Perfil',
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : const Color(0xFF252940),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            // Botão de salvar removido do header - apenas no final do formulário
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
                          label: 'Sobrenome (opcional)',
                          icon: Icons.person_outline,
                          // Campo opcional - não há validação obrigatória
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          inputFormatters: [EmailFormatter()],
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
                            LengthLimitingTextInputFormatter(14),
                          ],
                          enabled: _canEditCpf,
                          validator: (value) {
                            if (_canEditCpf && (value == null || value.isEmpty)) {
                              return 'Por favor, insira seu CPF';
                            }
                            if (_canEditCpf && value != null) {
                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length != 11) {
                                return 'CPF deve ter 11 dígitos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildBirthDateField(),
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
        final isDarkMode = themeService.isDarkMode;
        final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
        final disabledBorderColor = isDarkMode ? Colors.grey[800]! : Colors.grey[400]!;

        return TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF00C977)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
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
              borderSide: BorderSide(color: disabledBorderColor),
            ),
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBirthDateField() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;
        final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

        final displayText = _birthDate != null
            ? DateFormat('dd/MM/yyyy').format(_birthDate!)
            : '';

        return GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthDate ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              locale: const Locale('pt', 'BR'),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: const Color(0xFF00C977),
                      onPrimary: Colors.white,
                      surface: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                      onSurface: isDarkMode ? Colors.white : Colors.black,
                    ),
                    dialogBackgroundColor:
                        isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && mounted) {
              setState(() => _birthDate = picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Data de Nascimento',
              prefixIcon: const Icon(Icons.cake, color: Color(0xFF00C977)),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            child: Text(
              displayText.isEmpty ? 'Toque para selecionar' : displayText,
              style: TextStyle(
                color: displayText.isEmpty
                    ? (isDarkMode ? Colors.grey[500] : Colors.grey[400])
                    : (isDarkMode ? Colors.white : Colors.black),
                fontSize: 16,
              ),
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



