import 'package:flutter/material.dart';

import '../../../../../../core/app_colors.dart';
import '../../../../../../data/models/mechanic_workshop.dart';

class MechanicWorkshopNameRow extends StatelessWidget {
  const MechanicWorkshopNameRow({
    super.key,
    required this.mechanicWorkshop,
    this.isTablet = false, // Novo parâmetro para modo tablet
  });

  final MechanicWorkshop mechanicWorkshop;
  final bool isTablet; // Controla o tamanho dos textos em tablets

  @override
  Widget build(BuildContext context) {
    // Usar accountableName (nome fantasia) se disponível, senão usar fullName
    // Garantir que nunca seja null
    final displayName = mechanicWorkshop.accountableName?.isNotEmpty == true 
        ? mechanicWorkshop.accountableName! 
        : mechanicWorkshop.fullName ?? 'Oficina';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            displayName,
            style: TextStyle(
              color: AppColors.softBlackColor,
              fontWeight: FontWeight.w700,
              // Aumentar o tamanho da fonte em tablets
              fontSize: isTablet ? 18 : 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
