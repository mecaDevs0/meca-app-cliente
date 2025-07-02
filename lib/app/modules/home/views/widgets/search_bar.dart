import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onFilterTap,
    required this.hintText,
    required this.hasFilter,
    this.onSearchChanged,
    this.textStyle, // Novo parâmetro para customizar estilo do texto
  });
  final TextEditingController controller;
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onSearchChanged;
  final bool hasFilter;
  final String hintText;
  final TextStyle? textStyle; // Estilo de texto para personalização em tablets

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
              style: textStyle, // Aplicando o estilo de texto personalizado
            ),
          ),
          if (hasFilter)
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: Colors.grey.shade500,
              ),
              onPressed: onFilterTap,
            ),
        ],
      ),
    );
  }
}
