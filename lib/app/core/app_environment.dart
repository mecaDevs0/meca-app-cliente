import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons/shared/models/abbreviation.dart';

class Env {
  Env._();

  static Abbreviation get abbreviation {
    final EnvironmentUrl? envUrl = EnvironmentUrl.fromCache();
    return envUrl?.abbreviation ?? Abbreviation.production;
  }
}
