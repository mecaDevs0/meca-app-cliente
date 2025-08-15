import 'package:flutter/material.dart';

class ColorHelper {
  static Color getColorFromName(String? colorName) {
    if (colorName == null || colorName.isEmpty) {
      return Colors.green; // Cor padrão verde
    }

    final normalizedColor = colorName.toLowerCase().trim();
    
    switch (normalizedColor) {
      case 'vermelho':
      case 'red':
        return Colors.red;
      case 'azul':
      case 'blue':
        return Colors.blue;
      case 'verde':
      case 'green':
        return Colors.green;
      case 'amarelo':
      case 'yellow':
        return Colors.yellow;
      case 'laranja':
      case 'orange':
        return Colors.orange;
      case 'roxo':
      case 'purple':
        return Colors.purple;
      case 'rosa':
      case 'pink':
        return Colors.pink;
      case 'marrom':
      case 'brown':
        return Colors.brown;
      case 'cinza':
      case 'gray':
      case 'grey':
        return Colors.grey;
      case 'preto':
      case 'black':
        return Colors.black;
      case 'branco':
      case 'white':
        return Colors.white;
      case 'prata':
      case 'silver':
        return Colors.grey[400]!;
      case 'dourado':
      case 'gold':
        return Colors.amber;
      case 'bege':
      case 'beige':
        return const Color(0xFFF5F5DC);
      case 'champagne':
        return const Color(0xFFF7E7CE);
      case 'grafite':
        return const Color(0xFF41424C);
      case 'azul marinho':
      case 'navy':
        return Colors.indigo;
      case 'verde escuro':
      case 'dark green':
        return Colors.green[800]!;
      case 'vermelho escuro':
      case 'dark red':
        return Colors.red[800]!;
      case 'azul claro':
      case 'light blue':
        return Colors.lightBlue;
      case 'verde claro':
      case 'light green':
        return Colors.lightGreen;
      default:
        return Colors.green; // Cor padrão verde
    }
  }
}
