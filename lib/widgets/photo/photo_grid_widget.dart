import 'dart:io';
import 'package:flutter/material.dart';

/// Widget para exibir grid de fotos com opção de remover
class PhotoGridWidget extends StatelessWidget {
  final List<File> photos;
  final Function(int index) onRemove;
  final double thumbnailSize;
  final EdgeInsets? padding;

  const PhotoGridWidget({
    Key? key,
    required this.photos,
    required this.onRemove,
    this.thumbnailSize = 80.0,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fotos selecionadas (${photos.length}):',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(photos.length, (index) {
              return _buildThumbnail(context, photos[index], index);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, File photo, int index) {
    return Stack(
      children: [
        Container(
          width: thumbnailSize,
          height: thumbnailSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 32,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: -5,
          right: -5,
          child: GestureDetector(
            onTap: () => onRemove(index),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

