import 'package:flutter_test/flutter_test.dart';
import 'package:meca_app_cliente/services/photo/upload_service.dart';

void main() {
  group('UploadService', () {
    late UploadService uploadService;

    setUp(() {
      uploadService = UploadService();
    });

    test('deve inicializar corretamente', () {
      expect(uploadService, isNotNull);
    });

    test('UploadProgress deve calcular porcentagem corretamente', () {
      final progress = UploadProgress(sent: 50, total: 100);
      expect(progress.percentage, equals(50.0));
    });

    test('UploadProgress deve retornar 0 quando total é 0', () {
      final progress = UploadProgress(sent: 0, total: 0);
      expect(progress.percentage, equals(0.0));
    });
  });
}




