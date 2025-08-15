import 'package:flutter/material.dart';

import '../../../../../../core/app_colors.dart';
import '../../../../../../core/utils/workshop_name_helper.dart';
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
    // Debug logs
    print('🔧 [MechanicWorkshopNameRow] Workshop ID: ${mechanicWorkshop.id}');
    print('🔧 [MechanicWorkshopNameRow] CompanyName: "${mechanicWorkshop.companyName}"');
    print('🔧 [MechanicWorkshopNameRow] FullName: "${mechanicWorkshop.fullName}"');
    print('🔧 [MechanicWorkshopNameRow] AccountableName: "${mechanicWorkshop.accountableName}"');
    
    // Usar o helper para obter o nome do estabelecimento
    final displayName = WorkshopNameHelper.getDisplayName(mechanicWorkshop);
    
    print('🔧 [MechanicWorkshopNameRow] Display Name: "$displayName"');
    
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
