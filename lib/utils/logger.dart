import 'package:flutter/foundation.dart';

/// Sistema de logs organizado e claro para o app MECA
class AppLogger {
  static const String _prefix = '🔵 MECA';
  
  /// Log de informação geral
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      final tagStr = tag != null ? '[$tag]' : '';
      print('$timestamp $_prefix ℹ️  $tagStr $message');
    }
  }
  
  /// Log de sucesso
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      final tagStr = tag != null ? '[$tag]' : '';
      print('$timestamp $_prefix ✅ $tagStr $message');
    }
  }
  
  /// Log de erro
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      final tagStr = tag != null ? '[$tag]' : '';
      print('$timestamp $_prefix ❌ $tagStr $message');
      if (error != null) {
        print('$timestamp $_prefix    └─ Erro: $error');
      }
      if (stackTrace != null && kDebugMode) {
        print('$timestamp $_prefix    └─ Stack: $stackTrace');
      }
    }
  }
  
  /// Log de warning
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      final tagStr = tag != null ? '[$tag]' : '';
      print('$timestamp $_prefix ⚠️  $tagStr $message');
    }
  }
  
  /// Log de requisição API
  static void api(String method, String endpoint, {int? statusCode, String? error}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      if (error != null) {
        print('$timestamp $_prefix 🌐 [$method] $endpoint ❌ $error');
      } else if (statusCode != null) {
        final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '⚠️';
        print('$timestamp $_prefix 🌐 [$method] $endpoint $emoji $statusCode');
      } else {
        print('$timestamp $_prefix 🌐 [$method] $endpoint');
      }
    }
  }
  
  /// Log de cache
  static void cache(String action, String key) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      print('$timestamp $_prefix 💾 Cache: $action $key');
    }
  }
  
  /// Log de navegação
  static void navigation(String route, {Map<String, dynamic>? arguments}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      final argsStr = arguments != null ? ' (args: ${arguments.keys.join(", ")})' : '';
      print('$timestamp $_prefix 🧭 Navegação: $route$argsStr');
    }
  }
  
  /// Limpar logs (não faz nada, apenas para compatibilidade)
  static void clear() {
    // Não implementado - logs são temporários
  }
}


