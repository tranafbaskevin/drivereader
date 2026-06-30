import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'models/story_models.dart';
part 'utils/app_constants.dart';
part 'utils/link_helpers.dart';
part 'services/kevdex_memory.dart';
part 'widgets/reader_gallery_widgets.dart';
part 'widgets/source_hub_widgets.dart';
part 'widgets/manga_detail_widgets.dart';
part 'widgets/reader_controls.dart';
part 'widgets/common_widgets.dart';
part 'widgets/background_picker_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KevDexMemory.load();
  runApp(const DriveReaderApp());
}

class ReadingProgress {
  final String sourceLink;
  final List<DriveImage> images;
  final int pageIndex;
  final StoryMetadata? metadata;

  const ReadingProgress({
    required this.sourceLink,
    required this.images,
    required this.pageIndex,
    this.metadata,
  });

  int get totalPages => images.isEmpty ? 1 : images.length;

  int get currentPage => pageIndex + 1;

  String get pageLabel => 'Page $currentPage / $totalPages';

  bool get isPrivateSource {
    final sourceType = metadata?.sourceType;
    return sourceType != null && isPrivateSourceType(sourceType);
  }

  String? get thumbnailUrl {
    if (images.isEmpty) {
      return convertDriveLinkToImageUrl(sourceLink);
    }

    final safeIndex = pageIndex.clamp(0, images.length - 1).toInt();
    return images[safeIndex].thumbnailUrl;
  }

  Map<String, Object?> toJson() {
    return {
      'sourceLink': sourceLink,
      'pageIndex': pageIndex,
      'images': images.map((image) => image.toJson()).toList(),
      'metadata': metadata?.toJson(),
    };
  }

  static ReadingProgress? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final sourceLink = value['sourceLink'];
    final pageIndex = value['pageIndex'];
    final imagesValue = value['images'];
    final metadata = StoryMetadata.fromJson(value['metadata']);

    if (sourceLink is! String || pageIndex is! int || imagesValue is! List) {
      return null;
    }

    final images = imagesValue
        .map(DriveImage.fromJson)
        .whereType<DriveImage>()
        .toList(growable: false);

    return ReadingProgress(
      sourceLink: sourceLink,
      images: List<DriveImage>.unmodifiable(images),
      pageIndex: images.isEmpty
          ? 0
          : pageIndex.clamp(0, images.length - 1).toInt(),
      metadata: metadata,
    );
  }
}

class LibraryItem {
  final String sourceLink;
  final List<DriveImage> images;
  final int pageIndex;
  final int updatedAtMs;
  final StoryMetadata? metadata;

  const LibraryItem({
    required this.sourceLink,
    required this.images,
    required this.pageIndex,
    required this.updatedAtMs,
    this.metadata,
  });

