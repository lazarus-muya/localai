import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/content_block.dart';

class ImageBlockView extends StatelessWidget {
  const ImageBlockView({super.key, required this.block});

  final ImageBlock block;

  @override
  Widget build(BuildContext context) {
    final Widget image = switch (block.sourceType) {
      ImageSourceType.network => CachedNetworkImage(
          imageUrl: block.data,
          placeholder: (context, url) => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.broken_image),
        ),
      ImageSourceType.file => Image.file(
          File(block.data),
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        ),
      ImageSourceType.base64 => Image.memory(
          base64Decode(block.data),
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: image,
      ),
    );
  }
}
