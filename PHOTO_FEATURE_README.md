# 📸 Funcionalidade de Captura e Upload de Fotos

## 📋 Visão Geral

Implementação completa e robusta do botão "Tirar Foto" no app cliente MECA, com suporte a:
- ✅ Captura de fotos via câmera nativa
- ✅ Seleção de fotos da galeria
- ✅ Compressão e redimensionamento automático
- ✅ Upload com progresso
- ✅ Gerenciamento de permissões nativo (iOS/Android)
- ✅ Limpeza automática de arquivos temporários

## 🏗️ Arquitetura

### Serviços Criados

1. **PhotoService** (`lib/services/photo/photo_service.dart`)
   - Gerencia captura de fotos (modo rápido com `image_picker`)
   - Verifica e solicita permissões
   - Comprime e redimensiona imagens
   - Suporta dois modos: `quick` (image_picker) e `advanced` (camera package - futuro)

2. **PhotoRepository** (`lib/services/photo/photo_repository.dart`)
   - Gerencia arquivos temporários
   - Limpeza automática de arquivos antigos
   - Isolamento de armazenamento temporário

3. **UploadService** (`lib/services/photo/upload_service.dart`)
   - Upload multipart/form-data via Dio
   - Suporte a progresso de upload
   - Tratamento completo de erros
   - Upload de múltiplas imagens

### Widgets Criados

1. **PhotoGridWidget** (`lib/widgets/photo/photo_grid_widget.dart`)
   - Exibe grid de thumbnails
   - Botão de remoção por foto
   - Limite configurável de fotos

2. **UploadProgressWidget** (`lib/widgets/photo/upload_progress_widget.dart`)
   - Exibe progresso de upload
   - Estados: pending, uploading, success, error
   - Botões de retry e cancelamento

3. **TakePhotoButton** (`lib/widgets/photo/take_photo_button.dart`)
   - Botão reutilizável para captura
   - Integração automática com PhotoService

## 📦 Dependências Adicionadas

```yaml
flutter_image_compress: ^2.3.0  # Compressão de imagens
path_provider: ^2.1.5            # Diretórios temporários
camera: ^0.11.0+1                # Modo avançado (futuro)
```

## ⚙️ Configuração

### Android (`android/app/src/main/AndroidManifest.xml`)

Permissões já adicionadas:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### iOS (`ios/Runner/Info.plist`)

Chaves já adicionadas:
```xml
<key>NSCameraUsageDescription</key>
<string>Precisamos acessar a câmera para tirar fotos do serviço.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Precisamos acessar a galeria para selecionar fotos do serviço.</string>
```

## 🚀 Como Usar

### Exemplo Básico

```dart
import 'package:meca_app_cliente/services/photo/photo_service.dart';
import 'package:meca_app_cliente/services/photo/upload_service.dart';

// Inicializar serviços
final photoService = PhotoService(mode: PhotoCaptureMode.quick);
final uploadService = UploadService();

// Capturar foto
final result = await photoService.takePhoto();
if (result.success && result.file != null) {
  // Fazer upload
  final uploadResult = await uploadService.uploadImage(
    result.file!,
    bookingId,
    onProgress: (progress) {
      print('Progresso: ${progress.percentage}%');
    },
  );
}
```

### Integração no BookingScreen

O `BookingScreen` já está integrado com os novos serviços:
- Botão "Tirar Foto" com limite de 5 fotos
- Grid de thumbnails com remoção
- Upload automático após criação do agendamento
- Limpeza de arquivos temporários após upload

## 🧪 Testes

### Testes Unitários

Execute os testes:
```bash
flutter test test/services/photo/photo_service_test.dart
flutter test test/services/photo/upload_service_test.dart
```

### Testes de Integração

Para testar o fluxo completo:
1. Execute o app em dispositivo físico (iOS ou Android)
2. Navegue até a tela de agendamento
3. Clique em "Tirar Foto"
4. Conceda permissão quando solicitado
5. Tire uma foto
6. Verifique se o thumbnail aparece
7. Crie o agendamento
8. Verifique se o upload ocorre

### Testes de Permissões

