import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

enum AlertStatus {
  reproved,
  withTime,
  info,
  waitingApproveBudget,
  waitingCarParts;

  Color get color {
    return switch (this) {
      AlertStatus.reproved => AppColors.redAlertColor,
      _ => AppColors.halfBaked,
    };
  }
}
