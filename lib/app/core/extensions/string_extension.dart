import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

extension StringExtension on String? {
  String get formattedPhone {
    if (this == null) {
      return '';
    }
    if (this!.length > 11) {
      return this!;
    }
    return UtilBrasilFields.obterTelefone(this!);
  }
}
