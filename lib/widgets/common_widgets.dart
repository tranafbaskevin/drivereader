part of 'package:kevdex/main.dart';

class _KevDexBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;

  const _KevDexBackground({required this.child, this.overlayOpacity = 0.74});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiBackground>(
      valueListenable: uiBackgroundNotifier,
      child: child,
      builder: (context, background, foreground) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _BackgroundImage(background: background),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _backgroundOverlay(overlayOpacity * 0.72),
                    _backgroundOverlay(overlayOpacity),
                    _backgroundOverlay(overlayOpacity * 0.92),
                  ],
                ),
              ),
            ),
            foreground!,
          ],
        );
      },
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final UiBackground background;

  const _BackgroundImage({required this.background});

  @override
  Widget build(BuildContext context) {
    if (background.isAsset) {
      return Image.asset(
        background.path,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }

    return Image.file(
      File(background.path),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          _defaultBackgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
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
