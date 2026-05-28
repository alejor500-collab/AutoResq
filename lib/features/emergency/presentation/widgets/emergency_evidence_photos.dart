import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/app_colors.dart';

class EmergencyEvidencePhotos extends StatelessWidget {
  final List<String> photoUrls;
  final String title;
  final bool compact;
  final bool featured;

  const EmergencyEvidencePhotos({
    super.key,
    required this.photoUrls,
    this.title = 'Fotos de evidencia',
    this.compact = false,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final urls = photoUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return const SizedBox.shrink();

    final itemSize = compact ? 58.0 : 84.0;
    final borderRadius = BorderRadius.circular(14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 15,
              color: AppColors.primary,
            ),
            const Gap(6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const Gap(8),
        if (featured) ...[
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _openViewer(context, urls, 0),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                height: 156,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        urls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.secondary,
                            size: 30,
                          ),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_full_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              Gap(6),
                              Text(
                                'Ampliar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (urls.length > 1) const Gap(8),
        ],
        if (!featured || urls.length > 1)
          SizedBox(
            height: itemSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured ? urls.length - 1 : urls.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (context, index) {
                final resolvedIndex = featured ? index + 1 : index;
                final url = urls[resolvedIndex];
                return _EvidenceThumbnail(
                  url: url,
                  size: itemSize,
                  borderRadius: borderRadius,
                  onTap: () => _openViewer(context, urls, resolvedIndex),
                );
              },
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, List<String> urls, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (_) => _EvidencePhotoViewer(
        urls: urls,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  final String url;
  final double size;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _EvidenceThumbnail({
    required this.url,
    required this.size,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: AppColors.secondary,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidencePhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _EvidencePhotoViewer({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_EvidencePhotoViewer> createState() => _EvidencePhotoViewerState();
}

class _EvidencePhotoViewerState extends State<_EvidencePhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Foto ${_index + 1} de ${widget.urls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.urls.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        widget.urls[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
