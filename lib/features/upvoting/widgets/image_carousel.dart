import 'package:flutter/material.dart';

import '../../../services/app_settings_service.dart';
import '../../../theme/app_theme.dart';

class ImageCarousel extends StatefulWidget {
  const ImageCarousel({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls
        .where((u) => u.trim().isNotEmpty)
        .toList(growable: false);
    final reduceMedia = AppSettingsService.instance.shouldReduceMedia;

    if (urls.isEmpty || reduceMedia) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: AppTheme.surfaceGrey,
            child: Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: AppTheme.textSecondary,
                size: 48,
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return Image.network(
                  urls[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const ColoredBox(
                      color: AppTheme.surfaceGrey,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppTheme.surfaceGrey,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: AppTheme.textSecondary,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  '${_index + 1}/${urls.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
