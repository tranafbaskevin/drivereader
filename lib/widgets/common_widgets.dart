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

class _KevDexHeader extends StatelessWidget {
  const _KevDexHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _KevDexLogo(),
        const SizedBox(height: 22),
        const Text(
          'KevDex',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Read Anywhere.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _secondaryAccent,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Google Drive / MangaDex / Hentai2Read Reader',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _KevDexLogo extends StatelessWidget {
  const _KevDexLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: _glassSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2F2D39)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, size: 46, color: _primaryAccent),
          Positioned(
            right: 18,
            bottom: 18,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF393745)),
              ),
              child: const Icon(
                Icons.account_tree_rounded,
                size: 15,
                color: _secondaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
