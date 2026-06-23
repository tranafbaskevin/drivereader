import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const Color _appBackground = Color(0xFF101016);
const Color _surfaceColor = Color(0xFF1A1A22);
const Color _fieldColor = Color(0xFF20202A);
const Color _glassSurfaceColor = Color(0xE61A1A22);
const Color _primaryAccent = Color(0xFF9BE7C9);
const Color _secondaryAccent = Color(0xFFFFB86B);
const Color _mutedText = Color(0xFFB7B6C6);
const String _defaultBackgroundAsset =
    'assets/images/kevdex_anime_library_bg.png';
const String _hallwayBackgroundAsset =
    'assets/images/kevdex_bg_manga_hallway.png';
const String _eyeBackgroundAsset = 'assets/images/kevdex_bg_manga_eye.png';
const String _shadowBackgroundAsset =
    'assets/images/kevdex_bg_manga_shadow.png';

Color _backgroundOverlay(double opacity) {
  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  return _appBackground.withAlpha(alpha);
}

void main() {
  runApp(const DriveReaderApp());
}

class DriveImage {
  final String thumbnailUrl;
  final String fullUrl;

  const DriveImage({required this.thumbnailUrl, required this.fullUrl});
}

class ReadingProgress {
  final String sourceLink;
  final List<DriveImage> images;
  final int pageIndex;

  const ReadingProgress({
    required this.sourceLink,
    required this.images,
    required this.pageIndex,
  });

  int get totalPages => images.isEmpty ? 1 : images.length;

  int get currentPage => pageIndex + 1;

  String get pageLabel => 'Page $currentPage / $totalPages';

  String? get thumbnailUrl {
    if (images.isEmpty) {
      return convertDriveLinkToImageUrl(sourceLink);
    }

    final safeIndex = pageIndex.clamp(0, images.length - 1).toInt();
    return images[safeIndex].thumbnailUrl;
  }
}

class UiBackground {
  final String title;
  final String path;
  final bool isAsset;

  const UiBackground.asset({required this.title, required this.path})
    : isAsset = true;

  const UiBackground.file({required this.title, required this.path})
    : isAsset = false;
}

const UiBackground defaultUiBackground = UiBackground.asset(
  title: 'KevDex Library',
  path: _defaultBackgroundAsset,
);

const List<UiBackground> _presetUiBackgrounds = [
  defaultUiBackground,
  UiBackground.asset(title: 'Hallway', path: _hallwayBackgroundAsset),
  UiBackground.asset(title: 'Midnight Eye', path: _eyeBackgroundAsset),
  UiBackground.asset(title: 'Shadow Reader', path: _shadowBackgroundAsset),
];

final ValueNotifier<ReadingProgress?> readingProgressNotifier =
    ValueNotifier<ReadingProgress?>(null);

final ValueNotifier<UiBackground> uiBackgroundNotifier =
    ValueNotifier<UiBackground>(defaultUiBackground);