**iOS Simulator:**
- Permissões são simuladas, mas não há câmera real
- Use dispositivo físico para testes completos

**Android Emulator:**
- Permissões funcionam normalmente
- Câmera pode ser simulada via webcam do computador

**Dispositivo Físico (Recomendado):**
- Teste todos os cenários de permissão:
  - Primeira vez (solicitar)
  - Negada temporariamente
  - Negada permanentemente (abrir configurações)

## 🔧 Configurações Avançadas

### Ajustar Limite de Fotos

No `BookingScreen`, altere:
```dart
static const int maxPhotos = 5; // Altere para o valor desejado
```

### Ajustar Qualidade de Compressão

No `PhotoService`, altere:
```dart
PhotoService(
  maxWidth: 1920,    // Largura máxima
  maxHeight: 1080,   // Altura máxima
  quality: 85,       // Qualidade (0-100)
)
```

### Endpoint de Upload

O endpoint padrão é:
```
POST /api/bookings/{bookingId}/images
```

Para alterar, edite `UploadService`:
```dart
final response = await _dio.post(
  '/api/bookings/$bookingId/images', // Altere aqui
  ...
);
```

## 🐛 Troubleshooting

### Erro: "Permissão negada"
- Verifique se as permissões estão no AndroidManifest.xml e Info.plist
- No iOS, limpe o app e reinstale (permite solicitar permissão novamente)
- No Android, vá em Configurações > Apps > Meca > Permissões

### Erro: "Câmera não disponível"
- Verifique se o dispositivo tem câmera
- No emulador Android, configure webcam
- No iOS Simulator, use dispositivo físico

### Erro: "Upload falhou"
- Verifique conexão com internet
- Verifique se o token de autenticação está válido
- Verifique logs do servidor
- Verifique se o endpoint está correto

### Imagens muito grandes
- Ajuste `maxWidth`, `maxHeight` e `quality` no PhotoService
- O limite padrão é 3MB por arquivo

## 📊 Telemetria (Opcional)

Para adicionar analytics, edite `PhotoService.takePhoto()`:
```dart
// Após captura bem-sucedida
analytics.logEvent('photo_taken', {
  'file_size': fileSize,
  'compressed_size': compressedSize,
});
```

## 🔒 Segurança

- ✅ Arquivos temporários são armazenados em diretório privado do app
- ✅ Limpeza automática após upload bem-sucedido
- ✅ Validação de tamanho de arquivo antes do upload
- ✅ Comunicação via HTTPS (configurado no ApiService)
- ✅ Token Bearer incluído automaticamente no upload

## 📝 Checklist de Aceitação

- [x] Botão "Tirar Foto" funcional
- [x] Permissões tratadas corretamente (granted, denied, permanentlyDenied)
- [x] Diálogos nativos (iOS Cupertino, Android Material)
- [x] Captura de foto funcional
- [x] Thumbnails exibidos corretamente
- [x] Remoção de fotos funcional
- [x] Limite de fotos respeitado (5 fotos)
- [x] Compressão e redimensionamento automático
- [x] Upload com progresso
- [x] Limpeza de arquivos temporários
- [x] Tratamento de erros completo
- [x] Compatível com iOS e Android

## 🎯 Próximos Passos (Opcional)

1. **Modo Avançado (camera package)**
   - Implementar `takePhotoAdvanced()` no PhotoService
   - Criar widget de preview customizado
   - Adicionar controles de foco, flash, etc.

2. **Background Upload**
   - Usar WorkManager (Android) / Background Tasks (iOS)
   - Enfileirar uploads quando offline
   - Retry automático

3. **Preview Fullscreen**
   - Adicionar visualização em tela cheia
   - Edição básica (crop, rotate)

4. **Cache Inteligente**
   - Manter thumbnails em cache
   - Lazy loading de imagens grandes

## 📚 Referências

- [image_picker package](https://pub.dev/packages/image_picker)
- [flutter_image_compress](https://pub.dev/packages/flutter_image_compress)
- [permission_handler](https://pub.dev/packages/permission_handler)
- [camera package](https://pub.dev/packages/camera)

---

**Versão:** 1.0.0  
**Data:** 2024  
**Autor:** MECA Development Team




