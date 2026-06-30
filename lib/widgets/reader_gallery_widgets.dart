part of 'package:kevdex/main.dart';

class _GalleryGrid extends StatelessWidget {
  final List<DriveImage> folderImages;
  final String sourceLink;
  final StoryMetadata? metadata;

  const _GalleryGrid({
    required this.folderImages,
    required this.sourceLink,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    if (folderImages.isEmpty) {
      return const _KevDexBackground(
        overlayOpacity: 0.82,
        child: _ReaderMessageState(
          icon: Icons.auto_stories_rounded,
          title: 'No pages found in this folder.',
          message: 'Try another Google Drive folder.',
        ),
      );
    }

    return _KevDexBackground(
      overlayOpacity: 0.82,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Gallery',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _glassSurfaceColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF2F2D39)),
                    ),
                    child: Text(
                      '${folderImages.length} pages',
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: folderImages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  return _GalleryPageCard(
                    image: folderImages[index],
                    pageNumber: index + 1,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReaderPage(
                            link: sourceLink,
                            images: folderImages,
                            initialIndex: index,
                            startInGallery: false,
                            metadata: metadata,
                          ),
                        ),
                      );
                    },
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

class _GalleryPageCard extends StatelessWidget {
  final DriveImage image;
  final int pageNumber;
  final VoidCallback onTap;

  const _GalleryPageCard({
    required this.image,
    required this.pageNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: _glassSurfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2F2D39)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: image.thumbnailUrl,
                        httpHeaders: _readerImageRequestHeaders(
                          image.thumbnailUrl,
                        ),
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const _ThumbnailPlaceholder(),
                        errorWidget: (context, url, error) =>
                            const _ThumbnailPlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC101016),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#$pageNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.article_rounded,
                      color: _primaryAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Page $pageNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateThumbnailFrame extends StatelessWidget {
  final bool isPrivate;
  final Widget child;

  const _PrivateThumbnailFrame({required this.isPrivate, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isPrivate) {
      return child;
    }

    return ValueListenableBuilder<PrivateSourceSettings>(
      valueListenable: privateSourceSettingsNotifier,
      builder: (context, settings, _) {
        if (!settings.blurPrivateThumbnails) {
          return child;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: child,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xAA101016)),
            ),
            const Center(
              child: Icon(
                Icons.visibility_off_rounded,
                color: _primaryAccent,
                size: 24,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _fieldColor,
      child: Center(
        child: Icon(Icons.image_rounded, color: _mutedText, size: 28),
      ),
    );
  }
}

class _MangaLoadingState extends StatelessWidget {
  const _MangaLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded, color: _primaryAccent, size: 42),
          SizedBox(height: 14),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _primaryAccent,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading page...',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ReaderMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 58),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