  factory LibraryItem.fromProgress(ReadingProgress progress) {
    return LibraryItem(
      sourceLink: progress.sourceLink,
      images: List<DriveImage>.unmodifiable(progress.images),
      pageIndex: progress.images.isEmpty
          ? 0
          : progress.pageIndex.clamp(0, progress.images.length - 1).toInt(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      metadata: progress.metadata,
    );
  }

  int get totalPages => images.isEmpty ? 1 : images.length;

  int get currentPage => pageIndex + 1;

  bool get isPrivateSource {
    final sourceType = metadata?.sourceType;
    return sourceType != null && isPrivateSourceType(sourceType);
  }

  String get title {
    final metadataTitle = metadata?.title.trim();
    if (metadataTitle != null && metadataTitle.isNotEmpty) {
      return metadataTitle;
    }

    if (isMangaDexChapterLink(sourceLink)) {
      return 'MangaDex Chapter';
    }

    if (isDriveFolderLink(sourceLink) || images.length > 1) {
      return 'Drive Folder';
    }

    return 'Single Page';
  }

  String get subtitle {
    final chapterLabel = metadata?.chapterLabel?.trim();
    if (chapterLabel != null && chapterLabel.isNotEmpty) {
      return '$chapterLabel - Page $currentPage / $totalPages';
    }

    return 'Page $currentPage / $totalPages';
  }

  String? get thumbnailUrl {
    if (images.isEmpty) {
      return convertDriveLinkToImageUrl(sourceLink);
    }

    final safeIndex = pageIndex.clamp(0, images.length - 1).toInt();
    return images[safeIndex].thumbnailUrl;
  }

  ReadingProgress toProgress() {
    return ReadingProgress(
      sourceLink: sourceLink,
      images: List<DriveImage>.unmodifiable(images),
      pageIndex: images.isEmpty
          ? 0
          : pageIndex.clamp(0, images.length - 1).toInt(),
      metadata: metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sourceLink': sourceLink,
      'pageIndex': pageIndex,
      'updatedAtMs': updatedAtMs,
      'images': images.map((image) => image.toJson()).toList(),
      'metadata': metadata?.toJson(),
    };
  }

  static LibraryItem? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final sourceLink = value['sourceLink'];
    final pageIndex = value['pageIndex'];
    final updatedAtMs = value['updatedAtMs'];
    final imagesValue = value['images'];
    final metadata = StoryMetadata.fromJson(value['metadata']);

    if (sourceLink is! String ||
        pageIndex is! int ||
        updatedAtMs is! int ||
        imagesValue is! List) {
      return null;
    }

    final images = imagesValue
        .map(DriveImage.fromJson)
        .whereType<DriveImage>()
        .toList(growable: false);

    return LibraryItem(
      sourceLink: sourceLink,
      images: List<DriveImage>.unmodifiable(images),
      pageIndex: images.isEmpty
          ? 0
          : pageIndex.clamp(0, images.length - 1).toInt(),
      updatedAtMs: updatedAtMs,
      metadata: metadata,
    );
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

  Map<String, Object?> toJson() {
    return {'title': title, 'path': path, 'isAsset': isAsset};
  }

  static UiBackground? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final title = value['title'];
    final path = value['path'];
    final isAsset = value['isAsset'];

    if (title is! String || path is! String || isAsset is! bool) {
      return null;
    }

    if (isAsset) {
      final preset = _presetUiBackgrounds.where((item) => item.path == path);
      if (preset.isNotEmpty) {
        return preset.first;
      }

      return null;
    }

    return UiBackground.file(title: title, path: path);
  }
}

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
  final TextEditingController driveLinkController = TextEditingController();
  final TextEditingController mangaDexLinkController = TextEditingController();
  final TextEditingController nHentaiLinkController = TextEditingController();
  final TextEditingController hitomiLinkController = TextEditingController();
  final TextEditingController hentai2ReadLinkController =
      TextEditingController();
  StorySourceType selectedSourceType = StorySourceType.driveFolder;
  bool isOpening = false;

  @override
  void initState() {
    super.initState();
    final savedDriveLink = KevDexMemory.lastDriveLink;
    final savedMangaDexLink = KevDexMemory.lastMangaDexLink;
    final savedNHentaiLink = KevDexMemory.lastNHentaiLink;
    final savedHitomiLink = KevDexMemory.lastHitomiLink;
    final savedHentai2ReadLink = KevDexMemory.lastHentai2ReadLink;
    final fallbackLink = KevDexMemory.lastLink;

    if (savedDriveLink != null && savedDriveLink.isNotEmpty) {
      driveLinkController.text = savedDriveLink;
    } else if (fallbackLink != null &&
        fallbackLink.isNotEmpty &&
        !isMangaDexChapterLink(fallbackLink)) {
      driveLinkController.text = fallbackLink;
    }

    if (savedMangaDexLink != null && savedMangaDexLink.isNotEmpty) {
      mangaDexLinkController.text = savedMangaDexLink;
      selectedSourceType = StorySourceType.mangaDexChapter;
    } else if (fallbackLink != null &&
        fallbackLink.isNotEmpty &&
        isMangaDexChapterLink(fallbackLink)) {
      mangaDexLinkController.text = fallbackLink;
      selectedSourceType = StorySourceType.mangaDexChapter;
    }

    if (savedNHentaiLink != null && savedNHentaiLink.isNotEmpty) {
      nHentaiLinkController.text = savedNHentaiLink;
    }

    if (savedHitomiLink != null && savedHitomiLink.isNotEmpty) {
      hitomiLinkController.text = savedHitomiLink;
    }

    if (savedHentai2ReadLink != null && savedHentai2ReadLink.isNotEmpty) {
      hentai2ReadLinkController.text = savedHentai2ReadLink;
    }
  }

  @override
  void dispose() {
    driveLinkController.dispose();
    mangaDexLinkController.dispose();
    nHentaiLinkController.dispose();
    hitomiLinkController.dispose();
    hentai2ReadLinkController.dispose();
    super.dispose();
  }

  TextEditingController _controllerForSource(StorySourceType sourceType) {
    return switch (sourceType) {
      StorySourceType.mangaDexChapter => mangaDexLinkController,
      StorySourceType.hentai2ReadChapter => hentai2ReadLinkController,
      StorySourceType.nHentaiGallery => nHentaiLinkController,
      StorySourceType.hitomiGallery => hitomiLinkController,
      StorySourceType.driveFolder ||
      StorySourceType.singlePage => driveLinkController,
    };
  }

  void _selectSource(StorySourceType sourceType) {
    final definition = sourceDefinitionFor(sourceType);

    if (definition.privateSource &&
        !privateSourceSettingsNotifier.value.isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable Private Sources first.')),
      );
      return;
    }

    if (!definition.isReady && !definition.privateSource) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${definition.label} adapter is planned.')),
      );
      return;
    }

    setState(() {
      selectedSourceType = sourceType;
    });
  }

  void _showSourceHub() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SourceHubSheet(
        selectedSourceType: selectedSourceType,
        onSelectSource: (sourceType) {
          Navigator.pop(context);
          _selectSource(sourceType);
        },
        onClearCache: _clearCache,
      ),
    );
  }

  Future<void> _clearCache() async {
    await KevDexMemory.clearAppCache();

    driveLinkController.clear();
    mangaDexLinkController.clear();
    nHentaiLinkController.clear();
    hitomiLinkController.clear();
    hentai2ReadLinkController.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      selectedSourceType = StorySourceType.driveFolder;
    });
  }

  Future<void> _openReader(StorySourceType requestedSourceType) async {
    if (isOpening) {
      return;
    }

    final definition = sourceDefinitionFor(requestedSourceType);

    if (definition.privateSource &&
        !privateSourceSettingsNotifier.value.isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable Private Sources first.')),
      );
      return;
    }

    final link = _controllerForSource(requestedSourceType).text.trim();

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paste a ${definition.label} link first.')),
      );
      return;
    }

    if (!definition.isReady) {
      if (!_matchesRequestedPrivateSource(requestedSourceType, link)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paste a valid ${definition.label} link.')),
        );
        return;
      }

      await KevDexMemory.saveLastLink(link);
      if (requestedSourceType == StorySourceType.nHentaiGallery) {
        await KevDexMemory.saveLastNHentaiLink(link);
      } else if (requestedSourceType == StorySourceType.hitomiGallery) {
        await KevDexMemory.saveLastHitomiLink(link);
      }

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${definition.label} link saved. Reader adapter is next.',
          ),
        ),
      );
      return;
    }

    final sourceType = detectStorySource(link);
    final folderId = extractDriveFolderId(link);
    final mangaDexChapterId = extractMangaDexChapterId(link);
    final nHentaiGalleryId = extractNHentaiGalleryId(link);
    final hitomiGalleryId = extractHitomiGalleryId(link);
    final hentai2ReadTarget = extractHentai2ReadTarget(link);

    if (requestedSourceType == StorySourceType.mangaDexChapter &&
        mangaDexChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a MangaDex chapter link.')),
      );
      return;
    }

    if (requestedSourceType == StorySourceType.hentai2ReadChapter &&
        hentai2ReadTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a valid Hentai2Read story or chapter link.'),
        ),
      );
      return;
    }

    if (requestedSourceType == StorySourceType.nHentaiGallery &&
        nHentaiGalleryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a valid NHentai gallery link.')),
      );
      return;
    }

    if (requestedSourceType == StorySourceType.hitomiGallery &&
        hitomiGalleryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a valid Hitomi gallery link.')),
      );
      return;
    }

    if (requestedSourceType != StorySourceType.mangaDexChapter &&
        mangaDexChapterId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the MangaDex box for this link.')),
      );
      return;
    }

    if (isPrivateSourceType(sourceType) && requestedSourceType != sourceType) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Use the ${sourceDefinitionFor(sourceType).label} box.',
          ),
        ),
      );
      return;
    }

    StoryMetadata? metadata;
    String? loadErrorMessage;

    List<DriveImage> images = [];
    await KevDexMemory.saveLastLink(link);
    switch (requestedSourceType) {
      case StorySourceType.mangaDexChapter:
        await KevDexMemory.saveLastMangaDexLink(link);
        break;
      case StorySourceType.hentai2ReadChapter:
        await KevDexMemory.saveLastHentai2ReadLink(link);
        break;
      case StorySourceType.nHentaiGallery:
        await KevDexMemory.saveLastNHentaiLink(link);
        break;
      case StorySourceType.hitomiGallery:
        await KevDexMemory.saveLastHitomiLink(link);
        break;
      case StorySourceType.driveFolder:
      case StorySourceType.singlePage:
        await KevDexMemory.saveLastDriveLink(link);
        break;
    }

    setState(() {
      isOpening = true;
    });

    try {
      if (requestedSourceType == StorySourceType.mangaDexChapter &&
          mangaDexChapterId != null) {
        images = await fetchMangaDexChapterImages(mangaDexChapterId);
        metadata = await fetchMangaDexChapterMetadata(mangaDexChapterId);
      } else if (requestedSourceType == StorySourceType.hentai2ReadChapter) {
        final result = await fetchHentai2ReadStory(link);
        images = result.images;
        metadata = result.metadata;
        loadErrorMessage = result.errorMessage;
      } else if (requestedSourceType == StorySourceType.nHentaiGallery) {
        final result = await fetchNHentaiGallery(link);
        images = result.images;
        metadata = result.metadata;
        loadErrorMessage = result.errorMessage;
      } else if (requestedSourceType == StorySourceType.hitomiGallery) {
        final result = await fetchHitomiGallery(link);
        images = result.images;
        metadata = result.metadata;
        loadErrorMessage = result.errorMessage;
      } else if (folderId != null) {
        images = await fetchDriveFolderImages(folderId);
        final folderName = await fetchDriveFolderName(folderId);
        metadata = StoryMetadata(
          sourceType: StorySourceType.driveFolder,
          title: folderName ?? 'Drive Folder',
        );
      } else {
        metadata = const StoryMetadata(
          sourceType: StorySourceType.singlePage,
          title: 'Google Drive Image',
        );
      }
    } catch (_) {
      loadErrorMessage =
          '${definition.label} could not be reached. Check the link, network, or VPN.';
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

    if (_sourceNeedsFetchedPages(requestedSourceType) && images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loadErrorMessage ??
                '${definition.label} did not return readable pages.',
          ),
        ),
      );
      return;
    }

    if (images.isNotEmpty) {
      final progress = ReadingProgress(
        sourceLink: link,
        images: List<DriveImage>.unmodifiable(images),
        pageIndex: 0,
        metadata: metadata,
      );
      readingProgressNotifier.value = progress;
      unawaited(KevDexMemory.saveReadingProgress(progress));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          link: link,
          images: images,
          initialIndex: 0,
          startInGallery: sourceType == StorySourceType.driveFolder,
          metadata: metadata,
        ),
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
          startInGallery: false,
          metadata: progress.metadata,
        ),
      ),
    );
  }

  void _openLibraryItem(LibraryItem item) {
    openLibraryItem(context, item);
  }

  void _openLibraryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LibraryPage()),
    );
  }

  void _openMangaDexHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MangaDexHomePage()),
    );
  }

  void _openHentai2ReadHome() {
    if (!privateSourceSettingsNotifier.value.isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable Private Sources first.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Hentai2ReadHomePage()),
    );
  }

  void _openHitomiHome() {
    if (!privateSourceSettingsNotifier.value.isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable Private Sources first.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HitomiHomePage()),
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
                    const SizedBox(height: 22),
                    _SourceHubPanel(
                      selectedSourceType: selectedSourceType,
                      driveController: driveLinkController,
                      mangaDexController: mangaDexLinkController,
                      nHentaiController: nHentaiLinkController,
                      hitomiController: hitomiLinkController,
                      hentai2ReadController: hentai2ReadLinkController,
                      isOpening: isOpening,
                      onSelectSource: _selectSource,
                      onShowSourceHub: _showSourceHub,
                      onOpenMangaDexHome: _openMangaDexHome,
                      onOpenHitomiHome: _openHitomiHome,
                      onOpenHentai2ReadHome: _openHentai2ReadHome,
                      onOpen: () => _openReader(selectedSourceType),
                      onClear: () {
                        final controller = _controllerForSource(
                          selectedSourceType,
                        );
                        controller.clear();

                        switch (selectedSourceType) {
                          case StorySourceType.mangaDexChapter:
                            unawaited(KevDexMemory.saveLastMangaDexLink(''));
                            break;
                          case StorySourceType.hentai2ReadChapter:
                            unawaited(KevDexMemory.saveLastHentai2ReadLink(''));
                            break;
                          case StorySourceType.nHentaiGallery:
                            unawaited(KevDexMemory.saveLastNHentaiLink(''));
                            break;
                          case StorySourceType.hitomiGallery:
                            unawaited(KevDexMemory.saveLastHitomiLink(''));
                            break;
                          case StorySourceType.driveFolder:
                          case StorySourceType.singlePage:
                            unawaited(KevDexMemory.saveLastDriveLink(''));
                            break;
                        }
                      },
                    ),
                    const SizedBox(height: 22),
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
                    ValueListenableBuilder<List<LibraryItem>>(
                      valueListenable: libraryNotifier,
                      builder: (context, items, child) {
                        if (items.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _LibraryShelf(
                            items: items,
                            onOpen: _openLibraryItem,
                            onOpenAll: _openLibraryPage,
                          ),
                        );
                      },
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

class _SourceHubPanel extends StatelessWidget {
  final StorySourceType selectedSourceType;
  final TextEditingController driveController;
  final TextEditingController mangaDexController;
  final TextEditingController nHentaiController;
  final TextEditingController hitomiController;
  final TextEditingController hentai2ReadController;
  final bool isOpening;
  final ValueChanged<StorySourceType> onSelectSource;
  final VoidCallback onShowSourceHub;
  final VoidCallback onOpenMangaDexHome;
  final VoidCallback onOpenHitomiHome;
  final VoidCallback onOpenHentai2ReadHome;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  const _SourceHubPanel({
    required this.selectedSourceType,
    required this.driveController,
    required this.mangaDexController,
    required this.nHentaiController,
    required this.hitomiController,
    required this.hentai2ReadController,
    required this.isOpening,
    required this.onSelectSource,
    required this.onShowSourceHub,
    required this.onOpenMangaDexHome,
    required this.onOpenHitomiHome,
    required this.onOpenHentai2ReadHome,
    required this.onOpen,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDefinition = sourceDefinitionFor(selectedSourceType);
    final selectedController = _controllerForSource(selectedSourceType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _glassSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2F2D39)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, color: _primaryAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Source Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Manage sources',
                icon: const Icon(Icons.tune_rounded),
                color: _primaryAccent,
                onPressed: onShowSourceHub,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final definition in publicReadyStorySources)
                _SourceFilterChip(
                  definition: definition,
                  selected: selectedSourceType == definition.type,
                  isOpening: isOpening,
                  onSelectSource: onSelectSource,
                ),
              ValueListenableBuilder<PrivateSourceSettings>(
                valueListenable: privateSourceSettingsNotifier,
                builder: (context, settings, child) {
                  if (!settings.isAccepted) {
                    return const SizedBox.shrink();
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final definition in privateStorySources)
                        _SourceFilterChip(
                          definition: definition,
                          selected: selectedSourceType == definition.type,
                          isOpening: isOpening,
                          onSelectSource: onSelectSource,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          if (selectedDefinition.privateSource) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF241D24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4B3E4A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.construction_rounded,
                    color: _secondaryAccent,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedDefinition.label} opens through Private Sources.',
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
          ],
          const SizedBox(height: 14),
          if (selectedSourceType == StorySourceType.mangaDexChapter) ...[
            Tooltip(
              message: 'Open MangaDex Home',
              child: OutlinedButton.icon(
                onPressed: isOpening ? null : onOpenMangaDexHome,
                icon: const Icon(Icons.explore_rounded),
                label: const Text('MangaDex Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryAccent,
                  side: const BorderSide(color: Color(0xFF3C6F60)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (selectedSourceType == StorySourceType.hentai2ReadChapter) ...[
            Tooltip(
              message: 'Open Hentai2Read Home',
              child: OutlinedButton.icon(
                onPressed: isOpening ? null : onOpenHentai2ReadHome,
                icon: const Icon(Icons.auto_stories_rounded),
                label: const Text('Hentai2Read Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryAccent,
                  side: const BorderSide(color: Color(0xFF3C6F60)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (selectedSourceType == StorySourceType.hitomiGallery) ...[
            Tooltip(
              message: 'Open Hitomi Home',
              child: OutlinedButton.icon(
                onPressed: isOpening ? null : onOpenHitomiHome,
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Hitomi Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryAccent,
                  side: const BorderSide(color: Color(0xFF3C6F60)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _SourceLinkField(
            label: selectedDefinition.label,
            hintText: selectedDefinition.hintText,
            icon: selectedDefinition.icon,
            controller: selectedController,
            isOpening: isOpening,
            openTooltip: 'Open ${selectedDefinition.label}',
            onOpen: onOpen,
            onClear: onClear,
          ),
        ],
      ),
    );
  }

  TextEditingController _controllerForSource(StorySourceType sourceType) {
    return switch (sourceType) {
      StorySourceType.mangaDexChapter => mangaDexController,
      StorySourceType.hentai2ReadChapter => hentai2ReadController,
      StorySourceType.nHentaiGallery => nHentaiController,
      StorySourceType.hitomiGallery => hitomiController,
      StorySourceType.driveFolder ||
      StorySourceType.singlePage => driveController,
    };
  }
}

class _SourceHubSheet extends StatelessWidget {
  final StorySourceType selectedSourceType;
  final ValueChanged<StorySourceType> onSelectSource;
  final Future<void> Function() onClearCache;

  const _SourceHubSheet({
    required this.selectedSourceType,
    required this.onSelectSource,
    required this.onClearCache,
  });

  Future<void> _confirmClearCache(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          title: const Text('Clear cache?'),
          content: const Text(
            'This removes pasted links, Continue Reading, Library, custom UI background, reader comfort, and cached pages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A7A),
                foregroundColor: const Color(0xFF101016),
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !context.mounted) {
      return;
    }

    await onClearCache();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('KevDex cache cleared.')));
    Navigator.pop(context);
  }

  Future<void> _confirmEnablePrivateSources(BuildContext context) async {
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          title: const Text('Enable Private Sources?'),
          content: const Text(
            'Private adapters are hidden by default. Turn this on only if you want KevDex to show adult-source options in Source Hub.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryAccent,
                foregroundColor: const Color(0xFF101016),
              ),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (shouldEnable != true) {
      return;
    }

    await KevDexMemory.savePrivateSourceSettings(
      PrivateSourceSettings(
        enabled: true,
        acceptedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Private sources enabled.')));
  }

  Future<void> _disablePrivateSources(BuildContext context) async {
    await KevDexMemory.savePrivateSourceSettings(defaultPrivateSourceSettings);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Private sources hidden.')));
  }

  Future<void> _confirmClearPrivateHistory(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          title: const Text('Clear private history?'),
          content: const Text(
            'This removes private Library items and private Continue Reading without touching normal reading history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB86B),
                foregroundColor: const Color(0xFF101016),
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    await KevDexMemory.clearPrivateHistory();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Private history cleared.')));
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
                  const Icon(Icons.account_tree_rounded, color: _primaryAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Source Hub',
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
              const _SourceHubSectionTitle(label: 'Ready'),
              const SizedBox(height: 8),
              for (final definition in publicReadyStorySources) ...[
                _SourceHubTile(
                  definition: definition,
                  selected: selectedSourceType == definition.type,
                  onTap: () => onSelectSource(definition.type),
                ),
                if (definition != publicReadyStorySources.last)
                  const SizedBox(height: 10),
              ],
              if (privateStorySources.isNotEmpty)
                ValueListenableBuilder<PrivateSourceSettings>(
                  valueListenable: privateSourceSettingsNotifier,
                  builder: (context, settings, child) {
                    final visiblePrivateSources = settings.isAccepted
                        ? privateStorySources
                        : const <StorySourceDefinition>[];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        _PrivateSourceGateCard(
                          settings: settings,
                          onChanged: (enabled) {
                            if (enabled) {
                              unawaited(_confirmEnablePrivateSources(context));
                            } else {
                              unawaited(_disablePrivateSources(context));
                            }
                          },
                          onClearPrivateHistory: () {
                            unawaited(_confirmClearPrivateHistory(context));
                          },
                          onBlurChanged: (enabled) {
                            unawaited(
                              KevDexMemory.savePrivateSourceSettings(
                                settings.copyWith(
                                  blurPrivateThumbnails: enabled,
                                ),
                              ),
                            );
                          },
                        ),
                        if (visiblePrivateSources.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const _SourceHubSectionTitle(label: 'Private Ready'),
                          const SizedBox(height: 8),
                          for (final definition in visiblePrivateSources) ...[
                            _SourceHubTile(
                              definition: definition,
                              selected: selectedSourceType == definition.type,
                              enabled: true,
                              onTap: () => onSelectSource(definition.type),
                            ),
                            if (definition != visiblePrivateSources.last)
                              const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 18),
              Tooltip(
                message: 'Clear app cache',
                child: OutlinedButton.icon(
                  onPressed: () => _confirmClearCache(context),
                  icon: const Icon(Icons.cleaning_services_rounded),
                  label: const Text('Clear Cache'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB0B0),
                    side: const BorderSide(color: Color(0xFF7A3E46)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  child: _PrivateThumbnailFrame(
                    isPrivate: progress.isPrivateSource,
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
                            httpHeaders: _readerImageRequestHeaders(
                              thumbnailUrl,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const _ThumbnailPlaceholder(),
                            errorWidget: (context, url, error) =>
                                const _ThumbnailPlaceholder(),
                          ),
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

void openLibraryItem(BuildContext context, LibraryItem item) {
  final progress = item.toProgress();
  readingProgressNotifier.value = progress;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ReaderPage(
        link: item.sourceLink,
        images: item.images,
        initialIndex: item.pageIndex,
        startInGallery: false,
        metadata: item.metadata,
      ),
    ),
  );
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<List<LibraryItem>>(
        valueListenable: libraryNotifier,
        builder: (context, items, child) {
          return _KevDexBackground(
            overlayOpacity: 0.82,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: Colors.white,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Library',
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
                            '${items.length} saved',
                            style: const TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const _ReaderMessageState(
                            icon: Icons.local_library_rounded,
                            title: 'Library is empty.',
                            message: 'Opened stories will appear here.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = items[index];

                              return _LibraryItemCard(
                                item: item,
                                onOpen: () => openLibraryItem(context, item),
                                onRemove: () => unawaited(
                                  KevDexMemory.removeLibraryItem(
                                    item.sourceLink,
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
        },
      ),
    );
  }
}

class _LibraryShelf extends StatelessWidget {
  final List<LibraryItem> items;
  final ValueChanged<LibraryItem> onOpen;
  final VoidCallback onOpenAll;

  const _LibraryShelf({
    required this.items,
    required this.onOpen,
    required this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    final previewItems = items.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: 'Open full Library',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_library_rounded,
                      color: _primaryAccent,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} saved',
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _mutedText,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final item in previewItems) ...[
          _LibraryItemCard(
            item: item,
            onOpen: () => onOpen(item),
            onRemove: () =>
                unawaited(KevDexMemory.removeLibraryItem(item.sourceLink)),
          ),
          if (item != previewItems.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _LibraryItemCard({
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = item.thumbnailUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _glassSurfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2F2D39)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 54,
                  height: 64,
                  child: _PrivateThumbnailFrame(
                    isPrivate: item.isPrivateSource,
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
                            httpHeaders: _readerImageRequestHeaders(
                              thumbnailUrl,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const _ThumbnailPlaceholder(),
                            errorWidget: (context, url, error) =>
                                const _ThumbnailPlaceholder(),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.metadata?.sourceLabel ?? item.sourceLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E8C99),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove from Library',
                icon: const Icon(Icons.close_rounded, size: 19),
                color: _mutedText,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MangaDexHomePage extends StatefulWidget {
  final Future<List<MangaDexMangaPreview>> Function({
    int limit,
    int offset,
    String? query,
  })?
  mangaLoader;

  const MangaDexHomePage({super.key, this.mangaLoader});

  @override
  State<MangaDexHomePage> createState() => _MangaDexHomePageState();
}

class _MangaDexHomePageState extends State<MangaDexHomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<MangaDexMangaPreview> _mangas = [];
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialMangas();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchTextChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMangas() async {
    final query = _searchQuery.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _mangas.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final loader = widget.mangaLoader;
      final List<MangaDexMangaPreview> list;
      if (loader != null) {
        list = await loader(
          limit: _limit,
          offset: _offset,
          query: query.isEmpty ? null : query,
        );
      } else {
        list = await fetchMangaDexHomeMangas(
          limit: _limit,
          offset: _offset,
          query: query,
        );
      }

      if (!mounted || query != _searchQuery.trim()) {
        return;
      }

      setState(() {
        _mangas.addAll(list);
        _isLoading = false;
        if (list.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (!mounted || query != _searchQuery.trim()) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = query.isEmpty
            ? 'Could not load MangaDex Home.'
            : 'Could not search MangaDex.';
      });
    }
  }

  Future<void> _loadMoreMangas() async {
    if (_isLoadingMore || !_hasMore) return;

    final query = _searchQuery.trim();

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextOffset = _offset + _limit;
      final loader = widget.mangaLoader;
      final List<MangaDexMangaPreview> list;
      if (loader != null) {
        list = await loader(
          limit: _limit,
          offset: nextOffset,
          query: query.isEmpty ? null : query,
        );
      } else {
        list = await fetchMangaDexHomeMangas(
          limit: _limit,
          offset: nextOffset,
          query: query,
        );
      }

      if (!mounted || query != _searchQuery.trim()) {
        return;
      }

      setState(() {
        _offset = nextOffset;
        _mangas.addAll(list);
        _isLoadingMore = false;
        if (list.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (_) {
      if (!mounted || query != _searchQuery.trim()) {
        return;
      }

      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String get _normalizedSearchQuery => _searchController.text.trim();

  void _onSearchTextChanged() {
    if (mounted) {
      setState(() {});
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }

      final nextQuery = _normalizedSearchQuery;
      if (nextQuery == _searchQuery) {
        return;
      }

      _searchQuery = nextQuery;
      _loadInitialMangas();
    });
  }

  void _refreshMangas() {
    _searchDebounce?.cancel();
    _searchQuery = _normalizedSearchQuery;
    _loadInitialMangas();
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && _searchQuery.isEmpty) {
      return;
    }

    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
    _loadInitialMangas();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.9) {
      _loadMoreMangas();
    }
  }

  void _openManga(MangaDexMangaPreview manga) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDexMangaDetailPage(manga: manga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _KevDexBackground(
        overlayOpacity: 0.86,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'MangaDex Home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Latest Updated Manga',
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh MangaDex Home',
                      icon: const Icon(Icons.refresh_rounded),
                      color: _primaryAccent,
                      onPressed: _refreshMangas,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _refreshMangas(),
                  decoration: InputDecoration(
                    hintText: 'Search manga title...',
                    hintStyle: const TextStyle(
                      color: _mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _primaryAccent,
                    ),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear Search',
                            icon: const Icon(Icons.close_rounded),
                            color: _mutedText,
                            onPressed: _clearSearch,
                          ),
                    filled: true,
                    fillColor: _glassSurfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2F2D39)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2F2D39)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _primaryAccent),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const _MangaLoadingState();
                    }

                    if (_errorMessage != null && _mangas.isEmpty) {
                      return _ReaderMessageState(
                        icon: Icons.explore_rounded,
                        title: _errorMessage!,
                        message: _searchQuery.isEmpty
                            ? 'Refresh or check the network.'
                            : 'Try another title or refresh.',
                      );
                    }

                    if (_mangas.isEmpty) {
                      return _ReaderMessageState(
                        icon: _searchQuery.isEmpty
                            ? Icons.explore_rounded
                            : Icons.search_off_rounded,
                        title: _searchQuery.isEmpty
                            ? 'No MangaDex stories found.'
                            : 'No MangaDex results found.',
                        message: _searchQuery.isEmpty
                            ? 'Refresh or check the network.'
                            : 'Try another manga title.',
                      );
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _mangas.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index >= _mangas.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _primaryAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final manga = _mangas[index];
                        return _MangaDexMangaCard(
                          manga: manga,
                          onOpen: () => _openManga(manga),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MangaDexMangaCard extends StatelessWidget {
  final MangaDexMangaPreview manga;
  final VoidCallback onOpen;

  const _MangaDexMangaCard({required this.manga, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = manga.thumbnailUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _glassSurfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2F2D39)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 86,
                  child: thumbnailUrl == null
                      ? const ColoredBox(
                          color: _fieldColor,
                          child: Icon(
                            Icons.menu_book_rounded,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      manga.description ?? 'No description available.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'MangaDex',
                      style: TextStyle(
                        color: _primaryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _primaryAccent,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MangaDexMangaDetailPage extends StatefulWidget {
  final MangaDexMangaPreview manga;

  const MangaDexMangaDetailPage({super.key, required this.manga});

  @override
  State<MangaDexMangaDetailPage> createState() =>
      _MangaDexMangaDetailPageState();
}

class _MangaDexMangaDetailPageState extends State<MangaDexMangaDetailPage> {
  late Future<List<MangaDexChapterPreview>> chaptersFuture;
  String? openingChapterId;
  bool isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    chaptersFuture = _loadChapters();
  }

  Future<List<MangaDexChapterPreview>> _loadChapters() {
    return fetchMangaDexMangaChapters(widget.manga.mangaId).then((chapters) {
      return chapters
          .map((c) => c.copyWith(thumbnailUrl: widget.manga.thumbnailUrl))
          .toList();
    });
  }

  void _refresh() {
    setState(() {
      chaptersFuture = _loadChapters();
    });
  }

  Future<void> _openChapter(MangaDexChapterPreview chapter) async {
    if (openingChapterId != null) {
      return;
    }

    setState(() {
      openingChapterId = chapter.chapterId;
    });

    List<DriveImage> images = const <DriveImage>[];
    StoryMetadata metadata = chapter.metadata.copyWith(
      title: widget.manga.title,
    );
    String? errorMessage;

    try {
      images = await fetchMangaDexChapterImages(chapter.chapterId);
      metadata = await fetchMangaDexChapterMetadata(chapter.chapterId);
      metadata = metadata.copyWith(title: widget.manga.title);
    } catch (_) {
      errorMessage = 'MangaDex chapter could not be reached.';
    } finally {
      if (mounted) {
        setState(() {
          openingChapterId = null;
        });
      }
    }

    if (!mounted) {
      return;
    }

    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'MangaDex did not return readable pages.',
          ),
        ),
      );
      return;
    }

    await KevDexMemory.saveLastLink(chapter.sourceLink);
    await KevDexMemory.saveLastMangaDexLink(chapter.sourceLink);

    final progress = ReadingProgress(
      sourceLink: chapter.sourceLink,
      images: List<DriveImage>.unmodifiable(images),
      pageIndex: 0,
      metadata: metadata,
    );

    readingProgressNotifier.value = progress;
    unawaited(KevDexMemory.saveReadingProgress(progress));

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          link: chapter.sourceLink,
          images: images,
          initialIndex: 0,
          startInGallery: false,
          metadata: metadata,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manga = widget.manga;

    return Scaffold(
      body: _KevDexBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Manga Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Chapters',
                      icon: const Icon(Icons.refresh_rounded),
                      color: _primaryAccent,
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _glassSurfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2F2D39)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 100,
                                height: 140,
                                child: manga.thumbnailUrl == null
                                    ? const ColoredBox(
                                        color: _fieldColor,
                                        child: Icon(
                                          Icons.menu_book_rounded,
                                          color: _primaryAccent,
                                          size: 40,
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: manga.thumbnailUrl!,
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
                                children: [
                                  Text(
                                    manga.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Source: MangaDex',
                                    style: TextStyle(
                                      color: _mutedText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      // Optional action
                                    },
                                    child: const Text(
                                      'Open in MangaDex website',
                                      style: TextStyle(
                                        color: _primaryAccent,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (manga.description != null) ...[
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _glassSurfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2F2D39)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manga.description!,
                                maxLines: isDescriptionExpanded ? null : 3,
                                overflow: isDescriptionExpanded
                                    ? null
                                    : TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              if (manga.description!.length > 150)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        isDescriptionExpanded =
                                            !isDescriptionExpanded;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      isDescriptionExpanded
                                          ? 'Show Less'
                                          : 'Read More',
                                      style: const TextStyle(
                                        color: _primaryAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Text(
                        'Chapters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<MangaDexChapterPreview>>(
                        future: chaptersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: _MangaLoadingState(),
                            );
                          }

                          if (snapshot.hasError) {
                            return const _ReaderMessageState(
                              icon: Icons.error_outline_rounded,
                              title: 'Failed to load chapters.',
                              message: 'Please try again.',
                            );
                          }

                          final chapters =
                              snapshot.data ?? const <MangaDexChapterPreview>[];

                          if (chapters.isEmpty) {
                            return const _ReaderMessageState(
                              icon: Icons.menu_book_rounded,
                              title: 'No chapters available.',
                              message:
                                  'This manga might not have any chapters in English.',
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 30),
                            itemCount: chapters.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final chapter = chapters[index];
                              return _MangaDexDetailChapterCard(
                                chapter: chapter,
                                isOpening:
                                    openingChapterId == chapter.chapterId,
                                onOpen: () => _openChapter(chapter),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Hentai2ReadHomePage extends StatefulWidget {
  final Future<List<Hentai2ReadStoryPreview>> Function({int page})? storyLoader;

  const Hentai2ReadHomePage({super.key, this.storyLoader});

  @override
  State<Hentai2ReadHomePage> createState() => _Hentai2ReadHomePageState();
}

class _Hentai2ReadHomePageState extends State<Hentai2ReadHomePage> {
  final ScrollController _scrollController = ScrollController();
  final List<Hentai2ReadStoryPreview> _stories = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadInitialStories();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialStories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _stories.clear();
      _page = 1;
      _hasMore = true;
    });

    try {
      final loader = widget.storyLoader;
      final list = loader == null
          ? await fetchHentai2ReadHomeStories(page: _page)
          : await loader(page: _page);

      setState(() {
        _stories.addAll(list);
        _isLoading = false;
        if (list.isEmpty) {
          _hasMore = false;
        }
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load Hentai2Read Home.';
      });
    }
  }

  Future<void> _loadMoreStories() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final loader = widget.storyLoader;
      final list = loader == null
          ? await fetchHentai2ReadHomeStories(page: nextPage)
          : await loader(page: nextPage);

      setState(() {
        _page = nextPage;
        _stories.addAll(list);
        _isLoadingMore = false;
        if (list.isEmpty) {
          _hasMore = false;
        }
      });
    } catch (_) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.9) {
      _loadMoreStories();
    }
  }

  void _openStory(Hentai2ReadStoryPreview story) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Hentai2ReadStoryDetailPage(story: story),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _KevDexBackground(
        overlayOpacity: 0.86,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hentai2Read Home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Latest Stories',
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Hentai2Read Home',
                      icon: const Icon(Icons.refresh_rounded),
                      color: _primaryAccent,
                      onPressed: _loadInitialStories,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const _MangaLoadingState();
                    }

                    if (_errorMessage != null && _stories.isEmpty) {
                      return _ReaderMessageState(
                        icon: Icons.auto_stories_rounded,
                        title: _errorMessage!,
                        message: 'Refresh or check the network.',
                      );
                    }

                    if (_stories.isEmpty) {
                      return const _ReaderMessageState(
                        icon: Icons.auto_stories_rounded,
                        title: 'No Hentai2Read stories found.',
                        message: 'Refresh or check the network.',
                      );
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _stories.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index >= _stories.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _primaryAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final story = _stories[index];
                        return _Hentai2ReadStoryCard(
                          story: story,
                          onOpen: () => _openStory(story),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hentai2ReadStoryCard extends StatelessWidget {
  final Hentai2ReadStoryPreview story;
  final VoidCallback onOpen;

  const _Hentai2ReadStoryCard({required this.story, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _glassSurfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2F2D39)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 86,
                  child: story.thumbnailUrl == null
                      ? const _ThumbnailPlaceholder()
                      : _PrivateThumbnailFrame(
                          isPrivate: true,
                          child: CachedNetworkImage(
                            imageUrl: story.thumbnailUrl!,
                            httpHeaders: _readerImageRequestHeaders(
                              story.thumbnailUrl!,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const _ThumbnailPlaceholder(),
                            errorWidget: (context, url, error) =>
                                const _ThumbnailPlaceholder(),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (story.description != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        story.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    const Text(
                      'Hentai2Read',
                      style: TextStyle(
                        color: _primaryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _primaryAccent),
            ],
          ),
        ),
      ),
    );
  }
}

class Hentai2ReadStoryDetailPage extends StatefulWidget {
  final Hentai2ReadStoryPreview story;

  const Hentai2ReadStoryDetailPage({super.key, required this.story});

  @override
  State<Hentai2ReadStoryDetailPage> createState() =>
      _Hentai2ReadStoryDetailPageState();
}

class _Hentai2ReadStoryDetailPageState
    extends State<Hentai2ReadStoryDetailPage> {
  late Future<Hentai2ReadStoryDetail> detailFuture;
  String? openingChapterId;

  @override
  void initState() {
    super.initState();
    detailFuture = fetchHentai2ReadStoryDetail(widget.story.sourceLink);
  }

  void _refresh() {
    setState(() {
      detailFuture = fetchHentai2ReadStoryDetail(widget.story.sourceLink);
    });
  }

  Future<void> _openChapter(Hentai2ReadChapterPreview chapter) async {
    if (openingChapterId != null) {
      return;
    }

    setState(() {
      openingChapterId = chapter.chapterId;
    });

    StoryFetchResult? result;
    String? errorMessage;

    try {
      result = await fetchHentai2ReadStory(chapter.sourceLink);
    } catch (_) {
      errorMessage = 'Hentai2Read chapter could not be reached.';
    } finally {
      if (mounted) {
        setState(() {
          openingChapterId = null;
        });
      }
    }

    if (!mounted) {
      return;
    }

    if (result == null || result.images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ??
                result?.errorMessage ??
                'Hentai2Read did not return readable pages.',
          ),
        ),
      );
      return;
    }

    await KevDexMemory.saveLastLink(chapter.sourceLink);
    await KevDexMemory.saveLastHentai2ReadLink(chapter.sourceLink);

    final progress = ReadingProgress(
      sourceLink: chapter.sourceLink,
      images: List<DriveImage>.unmodifiable(result.images),
      pageIndex: 0,
      metadata: result.metadata,
    );

    readingProgressNotifier.value = progress;
    unawaited(KevDexMemory.saveReadingProgress(progress));

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          link: chapter.sourceLink,
          images: result!.images,
          initialIndex: 0,
          startInGallery: false,
          metadata: result.metadata,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _KevDexBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Hentai2Read Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Chapters',
                      icon: const Icon(Icons.refresh_rounded),
                      color: _primaryAccent,
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Hentai2ReadStoryDetail>(
                  future: detailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _MangaLoadingState();
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return const _ReaderMessageState(
                        icon: Icons.auto_stories_rounded,
                        title: 'Failed to load chapters.',
                        message: 'Please try again.',
                      );
                    }

                    final detail = snapshot.data!;
                    final story = detail.story;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Hentai2ReadStoryCard(story: story, onOpen: () {}),
                          const SizedBox(height: 18),
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (detail.chapters.isEmpty)
                            const _ReaderMessageState(
                              icon: Icons.auto_stories_rounded,
                              title: 'No chapters available.',
                              message: 'Try another story.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 30),
                              itemCount: detail.chapters.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final chapter = detail.chapters[index];
                                return _Hentai2ReadChapterCard(
                                  chapter: chapter,
                                  isOpening:
                                      openingChapterId == chapter.chapterId,
                                  onOpen: () => _openChapter(chapter),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HitomiHomePage extends StatefulWidget {
  final Future<List<HitomiGalleryPreview>> Function()? galleryLoader;

  const HitomiHomePage({super.key, this.galleryLoader});

  @override
  State<HitomiHomePage> createState() => _HitomiHomePageState();
}

class _HitomiHomePageState extends State<HitomiHomePage> {
  final ScrollController _scrollController = ScrollController();
  final List<HitomiGalleryPreview> _galleries = [];
  List<String> _galleryIds = [];
  HitomiRouting? _routing;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _currentIndex = 0;
  final int _pageSize = 12;
  String? openingGalleryId;

  @override
  void initState() {
    super.initState();
    _loadInitialGalleries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialGalleries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _galleries.clear();
      _galleryIds.clear();
      _currentIndex = 0;
      _hasMore = true;
    });

    try {
      final loader = widget.galleryLoader;
      if (loader != null) {
        final list = await loader();
        setState(() {
          _galleries.addAll(list);
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }

      if (kIsWeb) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }

      final response = await http
          .get(
            Uri.https(_hitomiIndexHost, _hitomiIndexPath),
            headers: {
              ..._readerRequestHeaders('hitomi.la'),
              'Range': 'bytes=0-8191',
            },
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Failed to load Hitomi index.');
      }

      _galleryIds = parseHitomiNozomiIds(response.bodyBytes, limit: 300);
      _routing = await fetchHitomiRouting();

      if (_galleryIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }

      final slice = _galleryIds.take(_pageSize).toList();
      final list = await fetchHitomiHomeGalleries(
        limit: _pageSize,
        targetIds: slice,
        targetRouting: _routing,
      );

      setState(() {
        _galleries.addAll(list);
        _currentIndex = slice.length;
        _isLoading = false;
        if (list.isEmpty || _currentIndex >= _galleryIds.length) {
          _hasMore = false;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Hitomi Home could not load.';
      });
    }
  }

  Future<void> _loadMoreGalleries() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _galleryIds.isEmpty ||
        _routing == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final slice = _galleryIds.skip(_currentIndex).take(_pageSize).toList();
      if (slice.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final list = await fetchHitomiHomeGalleries(
        limit: _pageSize,
        targetIds: slice,
        targetRouting: _routing,
      );

      setState(() {
        _galleries.addAll(list);
        _currentIndex += slice.length;
        _isLoadingMore = false;
        if (list.isEmpty || _currentIndex >= _galleryIds.length) {
          _hasMore = false;
        }
      });
    } catch (_) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.9) {
      _loadMoreGalleries();
    }
  }

  Future<void> _openGallery(HitomiGalleryPreview gallery) async {
    if (openingGalleryId != null) {
      return;
    }

    setState(() {
      openingGalleryId = gallery.galleryId;
    });

    StoryFetchResult? result;
    String? errorMessage;

    try {
      result = await fetchHitomiGallery(gallery.sourceLink);
    } catch (_) {
      errorMessage = 'Hitomi gallery could not be reached.';
    } finally {
      if (mounted) {
        setState(() {
          openingGalleryId = null;
        });
      }
    }

    if (!mounted) {
      return;
    }

    if (result == null || result.images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ??
                result?.errorMessage ??
                'Hitomi did not return readable pages.',
          ),
        ),
      );
      return;
    }

    await KevDexMemory.saveLastLink(gallery.sourceLink);
    await KevDexMemory.saveLastHitomiLink(gallery.sourceLink);

    final progress = ReadingProgress(
      sourceLink: gallery.sourceLink,
      images: List<DriveImage>.unmodifiable(result.images),
      pageIndex: 0,
      metadata: result.metadata,
    );

    readingProgressNotifier.value = progress;
    unawaited(KevDexMemory.saveReadingProgress(progress));

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          link: gallery.sourceLink,
          images: result!.images,
          initialIndex: 0,
          startInGallery: false,
          metadata: result.metadata,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _KevDexBackground(
        overlayOpacity: 0.86,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hitomi Home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Recent Galleries',
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Hitomi Home',
                      icon: const Icon(Icons.refresh_rounded),
                      color: _primaryAccent,
                      onPressed: _loadInitialGalleries,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const _MangaLoadingState();
                    }

                    if (_errorMessage != null && _galleries.isEmpty) {
                      return _ReaderMessageState(
                        icon: Icons.travel_explore_rounded,
                        title: _errorMessage!,
                        message: 'Refresh or check the network.',
                      );
                    }

                    if (_galleries.isEmpty) {
                      return _ReaderMessageState(
                        icon: Icons.travel_explore_rounded,
                        title: kIsWeb
                            ? 'Hitomi Home needs Android.'
                            : 'No Hitomi galleries found.',
                        message: kIsWeb
                            ? 'Chrome preview blocks Hitomi list requests.'
                            : 'Refresh or check the network.',
                      );
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _galleries.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index >= _galleries.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _primaryAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final gallery = _galleries[index];
                        return _HitomiGalleryCard(
                          gallery: gallery,
                          isOpening: openingGalleryId == gallery.galleryId,
                          onOpen: () => _openGallery(gallery),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HitomiGalleryCard extends StatelessWidget {
  final HitomiGalleryPreview gallery;
  final bool isOpening;
  final VoidCallback onOpen;

  const _HitomiGalleryCard({
    required this.gallery,
    required this.isOpening,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      'Gallery ${gallery.galleryId}',
      '${gallery.pageCount} pages',
      if (gallery.language != null) gallery.language!,
    ].join(' - ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpening ? null : onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _glassSurfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2F2D39)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 86,
                  child: _PrivateThumbnailFrame(
                    isPrivate: true,
                    child: CachedNetworkImage(
                      imageUrl: gallery.thumbnailUrl,
                      httpHeaders: _readerImageRequestHeaders(
                        gallery.thumbnailUrl,
                      ),
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const _ThumbnailPlaceholder(),
                      errorWidget: (context, url, error) =>
                          const _ThumbnailPlaceholder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gallery.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Hitomi',
                      style: TextStyle(
                        color: _primaryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                height: 28,
                child: isOpening
                    ? const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _primaryAccent,
                      )
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        color: _primaryAccent,
                      ),
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
  final bool startInGallery;
  final StoryMetadata? metadata;

  const ReaderPage({
    super.key,
    required this.link,
    required this.images,
    required this.initialIndex,
    this.startInGallery = false,
    this.metadata,
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

    final hasReadablePage =
        !widget.startInGallery &&
        (widget.images.isNotEmpty ||
            (!isDriveFolderLink(widget.link) &&
                convertDriveLinkToImageUrl(widget.link) != null));

    if (hasReadablePage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleControlsHide();
      });
    }
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

  void _showReaderComfortSheet() {
    _hideControlsToken++;
    setState(() {
      showControls = true;
    });

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ReaderComfortSheet(),
    ).whenComplete(() {
      if (mounted) {
        _scheduleControlsHide();
      }
    });
  }

  void _openReaderGallery(List<DriveImage> readerImages) {
    if (readerImages.isEmpty) {
      return;
    }

    _showControlsTemporarily();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderGalleryPage(
          folderImages: readerImages,
          sourceLink: widget.link,
          metadata: widget.metadata,
        ),
      ),
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

    final progress = ReadingProgress(
      sourceLink: widget.link,
      images: List<DriveImage>.unmodifiable(readerImages),
      pageIndex: pageIndex.clamp(0, readerImages.length - 1).toInt(),
      metadata: widget.metadata,
    );

    readingProgressNotifier.value = progress;
    unawaited(KevDexMemory.saveReadingProgress(progress));
  }

  @override
  Widget build(BuildContext context) {
    final isFolder = isDriveFolderLink(widget.link);
    final showGallery = isFolder && widget.startInGallery;
    final singleImageUrl = convertDriveLinkToImageUrl(widget.link);
    final folderImages = widget.images;
    final readerImages = _resolveReaderImages(isFolder, singleImageUrl);
    final pageCount = readerImages.length;
    final progress = pageCount == 0 ? 0.0 : (currentPageIndex + 1) / pageCount;

    if (!showGallery && readerImages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _saveReadingProgress(readerImages, currentPageIndex);
        }
      });
    }

    void preloadImage(String url) {
      precacheImage(
        NetworkImage(url, headers: _readerImageRequestHeaders(url)),
        context,
        onError: (error, stackTrace) {},
      );
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
            child: showGallery
                ? _GalleryGrid(
                    folderImages: folderImages,
                    sourceLink: widget.link,
                    metadata: widget.metadata,
                  )
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
                          child: ValueListenableBuilder<ReaderComfortSettings>(
                            valueListenable: readerComfortNotifier,
                            builder: (context, settings, child) {
                              return CachedNetworkImage(
                                imageUrl: currentImage.fullUrl,
                                httpHeaders: _readerImageRequestHeaders(
                                  currentImage.fullUrl,
                                ),
                                fit: settings.fitMode.fit,
                                placeholder: (context, url) =>
                                    const _MangaLoadingState(),
                                errorWidget: (context, url, error) {
                                  return const _ReaderMessageState(
                                    icon: Icons.broken_image_rounded,
                                    title: 'This page could not be opened.',
                                    message: 'Check the link or try again.',
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!showGallery && readerImages.isNotEmpty)
            ValueListenableBuilder<ReaderComfortSettings>(
              valueListenable: readerComfortNotifier,
              builder: (context, settings, child) {
                if (settings.shade <= 0) {
                  return const SizedBox.shrink();
                }

                return IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withAlpha(
                      (settings.shade.clamp(0.0, 0.55) * 255).round(),
                    ),
                  ),
                );
              },
            ),
          if (!showGallery && showControls && readerImages.length > 1)
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
          if (!showGallery && showControls && readerImages.length > 1)
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
          if (!showGallery && showControls && readerImages.isNotEmpty)
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: _ReaderProgressHud(
                currentPage: currentPageIndex + 1,
                totalPages: pageCount,
                progress: progress,
                onComfort: _showReaderComfortSheet,
                onGallery: readerImages.length > 1
                    ? () => _openReaderGallery(readerImages)
                    : null,
                onBack: () {
                  Navigator.pop(context);
                },
              ),
            ),
          if (showGallery || readerImages.isEmpty)
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

class _ReaderComfortSheet extends StatelessWidget {
  const _ReaderComfortSheet();

  void _updateSettings(ReaderComfortSettings settings) {
    readerComfortNotifier.value = settings;
    unawaited(KevDexMemory.saveReaderComfort(settings));
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
        child: ValueListenableBuilder<ReaderComfortSettings>(
          valueListenable: readerComfortNotifier,
          builder: (context, settings, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: _primaryAccent),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Reader Comfort',
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
                SegmentedButton<ReaderFitMode>(
                  segments: [
                    for (final mode in ReaderFitMode.values)
                      ButtonSegment<ReaderFitMode>(
                        value: mode,
                        icon: Icon(mode.icon, size: 18),
                        label: Text(mode.label),
                      ),
                  ],
                  selected: {settings.fitMode},
                  onSelectionChanged: (selection) {
                    _updateSettings(
                      settings.copyWith(fitMode: selection.first),
                    );
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: _fieldColor,
                    foregroundColor: _mutedText,
                    selectedBackgroundColor: _primaryAccent,
                    selectedForegroundColor: const Color(0xFF101016),
                    side: const BorderSide(color: Color(0xFF393745)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.dark_mode_rounded,
                      color: _mutedText,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Shade',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${(settings.shade * 100).round()}%',
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.shade.clamp(0.0, 0.55).toDouble(),
                  min: 0,
                  max: 0.55,
                  divisions: 11,
                  activeColor: _primaryAccent,
                  inactiveColor: const Color(0xFF393745),
                  onChanged: (value) {
                    _updateSettings(settings.copyWith(shade: value));
                  },
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    _updateSettings(defaultReaderComfortSettings);
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset Reader Comfort'),
                  style: TextButton.styleFrom(
                    foregroundColor: _mutedText,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ReaderGalleryPage extends StatelessWidget {
  final List<DriveImage> folderImages;
  final String sourceLink;
  final StoryMetadata? metadata;

  const ReaderGalleryPage({
    super.key,
    required this.folderImages,
    required this.sourceLink,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _GalleryGrid(
            folderImages: folderImages,
            sourceLink: sourceLink,
            metadata: metadata,
          ),
          Positioned(
            top: 40,
            left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                tooltip: 'Back',
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

Future<List<Hentai2ReadStoryPreview>> fetchHentai2ReadHomeStories({
  int page = 1,
}) async {
  try {
    final safePage = page < 1 ? 1 : page;
    final response = await http
        .get(
          Uri.https(
            'hentai2read.com',
            '/hentai-list/all/any/all/last-added/$safePage/',
          ),
          headers: _readerRequestHeaders('hentai2read.com'),
        )
        .timeout(_privateSourceRequestTimeout);

    if (response.statusCode != 200) {
      return const <Hentai2ReadStoryPreview>[];
    }

    return parseHentai2ReadHomePreviews(response.body);
  } catch (_) {
    return const <Hentai2ReadStoryPreview>[];
  }
}

List<Hentai2ReadStoryPreview> parseHentai2ReadHomePreviews(String html) {
  final previews = <Hentai2ReadStoryPreview>[];
  final seenSlugs = <String>{};
  final anchorPattern = RegExp(
    r'<a[^>]+href="(https?://hentai2read\.com/[^"]+/)"[^>]*class="[^"]*title[^"]*"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in anchorPattern.allMatches(html)) {
    final sourceLink = match.group(1)!;
    final slug = extractHentai2ReadStorySlug(sourceLink);

    if (slug == null || !seenSlugs.add(slug)) {
      continue;
    }

    final rawTitle = match.group(2) ?? '';
    final title = _stripHtml(rawTitle) ?? _titleFromSlug(slug);
    final contextStart = (match.start - 1400).clamp(0, html.length).toInt();
    final contextHtml = html.substring(contextStart, match.end);
    final thumbnailUrl = _lastHtmlImageSource(contextHtml);

    previews.add(
      Hentai2ReadStoryPreview(
        slug: slug,
        title: title,
        sourceLink: _hentai2ReadStoryLink(slug),
        thumbnailUrl: thumbnailUrl,
      ),
    );
  }

  return List<Hentai2ReadStoryPreview>.unmodifiable(previews);
}

Future<Hentai2ReadStoryDetail> fetchHentai2ReadStoryDetail(
  String sourceLink,
) async {
  final slug = extractHentai2ReadStorySlug(sourceLink);
  final fallback = Hentai2ReadStoryDetail(
    story: Hentai2ReadStoryPreview(
      slug: slug ?? 'hentai2read',
      title: slug == null ? 'Hentai2Read Story' : _titleFromSlug(slug),
      sourceLink: slug == null ? sourceLink : _hentai2ReadStoryLink(slug),
    ),
    chapters: const <Hentai2ReadChapterPreview>[],
  );

  if (slug == null) {
    return fallback;
  }

  try {
    final response = await http
        .get(
          Uri.https('hentai2read.com', '/$slug/'),
          headers: _readerRequestHeaders('hentai2read.com'),
        )
        .timeout(_privateSourceRequestTimeout);

    if (response.statusCode != 200) {
      return fallback;
    }

    return parseHentai2ReadStoryDetail(
      response.body,
      sourceLink: _hentai2ReadStoryLink(slug),
      fallbackSlug: slug,
    );
  } catch (_) {
    return fallback;
  }
}

Hentai2ReadStoryDetail parseHentai2ReadStoryDetail(
  String html, {
  required String sourceLink,
  required String fallbackSlug,
}) {
  final title =
      _firstMetaContent(html, 'og:title') ??
      _firstHeadingText(html) ??
      _titleFromSlug(fallbackSlug);
  final thumbnailUrl =
      _firstMetaContent(html, 'og:image') ?? _lastHtmlImageSource(html);
  final story = Hentai2ReadStoryPreview(
    slug: fallbackSlug,
    title: title,
    sourceLink: _hentai2ReadStoryLink(fallbackSlug),
    thumbnailUrl: thumbnailUrl,
  );

  final chapters = parseHentai2ReadChapterPreviews(
    html,
    storyTitle: story.title,
    thumbnailUrl: story.thumbnailUrl,
  );

  return Hentai2ReadStoryDetail(story: story, chapters: chapters);
}

List<Hentai2ReadChapterPreview> parseHentai2ReadChapterPreviews(
  String html, {
  required String storyTitle,
  String? thumbnailUrl,
}) {
  final chapters = <Hentai2ReadChapterPreview>[];
  final seenLinks = <String>{};
  final chapterPattern = RegExp(
    r'<a[^>]+href="(https?://hentai2read\.com/([^"/]+)/(\d+)/)"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in chapterPattern.allMatches(html)) {
    final sourceLink = match.group(1)!;
    if (!seenLinks.add(sourceLink)) {
      continue;
    }

    final chapterId = match.group(3)!;
    final rawLabel = (match.group(4) ?? '')
        .split(RegExp(r'<div', caseSensitive: false))
        .first;
    final chapterLabel = _hentai2ReadChapterLabel(rawLabel, chapterId);

    chapters.add(
      Hentai2ReadChapterPreview(
        chapterId: chapterId,
        sourceLink: sourceLink,
        title: storyTitle,
        chapterLabel: chapterLabel,
        thumbnailUrl: thumbnailUrl,
      ),
    );
  }

  if (chapters.isEmpty) {
    final fallbackSourceLink = sourceLinkFromHtml(html);
    final slug = fallbackSourceLink == null
        ? null
        : extractHentai2ReadStorySlug(fallbackSourceLink);
    if (slug != null) {
      chapters.add(
        Hentai2ReadChapterPreview(
          chapterId: '1',
          sourceLink: _hentai2ReadChapterLink(slug, '1'),
          title: storyTitle,
          chapterLabel: 'Chapter 1',
          thumbnailUrl: thumbnailUrl,
        ),
      );
    }
  }

  chapters.sort((a, b) {
    final left = int.tryParse(a.chapterId) ?? 0;
    final right = int.tryParse(b.chapterId) ?? 0;
    return left.compareTo(right);
  });

  return List<Hentai2ReadChapterPreview>.unmodifiable(chapters);
}

Future<StoryFetchResult> fetchHentai2ReadStory(String link) async {
  final target = extractHentai2ReadTarget(link);
  final fallback = StoryFetchResult(
    images: const <DriveImage>[],
    metadata: StoryMetadata(
      sourceType: StorySourceType.hentai2ReadChapter,
      title: target == null ? 'Hentai2Read Story' : _titleFromSlug(target),
    ),
    errorMessage: target == null
        ? 'Paste a valid Hentai2Read story or chapter link.'
        : 'Hentai2Read did not return readable pages.',
  );

  if (target == null) {
    return fallback;
  }

  var readerLink = link;
  String? title;
  String? chapterLabel;

  if (!target.contains('/')) {
    final detail = await fetchHentai2ReadStoryDetail(link);
    if (detail.chapters.isEmpty) {
      return fallback;
    }

    final firstChapter = detail.chapters.first;
    readerLink = firstChapter.sourceLink;
    title = detail.story.title;
    chapterLabel = firstChapter.chapterLabel;
  }

  final uri = _hentai2ReadUri(readerLink);
  if (uri == null) {
    return fallback;
  }

  try {
    final response = await http
        .get(uri, headers: _readerRequestHeaders('hentai2read.com'))
        .timeout(_privateSourceRequestTimeout);

    if (response.statusCode != 200) {
      return fallback;
    }

    return parseHentai2ReadReaderPage(
      response.body,
      sourceLink: readerLink,
      fallbackTitle: title,
      fallbackChapterLabel: chapterLabel,
    );
  } catch (_) {
    return StoryFetchResult(
      images: fallback.images,
      metadata: fallback.metadata,
      errorMessage: 'Hentai2Read could not be reached on this network.',
    );
  }
}

StoryFetchResult parseHentai2ReadReaderPage(
  String html, {
  required String sourceLink,
  String? fallbackTitle,
  String? fallbackChapterLabel,
}) {
  final slug = extractHentai2ReadStorySlug(sourceLink);
  final target = extractHentai2ReadTarget(sourceLink);
  final chapterId = target?.contains('/') ?? false
      ? target!.split('/').last
      : null;
  final title =
      _hentai2ReadScriptValue(html, 'title') ??
      fallbackTitle ??
      (slug == null ? 'Hentai2Read Story' : _titleFromSlug(slug));
  final chapterLabel =
      fallbackChapterLabel ?? (chapterId == null ? null : 'Chapter $chapterId');
  final images = _hentai2ReadScriptImages(html);

  if (images.isEmpty) {
    return StoryFetchResult(
      images: const <DriveImage>[],
      metadata: StoryMetadata(
        sourceType: StorySourceType.hentai2ReadChapter,
        title: title,
        chapterLabel: chapterLabel,
      ),
      errorMessage: 'Hentai2Read did not include readable pages.',
    );
  }

  return StoryFetchResult(
    images: List<DriveImage>.unmodifiable(images),
    metadata: StoryMetadata(
      sourceType: StorySourceType.hentai2ReadChapter,
      title: title,
      chapterLabel: chapterLabel,
    ),
  );
}

List<DriveImage> _hentai2ReadScriptImages(String html) {
  final imagesMatch = RegExp(
    r'''['"]images['"]\s*:\s*\[(.*?)\]''',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);

  if (imagesMatch == null) {
    return const <DriveImage>[];
  }

  final images = <DriveImage>[];
  for (final match in RegExp(
    r'''['"]((?:\\.|[^'"\\])+)['"]''',
    dotAll: true,
  ).allMatches(imagesMatch.group(1)!)) {
    final rawPath = match.group(1)!.replaceAll(r'\/', '/');
    final pageUrl = rawPath.startsWith('http')
        ? rawPath
        : 'https://static.hentai.direct/hentai${rawPath.startsWith('/') ? rawPath : '/$rawPath'}';
    images.add(DriveImage(thumbnailUrl: pageUrl, fullUrl: pageUrl));
  }

  return List<DriveImage>.unmodifiable(images);
}

String? _hentai2ReadScriptValue(String html, String key) {
  final pattern = RegExp(
    '''['"]$key['"]\\s*:\\s*['"]((?:\\\\.|[^'"\\\\])*)['"]''',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(html);

  if (match == null) {
    return null;
  }

  return _decodeHtmlEntities(match.group(1)!.replaceAll(r'\/', '/'));
}

String? sourceLinkFromHtml(String html) {
  final canonical = _firstMetaContent(html, 'og:url');
  if (canonical != null) {
    return canonical;
  }

  final match = RegExp(
    r'https?://hentai2read\.com/[a-zA-Z0-9_-]+/',
    caseSensitive: false,
  ).firstMatch(html);
  return match?.group(0);
}

String? _firstMetaContent(String html, String property) {
  final escapedProperty = RegExp.escape(property);
  final pattern = RegExp(
    '<meta[^>]+(?:property|name)=["'
    ']$escapedProperty["'
    '][^>]+content=["'
    ']([^"'
    ']+)["'
    '][^>]*>',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(html);

  if (match == null) {
    return null;
  }

  return _decodeHtmlEntities(match.group(1)!);
}

String? _firstHeadingText(String html) {
  final match = RegExp(
    r'<h1[^>]*>(.*?)</h1>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);

  if (match == null) {
    return null;
  }

  return _stripHtml(match.group(1)!);
}

String? _lastHtmlImageSource(String html) {
  String? source;
  final pattern = RegExp(
    r'<img[^>]+(?:src|data-src)=["'
    ']([^"'
    ']+)["'
    '][^>]*>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in pattern.allMatches(html)) {
    source = _decodeHtmlEntities(match.group(1)!);
  }

  return source;
}

String? _stripHtml(String html) {
  final cleaned = html
      .replaceAll(
        RegExp(r'<script.*?</script>', caseSensitive: false, dotAll: true),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style.*?</style>', caseSensitive: false, dotAll: true),
        ' ',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) {
    return null;
  }

  return _decodeHtmlEntities(cleaned);
}

String _hentai2ReadChapterLabel(String html, String chapterId) {
  final text = _stripHtml(html);

  if (text == null) {
    return 'Chapter $chapterId';
  }

  final cleaned = text.replaceFirst(RegExp(r'^\d+\s*-\s*'), '').trim();

  if (cleaned.isEmpty) {
    return 'Chapter $chapterId';
  }

  return 'Chapter $chapterId - $cleaned';
}

String _titleFromSlug(String slug) {
  return slug
      .split(RegExp(r'[_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

String? extractNHentaiGalleryId(String link) {
  final cleanedLink = link.trim();
  final directIdMatch = RegExp(
    r'^(?:nhentai:)?(\d{2,})$',
  ).firstMatch(cleanedLink);

  if (directIdMatch != null) {
    return directIdMatch.group(1);
  }

  final uri = Uri.tryParse(cleanedLink);
  final host = uri?.host.toLowerCase() ?? '';

  if (!host.contains('nhentai')) {
    return null;
  }

  final pathSegments = uri?.pathSegments ?? const <String>[];

  for (var index = 0; index < pathSegments.length - 1; index++) {
    if (pathSegments[index].toLowerCase() != 'g') {
      continue;
    }

    final galleryId = RegExp(r'^\d+$').firstMatch(pathSegments[index + 1]);

    if (galleryId != null) {
      return galleryId.group(0);
    }
  }

  return null;
}

String? extractHitomiGalleryId(String link) {
  final cleanedLink = link.trim();
  final directIdMatch = RegExp(r'^hitomi:(\d{2,})$').firstMatch(cleanedLink);

  if (directIdMatch != null) {
    return directIdMatch.group(1);
  }

  final uri = Uri.tryParse(cleanedLink);
  final host = uri?.host.toLowerCase() ?? '';

  if (!host.contains('hitomi.')) {
    return null;
  }

  final lastPathSegment = uri?.pathSegments.isEmpty ?? true
      ? ''
      : uri!.pathSegments.last;
  final galleryIdMatch = RegExp(
    r'(\d+)\.html$',
    caseSensitive: false,
  ).firstMatch(lastPathSegment);

  return galleryIdMatch?.group(1);
}

Future<StoryFetchResult> fetchNHentaiGallery(String link) async {
  final galleryId = extractNHentaiGalleryId(link);
  final fallback = StoryFetchResult(
    images: const <DriveImage>[],
    metadata: StoryMetadata(
      sourceType: StorySourceType.nHentaiGallery,
      title: galleryId == null ? 'NHentai Gallery' : 'NHentai $galleryId',
      chapterLabel: galleryId == null ? null : 'Gallery $galleryId',
    ),
    errorMessage: galleryId == null
        ? 'Paste a valid NHentai gallery link.'
        : 'NHentai did not return readable pages.',
  );

  if (galleryId == null) {
    return fallback;
  }

  final hosts = _nHentaiCandidateHosts(link);
  String? lastErrorMessage;

  for (final host in hosts) {
    try {
      final response = await http
          .get(
            Uri.https(host, '/api/gallery/$galleryId'),
            headers: _readerRequestHeaders(host),
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200) {
        lastErrorMessage = _nHentaiStatusMessage(
          host,
          response.statusCode,
          api: true,
        );
        continue;
      }

      final decoded = jsonDecode(response.body);
      final result = parseNHentaiGalleryPayload(decoded, galleryId);

      if (result.images.isNotEmpty) {
        return result;
      }
      lastErrorMessage = result.errorMessage;
    } catch (error) {
      lastErrorMessage = _nHentaiConnectionMessage(host, error);
    }
  }

  for (final host in hosts) {
    try {
      final response = await http
          .get(
            Uri.https(host, '/g/$galleryId/'),
            headers: _readerRequestHeaders(host),
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200) {
        lastErrorMessage = _nHentaiStatusMessage(
          host,
          response.statusCode,
          api: false,
        );
        continue;
      }

      final result = parseNHentaiGalleryPage(response.body, galleryId);

      if (result.images.isNotEmpty) {
        return result;
      }
      lastErrorMessage = result.errorMessage;
    } catch (error) {
      lastErrorMessage = _nHentaiConnectionMessage(host, error);
    }
  }

  return StoryFetchResult(
    images: fallback.images,
    metadata: fallback.metadata,
    errorMessage: lastErrorMessage ?? fallback.errorMessage,
  );
}

StoryFetchResult parseNHentaiGalleryPage(String html, String galleryId) {
  if (_looksLikeCloudflareChallenge(html)) {
    return StoryFetchResult(
      images: const <DriveImage>[],
      metadata: StoryMetadata(
        sourceType: StorySourceType.nHentaiGallery,
        title: 'NHentai $galleryId',
        chapterLabel: 'Gallery $galleryId',
      ),
      errorMessage:
          'NHentai is asking for browser verification. Try opening it in a browser first, or use another source.',
    );
  }

  final gallery = _extractNHentaiGalleryMap(html);
  return parseNHentaiGalleryPayload(gallery, galleryId);
}

StoryFetchResult parseNHentaiGalleryPayload(Object? payload, String galleryId) {
  final fallback = StoryFetchResult(
    images: const <DriveImage>[],
    metadata: StoryMetadata(
      sourceType: StorySourceType.nHentaiGallery,
      title: 'NHentai $galleryId',
      chapterLabel: 'Gallery $galleryId',
    ),
    errorMessage: 'NHentai metadata could not be read.',
  );

  if (payload is! Map) {
    return fallback;
  }

  final mediaId = _cleanString(payload['media_id']);
  final title = _nHentaiTitle(payload['title']) ?? fallback.metadata.title;
  final images = payload['images'];
  final pages = images is Map ? images['pages'] : null;

  if (mediaId == null || pages is! List) {
    return StoryFetchResult(
      images: const <DriveImage>[],
      metadata: StoryMetadata(
        sourceType: StorySourceType.nHentaiGallery,
        title: title,
        chapterLabel: 'Gallery $galleryId',
      ),
      errorMessage: 'NHentai metadata did not include readable pages.',
    );
  }

  final driveImages = <DriveImage>[];

  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    final pageType = page is Map ? _cleanString(page['t']) : null;
    final extension = _nHentaiExtension(pageType);
    final pageNumber = index + 1;
    final pageUrl =
        'https://i.nhentai.net/galleries/$mediaId/$pageNumber.$extension';

    driveImages.add(DriveImage(thumbnailUrl: pageUrl, fullUrl: pageUrl));
  }

  return StoryFetchResult(
    images: List<DriveImage>.unmodifiable(driveImages),
    metadata: StoryMetadata(
      sourceType: StorySourceType.nHentaiGallery,
      title: title,
      chapterLabel: 'Gallery $galleryId',
    ),
  );
}

Future<List<HitomiGalleryPreview>> fetchHitomiHomeGalleries({
  int limit = 12,
  List<String>? targetIds,
  HitomiRouting? targetRouting,
}) async {
  if (kIsWeb) {
    return const <HitomiGalleryPreview>[];
  }

  try {
    final List<String> galleryIds;
    final HitomiRouting routing;

    if (targetIds != null && targetRouting != null) {
      galleryIds = targetIds;
      routing = targetRouting;
    } else {
      final response = await http
          .get(
            Uri.https(_hitomiIndexHost, _hitomiIndexPath),
            headers: {
              ..._readerRequestHeaders('hitomi.la'),
              'Range': 'bytes=0-4095',
            },
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200 && response.statusCode != 206) {
        return const <HitomiGalleryPreview>[];
      }

      galleryIds = parseHitomiNozomiIds(response.bodyBytes, limit: limit * 4);
      routing = await fetchHitomiRouting();
    }

    final previews = <HitomiGalleryPreview>[];
    int currentIndex = 0;

    while (previews.length < limit && currentIndex < galleryIds.length) {
      final batchSize = (limit - previews.length) + 4;
      final batchIds = galleryIds.skip(currentIndex).take(batchSize).toList();
      if (batchIds.isEmpty) break;

      currentIndex += batchIds.length;

      final futures = batchIds.map(
        (id) => fetchHitomiGalleryPreview(id, routing),
      );
      final results = await Future.wait(futures);

      for (final preview in results) {
        if (preview != null) {
          previews.add(preview);
        }
      }
    }

    return List<HitomiGalleryPreview>.unmodifiable(previews.take(limit));
  } catch (_) {
    return const <HitomiGalleryPreview>[];
  }
}

List<String> parseHitomiNozomiIds(List<int> bytes, {int limit = 40}) {
  if (limit <= 0) {
    return const <String>[];
  }

  final ids = <String>[];

  for (var offset = 0; offset + 3 < bytes.length; offset += 4) {
    final id =
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];

    if (id > 0) {
      ids.add(id.toString());
    }

    if (ids.length >= limit) {
      break;
    }
  }

  return List<String>.unmodifiable(ids);
}

Future<HitomiGalleryPreview?> fetchHitomiGalleryPreview(
  String galleryId,
  HitomiRouting routing,
) async {
  for (final host in _hitomiGalleryInfoHosts) {
    try {
      final response = await http
          .get(
            Uri.https(host, '/galleries/$galleryId.js'),
            headers: _readerRequestHeaders('hitomi.la'),
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200) {
        continue;
      }

      final preview = parseHitomiGalleryPreview(
        response.body,
        galleryId,
        routing: routing,
      );

      if (preview != null) {
        return preview;
      }
    } catch (_) {}
  }

  return null;
}

HitomiGalleryPreview? parseHitomiGalleryPreview(
  String script,
  String galleryId, {
  HitomiRouting routing = _fallbackHitomiRouting,
}) {
  final galleryInfo = _extractHitomiGalleryInfo(script);

  if (galleryInfo == null) {
    return null;
  }

  final files = galleryInfo['files'];

  if (files is! List || files.isEmpty) {
    return null;
  }

  final firstFile = files.first;

  if (firstFile is! Map) {
    return null;
  }

  final hash = _cleanString(firstFile['hash']);

  if (hash == null) {
    return null;
  }

  return HitomiGalleryPreview(
    galleryId: galleryId,
    title: _cleanString(galleryInfo['title']) ?? 'Hitomi $galleryId',
    sourceLink: 'https://hitomi.la/reader/$galleryId.html',
    thumbnailUrl: _hitomiWebpImageUrl(hash, routing),
    pageCount: files.whereType<Map>().length,
    language:
        _cleanString(galleryInfo['language_localname']) ??
        _cleanString(galleryInfo['language']),
  );
}

Future<StoryFetchResult> fetchHitomiGallery(String link) async {
  final galleryId = extractHitomiGalleryId(link);
  final fallback = StoryFetchResult(
    images: const <DriveImage>[],
    metadata: StoryMetadata(
      sourceType: StorySourceType.hitomiGallery,
      title: galleryId == null ? 'Hitomi Gallery' : 'Hitomi $galleryId',
      chapterLabel: galleryId == null ? null : 'Gallery $galleryId',
    ),
    errorMessage: galleryId == null
        ? 'Paste a valid Hitomi gallery link.'
        : 'Hitomi did not return readable pages.',
  );

  if (galleryId == null) {
    return fallback;
  }

  String? lastErrorMessage;
  final routing = await fetchHitomiRouting();

  for (final host in _hitomiGalleryInfoHosts) {
    try {
      final response = await http
          .get(
            Uri.https(host, '/galleries/$galleryId.js'),
            headers: _readerRequestHeaders('hitomi.la'),
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200) {
        lastErrorMessage =
            'Hitomi metadata replied with ${response.statusCode}. Try again later.';
        continue;
      }

      final result = parseHitomiGalleryInfo(
        response.body,
        galleryId,
        routing: routing,
      );

      if (result.images.isEmpty) {
        lastErrorMessage = result.errorMessage;
        continue;
      }

      return result;
    } catch (_) {
      lastErrorMessage =
          'Hitomi page list could not be reached on this network.';
    }
  }

  return StoryFetchResult(
    images: fallback.images,
    metadata: fallback.metadata,
    errorMessage: lastErrorMessage ?? fallback.errorMessage,
  );
}

StoryFetchResult parseHitomiGalleryInfo(
  String script,
  String galleryId, {
  HitomiRouting routing = _fallbackHitomiRouting,
}) {
  final galleryInfo = _extractHitomiGalleryInfo(script);
  final fallback = StoryFetchResult(
    images: const <DriveImage>[],
    metadata: StoryMetadata(
      sourceType: StorySourceType.hitomiGallery,
      title: 'Hitomi $galleryId',
      chapterLabel: 'Gallery $galleryId',
    ),
    errorMessage: 'Hitomi metadata could not be read.',
  );

  if (galleryInfo == null) {
    return fallback;
  }

  final title = _cleanString(galleryInfo['title']) ?? fallback.metadata.title;
  final files = galleryInfo['files'];

  if (files is! List) {
    return StoryFetchResult(
      images: const <DriveImage>[],
      metadata: StoryMetadata(
        sourceType: StorySourceType.hitomiGallery,
        title: title,
        chapterLabel: 'Gallery $galleryId',
      ),
      errorMessage: 'Hitomi metadata did not include readable pages.',
    );
  }

  final images = <DriveImage>[];

  for (final file in files.whereType<Map>()) {
    final hash = _cleanString(file['hash']);

    if (hash == null) {
      continue;
    }

    final pageUrl = _hitomiWebpImageUrl(hash, routing);

    images.add(DriveImage(thumbnailUrl: pageUrl, fullUrl: pageUrl));
  }

  return StoryFetchResult(
    images: List<DriveImage>.unmodifiable(images),
    metadata: StoryMetadata(
      sourceType: StorySourceType.hitomiGallery,
      title: title,
      chapterLabel: 'Gallery $galleryId',
    ),
  );
}

List<String> _nHentaiCandidateHosts(String link) {
  final hosts = <String>[];
  final uri = Uri.tryParse(link.trim());
  final host = uri?.host.toLowerCase() ?? '';

  if (host.contains('nhentai')) {
    hosts.add(host);
  }

  hosts.add('nhentai.net');
  return hosts.toSet().toList(growable: false);
}

const List<String> _hitomiGalleryInfoHosts = <String>[
  'ltn.gold-usergeneratedcontent.net',
  'ltn.hitomi.la',
];

const String _hitomiIndexHost = 'ltn.gold-usergeneratedcontent.net';
const String _hitomiIndexPath = '/index-all.nozomi';
const String _hitomiImageHost = 'a.gold-usergeneratedcontent.net';
const Duration _privateSourceRequestTimeout = Duration(seconds: 18);
const HitomiRouting _fallbackHitomiRouting = HitomiRouting(
  versionPath: '1782280801/',
);

class HitomiRouting {
  final String versionPath;
  // Keys where mirrorIndex = 1 (subdomain w2). In the new gg.js format the
  // switch-case list maps to o=1; everything else defaults to o=0 (w1).
  final Set<int> oneSubdomainKeys;

  const HitomiRouting({
    this.versionPath = '',
    this.oneSubdomainKeys = const <int>{},
  });

  int mirrorForHash(String hash) {
    return oneSubdomainKeys.contains(hitomiRoutingKey(hash)) ? 1 : 0;
  }

  String webpSubdomainForHash(String hash) {
    return 'w${1 + mirrorForHash(hash)}';
  }

  String fullPathForHash(String hash) {
    final key = hitomiRoutingKey(hash);

    if (versionPath.isEmpty) {
      return _hitomiLegacyFullPathFromHash(hash);
    }

    return '$versionPath$key/$hash';
  }
}

Future<HitomiRouting> fetchHitomiRouting() async {
  for (final host in _hitomiGalleryInfoHosts) {
    try {
      final response = await http
          .get(
            Uri.https(host, '/gg.js'),
            headers: _readerRequestHeaders('hitomi.la'),
          )
          .timeout(_privateSourceRequestTimeout);

      if (response.statusCode != 200) {
        continue;
      }

      return parseHitomiRoutingScript(response.body);
    } catch (_) {}
  }

  return _fallbackHitomiRouting;
}

/// Parses Hitomi's gg.js routing script.
///
/// The current gg.js format looks like:
///   gg = { m: function(g) {
///     var o = 0;
///     switch (g) { case 123: case 456: ... o = 1; break; }
///     return o;
///   }, s: function(h) { ... }, b: 'VERSION/' };
///
/// The switch-case list contains keys where o=1 (mirror index 1, subdomain
/// w2). All other keys fall through to the default o=0 (subdomain w1).
/// An older format had o=0 inside the switch Ã¢â‚¬â€ this parser handles both.
HitomiRouting parseHitomiRoutingScript(String script) {
  final versionPath =
      RegExp(r"\bb\s*:\s*'([^']*)'").firstMatch(script)?.group(1) ?? '';

  // Try new format first: cases inside the switch map to o=1.
  final oneBlock = RegExp(
    r'switch\s*\([^)]+\)\s*\{(.*?)o\s*=\s*1\s*;',
    dotAll: true,
  ).firstMatch(script);

  if (oneBlock != null) {
    final oneSubdomainKeys = <int>{};
    for (final match in RegExp(
      r'case\s+(\d+)\s*:',
    ).allMatches(oneBlock.group(1)!)) {
      final key = int.tryParse(match.group(1)!);
      if (key != null) {
        oneSubdomainKeys.add(key);
      }
    }
    return HitomiRouting(
      versionPath: versionPath,
      oneSubdomainKeys: Set<int>.unmodifiable(oneSubdomainKeys),
    );
  }

  // Legacy format: cases inside the switch map to o=0 (mirror 0, subdomain w1).
  // In that case keys NOT in the set map to mirror 1, which is what the old
  // zeroSubdomainKeys logic relied on. We store those as oneSubdomainKeys by
  // collecting all keys from the o=0 block and noting that everything else is
  // mirror 1. Because we cannot enumerate "everything else", we fall back to
  // an empty oneSubdomainKeys set (all keys Ã¢â€ â€™ w1) which is a safe default.
  return HitomiRouting(versionPath: versionPath);
}

int hitomiRoutingKey(String hash) {
  final match = RegExp(r'(..)(.)$').firstMatch(hash);

  if (match == null) {
    return 0;
  }

  return int.tryParse('${match.group(2)}${match.group(1)}', radix: 16) ?? 0;
}

String _hitomiWebpImageUrl(String hash, HitomiRouting routing) {
  final subdomain = routing.webpSubdomainForHash(hash);
  final path = routing.fullPathForHash(hash);
  return 'https://$subdomain.gold-usergeneratedcontent.net/$path.webp';
}

Map<String, String> _readerRequestHeaders(String host) {
  if (kIsWeb) {
    return {'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8'};
  }

  return {
    'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://$host/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) KevDex/2.2 Safari/537.36',
  };
}

String _nHentaiStatusMessage(String host, int statusCode, {required bool api}) {
  final normalizedHost = host.toLowerCase();

  if (normalizedHost == 'nhentai.to') {
    return api
        ? 'nhentai.to does not expose the metadata API KevDex needs.'
        : 'nhentai.to replied with $statusCode before KevDex could read pages.';
  }

  return api
      ? 'NHentai metadata replied with $statusCode. Try another mirror or VPN.'
      : 'NHentai page replied with $statusCode. Try another mirror or VPN.';
}

String _nHentaiConnectionMessage(String host, Object error) {
  final normalizedHost = host.toLowerCase();
  final errorText = error.toString().toLowerCase();

  if (normalizedHost == 'nhentai.to') {
    return 'nhentai.to opens in Chrome, but blocks KevDex app requests. This source needs a future Browser Bridge.';
  }

  if (errorText.contains('timeout')) {
    return 'NHentai timed out before pages could be read. Try another mirror or VPN.';
  }

  if (errorText.contains('handshake') ||
      errorText.contains('connection') ||
      errorText.contains('tls')) {
    return 'NHentai closed the app connection before pages could be read. Try another mirror or VPN.';
  }

  return 'NHentai page could not be reached. Try another mirror or VPN.';
}

Map<String, String>? _readerImageRequestHeaders(String url) {
  if (kIsWeb) {
    return null;
  }

  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';

  if (host.contains('hitomi') || host.contains('gold-usergeneratedcontent')) {
    return {
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Referer': 'https://hitomi.la/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) KevDex/2.2 Safari/537.36',
    };
  }

  if (host.contains('hentaicdn') || host.contains('hentai.direct')) {
    return _readerRequestHeaders('hentai2read.com');
  }

  if (host.contains('nhentai')) {
    return _readerRequestHeaders('nhentai.net');
  }

  return null;
}

bool _looksLikeCloudflareChallenge(String html) {
  return html.contains('cf_chl') ||
      html.contains('challenge-platform') ||
      html.contains('Enable JavaScript and cookies to continue') ||
      html.contains('Just a moment');
}

Map<String, Object?>? _extractNHentaiGalleryMap(String html) {
  final jsonParseMatch = RegExp(
    r'window\._gallery\s*=\s*JSON\.parse\("((?:\\.|[^"\\])*)"\)',
    dotAll: true,
  ).firstMatch(html);

  if (jsonParseMatch != null) {
    try {
      final rawJson = jsonDecode('"${jsonParseMatch.group(1)!}"');

      if (rawJson is String) {
        final decoded = jsonDecode(rawJson);

        if (decoded is Map) {
          return Map<String, Object?>.from(decoded);
        }
      }
    } catch (_) {}
  }

  final directMatch = RegExp(
    r'window\._gallery\s*=\s*(\{.*?\});',
    dotAll: true,
  ).firstMatch(html);

  if (directMatch == null) {
    return null;
  }

  try {
    final decoded = jsonDecode(directMatch.group(1)!);

    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {}

  return null;
}

String? _nHentaiTitle(Object? titleValue) {
  if (titleValue is String) {
    return _cleanString(titleValue);
  }

  if (titleValue is! Map) {
    return null;
  }

  for (final key in const ['pretty', 'english', 'japanese']) {
    final title = _cleanString(titleValue[key]);

    if (title != null) {
      return title;
    }
  }

  return null;
}

String _nHentaiExtension(String? pageType) {
  return switch (pageType) {
    'p' => 'png',
    'g' => 'gif',
    'w' => 'webp',
    _ => 'jpg',
  };
}

Map<String, Object?>? _extractHitomiGalleryInfo(String script) {
  final match = RegExp(
    r'var\s+galleryinfo\s*=\s*(\{.*\});?\s*$',
    dotAll: true,
  ).firstMatch(script.trim());

  if (match == null) {
    return null;
  }

  try {
    final decoded = jsonDecode(match.group(1)!);

    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {}

  return null;
}

String _hitomiLegacyFullPathFromHash(String hash) {
  if (hash.length < 3) {
    return hash;
  }

  final last = hash.substring(hash.length - 1);
  final previousTwo = hash.substring(hash.length - 3, hash.length - 1);
  return '$last/$previousTwo/$hash';
}

Future<String?> fetchDriveFolderName(String folderId) async {
  try {
    final response = await http.get(
      Uri.https('www.googleapis.com', '/drive/v3/files/$folderId', {
        'fields': 'name',
        'key': 'AIzaSyAHIpqx856jNpz9nrD7BBwakLkTY89cHnc',
      }),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, Object?>) {
      return null;
    }

    return _cleanString(data['name']);
  } catch (_) {
    return null;
  }
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

Future<List<MangaDexChapterPreview>> fetchMangaDexHomeChapters({
  int limit = 20,
}) async {
  try {
    final response = await http.get(
      Uri.https('api.mangadex.org', '/chapter', {
        'limit': limit.toString(),
        'translatedLanguage[]': 'en',
        'includes[]': 'manga',
        'contentRating[]': ['safe', 'suggestive', 'erotica'],
        'order[readableAt]': 'desc',
      }),
    );

    if (response.statusCode != 200) {
      return const <MangaDexChapterPreview>[];
    }

    final decoded = jsonDecode(response.body);
    final previews = parseMangaDexChapterPreviews(decoded);
    final mangaIds = previews
        .map((preview) => preview.mangaId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final coverUrls = await fetchMangaDexCoverUrls(mangaIds);

    return List<MangaDexChapterPreview>.unmodifiable(
      previews.map((preview) {
        final mangaId = preview.mangaId;

        if (mangaId == null) {
          return preview;
        }

        return preview.copyWith(thumbnailUrl: coverUrls[mangaId]);
      }),
    );
  } catch (_) {
    return const <MangaDexChapterPreview>[];
  }
}

Future<List<MangaDexMangaPreview>> fetchMangaDexHomeMangas({
  int limit = 20,
  int offset = 0,
  String? query,
}) async {
  try {
    final cleanQuery = query?.trim();
    final params = <String, dynamic>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'includes[]': 'cover_art',
      'contentRating[]': ['safe', 'suggestive', 'erotica'],
    };

    if (cleanQuery != null && cleanQuery.isNotEmpty) {
      params['title'] = cleanQuery;
      params['order[relevance]'] = 'desc';
    } else {
      params['order[latestUploadedChapter]'] = 'desc';
    }

    final response = await http.get(
      Uri.https('api.mangadex.org', '/manga', params),
    );

    if (response.statusCode != 200) {
      return const <MangaDexMangaPreview>[];
    }

    final decoded = jsonDecode(response.body);
    return parseMangaDexMangaPreviews(decoded);
  } catch (_) {
    return const <MangaDexMangaPreview>[];
  }
}

List<MangaDexMangaPreview> parseMangaDexMangaPreviews(Object? payload) {
  if (payload is! Map<String, Object?>) {
    return const <MangaDexMangaPreview>[];
  }

  final data = payload['data'];

  if (data is! List) {
    return const <MangaDexMangaPreview>[];
  }

  final previews = <MangaDexMangaPreview>[];

  for (final item in data.whereType<Map>()) {
    final id = _cleanString(item['id']);
    final attributes = item['attributes'];
    final relationships = item['relationships'];

    if (id == null || attributes is! Map) {
      continue;
    }

    final title = _bestLocalizedTitle(attributes['title']) ?? 'Untitled Manga';
    final description = _bestLocalizedTitle(attributes['description']);

    String? coverFileName;
    if (relationships is List) {
      for (final rel in relationships.whereType<Map>()) {
        if (rel['type'] == 'cover_art') {
          final relAttributes = rel['attributes'];
          if (relAttributes is Map) {
            coverFileName = _cleanString(relAttributes['fileName']);
          }
        }
      }
    }

    final thumbnailUrl = coverFileName != null
        ? 'https://uploads.mangadex.org/covers/$id/$coverFileName.256.jpg'
        : null;

    previews.add(
      MangaDexMangaPreview(
        mangaId: id,
        title: title,
        description: description,
        thumbnailUrl: thumbnailUrl,
        sourceLink: 'https://mangadex.org/manga/$id',
      ),
    );
  }

  return List<MangaDexMangaPreview>.unmodifiable(previews);
}

Future<List<MangaDexChapterPreview>> fetchMangaDexMangaChapters(
  String mangaId, {
  int limit = 100,
  int offset = 0,
}) async {
  try {
    final response = await http.get(
      Uri.https('api.mangadex.org', '/manga/$mangaId/feed', {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'translatedLanguage[]': 'en',
        'order[chapter]': 'desc',
      }),
    );

    if (response.statusCode != 200) {
      return const <MangaDexChapterPreview>[];
    }

    final decoded = jsonDecode(response.body);
    return parseMangaDexFeedChapters(decoded, mangaId, 'MangaDex Chapter');
  } catch (_) {
    return const <MangaDexChapterPreview>[];
  }
}

List<MangaDexChapterPreview> parseMangaDexFeedChapters(
  Object? payload,
  String mangaId,
  String mangaTitle,
) {
  if (payload is! Map<String, Object?>) {
    return const <MangaDexChapterPreview>[];
  }

  final data = payload['data'];

  if (data is! List) {
    return const <MangaDexChapterPreview>[];
  }

  final previews = <MangaDexChapterPreview>[];

  for (final item in data.whereType<Map>()) {
    final id = _cleanString(item['id']);
    final attributes = item['attributes'];

    if (id == null || attributes is! Map) {
      continue;
    }

    previews.add(
      MangaDexChapterPreview(
        chapterId: id,
        sourceLink: 'https://mangadex.org/chapter/$id',
        title: mangaTitle,
        chapterLabel: _mangaDexChapterLabel(attributes),
        mangaId: mangaId,
        pageCount: attributes['pages'] is int
            ? attributes['pages'] as int
            : null,
        language: _cleanString(attributes['translatedLanguage']),
      ),
    );
  }

  return List<MangaDexChapterPreview>.unmodifiable(previews);
}

List<MangaDexChapterPreview> parseMangaDexChapterPreviews(Object? payload) {
  if (payload is! Map<String, Object?>) {
    return const <MangaDexChapterPreview>[];
  }

  final data = payload['data'];

  if (data is! List) {
    return const <MangaDexChapterPreview>[];
  }

  final previews = <MangaDexChapterPreview>[];

  for (final item in data.whereType<Map>()) {
    final id = _cleanString(item['id']);
    final attributes = item['attributes'];
    final relationships = item['relationships'];

    if (id == null || attributes is! Map) {
      continue;
    }

    previews.add(
      MangaDexChapterPreview(
        chapterId: id,
        sourceLink: 'https://mangadex.org/chapter/$id',
        title: _mangaDexMangaTitle(relationships) ?? 'MangaDex Chapter',
        chapterLabel: _mangaDexChapterLabel(attributes),
        mangaId: _mangaDexRelationshipId(relationships, 'manga'),
        pageCount: attributes['pages'] is int
            ? attributes['pages'] as int
            : null,
        language: _cleanString(attributes['translatedLanguage']),
      ),
    );
  }

  return List<MangaDexChapterPreview>.unmodifiable(previews);
}

Future<Map<String, String>> fetchMangaDexCoverUrls(
  List<String> mangaIds,
) async {
  if (mangaIds.isEmpty) {
    return const <String, String>{};
  }

  try {
    final response = await http.get(
      Uri.https('api.mangadex.org', '/cover', {
        'limit': '100',
        'manga[]': mangaIds,
        'order[createdAt]': 'desc',
      }),
    );

    if (response.statusCode != 200) {
      return const <String, String>{};
    }

    return parseMangaDexCoverUrls(jsonDecode(response.body));
  } catch (_) {
    return const <String, String>{};
  }
}

Map<String, String> parseMangaDexCoverUrls(Object? payload) {
  if (payload is! Map<String, Object?>) {
    return const <String, String>{};
  }

  final data = payload['data'];

  if (data is! List) {
    return const <String, String>{};
  }

  final coverUrls = <String, String>{};

  for (final item in data.whereType<Map>()) {
    final attributes = item['attributes'];
    final relationships = item['relationships'];

    if (attributes is! Map) {
      continue;
    }

    final fileName = _cleanString(attributes['fileName']);
    final mangaId = _mangaDexRelationshipId(relationships, 'manga');

    if (fileName == null || mangaId == null || coverUrls.containsKey(mangaId)) {
      continue;
    }

    coverUrls[mangaId] =
        'https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg';
  }

  return Map<String, String>.unmodifiable(coverUrls);
}

Future<List<DriveImage>> fetchMangaDexChapterImages(String chapterId) async {
  final response = await http.get(
    Uri.https('api.mangadex.org', '/at-home/server/$chapterId'),
  );

  if (response.statusCode != 200) {
    return [];
  }

  final data = jsonDecode(response.body);

  if (data is! Map<String, Object?>) {
    return [];
  }

  final baseUrl = data['baseUrl'];
  final chapter = data['chapter'];

  if (baseUrl is! String || chapter is! Map<String, Object?>) {
    return [];
  }

  final hash = chapter['hash'];
  final pages = chapter['data'];

  if (hash is! String || pages is! List) {
    return [];
  }

  return pages
      .whereType<String>()
      .map<DriveImage>((pageFileName) {
        final pageUrl = '$baseUrl/data/$hash/$pageFileName';

        return DriveImage(thumbnailUrl: pageUrl, fullUrl: pageUrl);
      })
      .toList(growable: false);
}

Future<StoryMetadata> fetchMangaDexChapterMetadata(String chapterId) async {
  const fallback = StoryMetadata(
    sourceType: StorySourceType.mangaDexChapter,
    title: 'MangaDex Chapter',
  );

  try {
    final response = await http.get(
      Uri.https('api.mangadex.org', '/chapter/$chapterId', {
        'includes[]': 'manga',
      }),
    );

    if (response.statusCode != 200) {
      return fallback;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, Object?>) {
      return fallback;
    }

    final data = decoded['data'];

    if (data is! Map<String, Object?>) {
      return fallback;
    }

    final attributes = data['attributes'];
    final relationships = data['relationships'];
    final mangaTitle = _mangaDexMangaTitle(relationships);
    final chapterLabel = _mangaDexChapterLabel(attributes);

    return StoryMetadata(
      sourceType: StorySourceType.mangaDexChapter,
      title: mangaTitle ?? fallback.title,
      chapterLabel: chapterLabel,
    );
  } catch (_) {
    return fallback;
  }
}

String? _mangaDexMangaTitle(Object? relationships) {
  if (relationships is! List) {
    return null;
  }

  for (final relationship in relationships.whereType<Map>()) {
    if (relationship['type'] != 'manga') {
      continue;
    }

    final attributes = relationship['attributes'];

    if (attributes is! Map) {
      continue;
    }

    return _bestLocalizedTitle(attributes['title']);
  }

  return null;
}

String? _mangaDexRelationshipId(Object? relationships, String type) {
  if (relationships is! List) {
    return null;
  }

  for (final relationship in relationships.whereType<Map>()) {
    if (relationship['type'] != type) {
      continue;
    }

    return _cleanString(relationship['id']);
  }

  return null;
}

String? _mangaDexChapterLabel(Object? attributes) {
  if (attributes is! Map) {
    return null;
  }

  final chapterNumber = _cleanString(attributes['chapter']);
  final chapterTitle = _cleanString(attributes['title']);
  final parts = <String>[];

  if (chapterNumber != null) {
    parts.add('Chapter $chapterNumber');
  }

  if (chapterTitle != null) {
    parts.add(chapterTitle);
  }

  if (parts.isEmpty) {
    return null;
  }

  return parts.join(' - ');
}

String? _bestLocalizedTitle(Object? titleValue) {
  if (titleValue is String) {
    return _cleanString(titleValue);
  }

  if (titleValue is! Map) {
    return null;
  }

  for (final key in const ['en', 'ja-ro', 'ja', 'vi']) {
    final title = _cleanString(titleValue[key]);

    if (title != null) {
      return title;
    }
  }

  for (final value in titleValue.values) {
    final title = _cleanString(value);

    if (title != null) {
      return title;
    }
  }

  return null;
}

String? _cleanString(Object? value) {
  if (value is! String) {
    return null;
  }

  final text = value.trim();

  if (text.isEmpty) {
    return null;
  }

  return text;
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
