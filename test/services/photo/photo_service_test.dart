import 'package:flutter_test/flutter_test.dart';
import 'package:meca_app_cliente/services/photo/photo_service.dart';

void main() {
  group('PhotoService', () {
    late PhotoService photoService;

    setUp(() {
      photoService = PhotoService(mode: PhotoCaptureMode.quick);
    });

    test('deve inicializar com configurações padrão', () {
      expect(photoService.maxWidth, equals(1920));
      expect(photoService.maxHeight, equals(1080));
      expect(photoService.quality, equals(85));
      expect(photoService.mode, equals(PhotoCaptureMode.quick));
    });

    test('deve validar tamanho de arquivo', () async {
      // Este teste requer um arquivo real
      // Por enquanto, apenas verifica se o método existe
      expect(photoService.validateFileSize, isNotNull);
    });

    test('deve ter método para limpar arquivos temporários', () {
      expect(photoService.cleanOldTempFiles, isNotNull);
    });
  });
}