class DriveReaderApp extends StatelessWidget {
  const DriveReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KevDex',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _appBackground,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: _primaryAccent,
              brightness: Brightness.dark,
            ).copyWith(
              primary: _primaryAccent,
              secondary: _secondaryAccent,
              surface: _surfaceColor,
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _fieldColor,
          hintStyle: const TextStyle(color: Color(0xFF8E8C99)),
          prefixIconColor: _mutedText,
          suffixIconColor: _mutedText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF393745)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF393745)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primaryAccent, width: 1.4),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController linkController = TextEditingController();
  bool isOpening = false;

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  Future<void> _openReader() async {
    if (isOpening) {
      return;
    }

    final link = linkController.text.trim();

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a story link first.')),
      );
      return;
    }

    final folderId = extractDriveFolderId(link);

    List<DriveImage> images = [];

    setState(() {
      isOpening = true;
    });

    try {
      if (folderId != null) {
        images = await fetchDriveFolderImages(folderId);
      }
    } finally {
      if (mounted) {
        setState(() {
          isOpening = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReaderPage(link: link, images: images, initialIndex: 0),
      ),
    );
  }

  void _continueReading(ReadingProgress progress) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          link: progress.sourceLink,
          images: progress.images,
          initialIndex: progress.pageIndex,
        ),
      ),
    );
  }

  void _showBackgroundPicker() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BackgroundPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _KevDexBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _BackgroundPickerButton(
                        onPressed: _showBackgroundPicker,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _KevDexHeader(),
                    const SizedBox(height: 28),
                    ValueListenableBuilder<ReadingProgress?>(
                      valueListenable: readingProgressNotifier,
                      builder: (context, progress, child) {
                        if (progress == null) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _ContinueReadingCard(
                            progress: progress,
                            onTap: () => _continueReading(progress),
                          ),
                        );
                      },
                    ),
                    TextField(
                      controller: linkController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'https://drive.google.com/...',
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: linkController.clear,
                        ),
                      ),
                      onSubmitted: (_) => _openReader(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: isOpening ? null : _openReader,
                        icon: isOpening
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF121217),
                                ),
                              )
                            : const Icon(Icons.menu_book_rounded),
                        label: Text(
                          isOpening ? 'Gathering pages...' : 'Open Reader',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryAccent,
                          foregroundColor: const Color(0xFF121217),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'By Kevin and Dora-chan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _BackgroundPickerButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackgroundPickerButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Change UI background',
      onPressed: onPressed,
      icon: const Icon(Icons.wallpaper_rounded),
      style: IconButton.styleFrom(
        backgroundColor: _glassSurfaceColor,
        foregroundColor: _primaryAccent,
        side: const BorderSide(color: Color(0xFF2F2D39)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _BackgroundPickerSheet extends StatelessWidget {
  const _BackgroundPickerSheet();

  Future<void> _pickUserImage(BuildContext context) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (image == null || !context.mounted) {
      return;
    }

    uiBackgroundNotifier.value = UiBackground.file(
      title: 'My Image',
      path: image.path,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        decoration: BoxDecoration(
          color: const Color(0xF01A1A22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2F2D39)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.wallpaper_rounded, color: _primaryAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'UI Background',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final background in _presetUiBackgrounds)
                        SizedBox(
                          width: tileWidth,
                          child: _BackgroundPresetTile(background: background),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _pickUserImage(context),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Use My Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryAccent,
                    side: const BorderSide(color: _primaryAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  uiBackgroundNotifier.value = defaultUiBackground;
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset to KevDex Library'),
                style: TextButton.styleFrom(
                  foregroundColor: _mutedText,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundPresetTile extends StatelessWidget {
  final UiBackground background;

  const _BackgroundPresetTile({required this.background});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiBackground>(
      valueListenable: uiBackgroundNotifier,
      builder: (context, selectedBackground, child) {
        final isSelected =
            selectedBackground.isAsset == background.isAsset &&
            selectedBackground.path == background.path;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              uiBackgroundNotifier.value = background;
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? _primaryAccent : const Color(0xFF2F2D39),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: AspectRatio(
                  aspectRatio: 1.12,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(background.path, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 9,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                background.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: _primaryAccent,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        Container(
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
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 48,
            color: _primaryAccent,
          ),
        ),
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
          'Google Drive / Manga Reader',
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

class _ContinueReadingCard extends StatelessWidget {
  final ReadingProgress progress;
  final VoidCallback onTap;

  const _ContinueReadingCard({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = progress.thumbnailUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2F2D39)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 78,
                  child: thumbnailUrl == null
                      ? const ColoredBox(
                          color: _fieldColor,
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: _primaryAccent,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const _ThumbnailPlaceholder(),
                          errorWidget: (context, url, error) =>
                              const _ThumbnailPlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Continue Reading',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress.pageLabel,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: _primaryAccent,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  final String link;
  final List<DriveImage> images;
  final int initialIndex;

  const ReaderPage({
    super.key,
    required this.link,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final PageController pageController;
  late int currentPageIndex;
  bool showControls = true;
  int _hideControlsToken = 0;
  int? _lastSavedPageIndex;
  String? _lastSavedSourceLink;

  @override
  void initState() {
    super.initState();
    currentPageIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleControlsHide();
    });
  }

  @override
  void dispose() {
    _hideControlsToken++;
    pageController.dispose();
    super.dispose();
  }

  List<DriveImage> _resolveReaderImages(bool isFolder, String? singleImageUrl) {
    if (isFolder || widget.images.isNotEmpty) {
      return widget.images;
    }

    if (singleImageUrl == null) {
      return const <DriveImage>[];
    }

    return [DriveImage(thumbnailUrl: singleImageUrl, fullUrl: singleImageUrl)];
  }

  void _scheduleControlsHide() {
    final token = ++_hideControlsToken;

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || token != _hideControlsToken || !showControls) {
        return;
      }

      setState(() {
        showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    if (!showControls) {
      setState(() {
        showControls = true;
      });
    }

    _scheduleControlsHide();
  }

  void _toggleReaderControls() {
    if (showControls) {
      _hideControlsToken++;
      setState(() {
        showControls = false;
      });
      return;
    }

    _showControlsTemporarily();
  }

  void _goToPreviousPage() {
    if (currentPageIndex <= 0) {
      return;
    }

    _showControlsTemporarily();
    pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goToNextPage(int pageCount) {
    if (currentPageIndex >= pageCount - 1) {
      return;
    }

    _showControlsTemporarily();
    pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _saveReadingProgress(List<DriveImage> readerImages, int pageIndex) {
    if (readerImages.isEmpty) {
      return;
    }

    if (_lastSavedSourceLink == widget.link &&
        _lastSavedPageIndex == pageIndex) {
      return;
    }

    _lastSavedSourceLink = widget.link;
    _lastSavedPageIndex = pageIndex;

    readingProgressNotifier.value = ReadingProgress(
      sourceLink: widget.link,
      images: List<DriveImage>.unmodifiable(readerImages),
      pageIndex: pageIndex.clamp(0, readerImages.length - 1).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFolder = isDriveFolderLink(widget.link);
    final singleImageUrl = convertDriveLinkToImageUrl(widget.link);
    final folderImages = widget.images;
    final readerImages = _resolveReaderImages(isFolder, singleImageUrl);
    final pageCount = readerImages.length;
    final progress = pageCount == 0 ? 0.0 : (currentPageIndex + 1) / pageCount;

    if (!isFolder && readerImages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _saveReadingProgress(readerImages, currentPageIndex);
        }
      });
    }

    void preloadImage(String url) {
      precacheImage(NetworkImage(url), context);
    }

    void preloadAround(int index) {
      if (index > 0) {
        preloadImage(readerImages[index - 1].fullUrl);
      }

      if (index < readerImages.length - 1) {
        preloadImage(readerImages[index + 1].fullUrl);
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: isFolder
                ? _GalleryGrid(folderImages: folderImages)
                : readerImages.isEmpty
                ? const _ReaderMessageState(
                    icon: Icons.broken_image_rounded,
                    title: 'This page could not be opened.',
                    message: 'Check the link or try again.',
                  )
                : PageView.builder(
                    controller: pageController,
                    onPageChanged: (pageIndex) {
                      setState(() {
                        currentPageIndex = pageIndex;
                      });
                      _saveReadingProgress(readerImages, pageIndex);

                      if (showControls) {
                        _scheduleControlsHide();
                      }
                    },
                    itemCount: readerImages.length,
                    itemBuilder: (context, pageIndex) {
                      preloadAround(pageIndex);

                      final currentImage = readerImages[pageIndex];
                      return GestureDetector(
                        onTap: _toggleReaderControls,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: CachedNetworkImage(
                            imageUrl: currentImage.fullUrl,
                            fit: BoxFit.fitWidth,
                            placeholder: (context, url) =>
                                const _MangaLoadingState(),
                            errorWidget: (context, url, error) {
                              return const _ReaderMessageState(
                                icon: Icons.broken_image_rounded,
                                title: 'This page could not be opened.',
                                message: 'Check the link or try again.',
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!isFolder && showControls && readerImages.length > 1)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white70,
                      size: 42,
                    ),
                    onPressed: currentPageIndex > 0 ? _goToPreviousPage : null,
                  ),
                ),
              ),
            ),
          if (!isFolder && showControls && readerImages.length > 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 42,
                    ),
                    onPressed: currentPageIndex < pageCount - 1
                        ? () => _goToNextPage(pageCount)
                        : null,
                  ),
                ),
              ),
            ),
          if (!isFolder && showControls && readerImages.isNotEmpty)
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: _ReaderProgressHud(
                currentPage: currentPageIndex + 1,
                totalPages: pageCount,
                progress: progress,
                onBack: () {
                  Navigator.pop(context);
                },
              ),
            ),
          if (isFolder || readerImages.isEmpty)
            Positioned(
              top: 40,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReaderProgressHud extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final double progress;
  final VoidCallback onBack;

  const _ReaderProgressHud({
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xDD101016),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2F2D39)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page $currentPage / $totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    backgroundColor: const Color(0xFF2C2A35),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _primaryAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final List<DriveImage> folderImages;

  const _GalleryGrid({required this.folderImages});

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
                            link: folderImages[index].fullUrl,
                            images: folderImages,
                            initialIndex: index,
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

bool isDriveFolderLink(String link) {
  return link.contains('/drive/folders/');
}

String? extractDriveFolderId(String link) {
  final regExp = RegExp(r'/folders/([^/?]+)');
  final match = regExp.firstMatch(link);

  if (match == null) {
    return null;
  }

  return match.group(1);
}

Future<List<DriveImage>> fetchDriveFolderImages(String folderId) async {
  final response = await http.get(
    Uri.parse(
      'https://www.googleapis.com/drive/v3/files?q=%27$folderId%27+in+parents&fields=files(id,name,mimeType,thumbnailLink)&orderBy=name&key=AIzaSyAHIpqx856jNpz9nrD7BBwakLkTY89cHnc',
    ),
  );

  if (response.statusCode != 200) {
    return [];
  }

  final data = jsonDecode(response.body);
  final files = data['files'] as List;

  return files
      .where((file) => file['mimeType'].toString().startsWith('image/'))
      .map<DriveImage>((file) {
        final thumbnail = file['thumbnailLink'] as String?;
        final id = file['id'];

        final fullUrl = 'https://drive.google.com/uc?export=view&id=$id';

        final thumbnailUrl = thumbnail != null && thumbnail.isNotEmpty
            ? thumbnail.replaceAll(RegExp(r'=s\d+'), '=s400')
            : fullUrl;

        return DriveImage(thumbnailUrl: thumbnailUrl, fullUrl: fullUrl);
      })
      .toList();
}

String? convertDriveLinkToImageUrl(String link) {
  if (link.startsWith('http') && link.contains('uc?export=view&id=')) {
    return link;
  }

  if (link.startsWith('http') && !link.contains('drive.google.com')) {
    return link;
  }

  final regExp = RegExp(r'/d/([^/]+)');
  final match = regExp.firstMatch(link);

  if (match == null) {
    return null;
  }

  final fileId = match.group(1);

  if (fileId == null || fileId.isEmpty) {
    return null;
  }

  return 'https://drive.google.com/uc?export=view&id=$fileId';
}
