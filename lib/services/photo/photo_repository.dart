import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Repository para gerenciar arquivos temporários de fotos
class PhotoRepository {
  static const String _tempPhotoPrefix = 'meca_photo_';
  static const String _tempPhotoExtension = '.jpg';
  
  /// Obtém o diretório temporário do app
  Future<Directory> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final photoDir = Directory(path.join(tempDir.path, 'photos'));
    
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    
    return photoDir;
  }
  
  /// Gera um caminho único para uma nova foto temporária
  Future<String> generateTempPhotoPath() async {
    final tempDir = await getTempDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$_tempPhotoPrefix$timestamp$_tempPhotoExtension';
    return path.join(tempDir.path, fileName);
  }
  
  /// Salva um arquivo temporário
  Future<File> saveTempFile(File sourceFile) async {
    final tempPath = await generateTempPhotoPath();
    return await sourceFile.copy(tempPath);
  }
  
  /// Lista todas as fotos temporárias
  Future<List<File>> listTempPhotos() async {
    final tempDir = await getTempDirectory();
    if (!await tempDir.exists()) {
      return [];
    }
    
    final files = tempDir.listSync()
        .whereType<File>()
        .where((file) => path.basename(file.path).startsWith(_tempPhotoPrefix))
        .toList();
    
    return files;
  }
  
  /// Remove uma foto temporária específica
  Future<bool> deleteTempPhoto(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Erro ao deletar foto temporária: $e');
      return false;
    }
  }
  
  /// Remove fotos temporárias mais antigas que a duração especificada
  Future<int> cleanTempFilesOlderThan(Duration maxAge) async {
    try {
      final tempDir = await getTempDirectory();
      if (!await tempDir.exists()) {
        return 0;
      }
      
      final now = DateTime.now();
      int deletedCount = 0;
      
      final files = await listTempPhotos();
      for (final file in files) {
        final stat = await file.stat();
        final age = now.difference(stat.modified);
        
        if (age > maxAge) {
          if (await deleteTempPhoto(file.path)) {
            deletedCount++;
          }
        }
      }
      
      return deletedCount;
    } catch (e) {
      print('Erro ao limpar fotos temporárias: $e');
      return 0;
    }
  }
  
  /// Limpa todas as fotos temporárias
  Future<int> cleanAllTempFiles() async {
    try {
      final files = await listTempPhotos();
      int deletedCount = 0;
      
      for (final file in files) {
        if (await deleteTempPhoto(file.path)) {
          deletedCount++;
        }
      }
      
      return deletedCount;
    } catch (e) {
      print('Erro ao limpar todas as fotos temporárias: $e');
      return 0;
    }
  }
  
  /// Obtém o tamanho total das fotos temporárias em bytes
  Future<int> getTotalTempFilesSize() async {
    try {
      final files = await listTempPhotos();
      int totalSize = 0;
      
      for (final file in files) {
        final stat = await file.stat();
        totalSize += stat.size;
      }
      
      return totalSize;
    } catch (e) {
      print('Erro ao calcular tamanho das fotos temporárias: $e');
      return 0;
    }
  }
}




