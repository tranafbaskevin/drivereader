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

enum StorySourceStatus { ready, planned }

enum StorySourceType {
  driveFolder,
  mangaDexChapter,
  nHentaiGallery,
  hitomiGallery,
  singlePage,
}

class StorySourceDefinition {
  final StorySourceType type;
  final String label;
  final String hintText;
  final IconData icon;
  final StorySourceStatus status;
  final bool privateSource;

  const StorySourceDefinition({
    required this.type,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.status,
    this.privateSource = false,
  });

  bool get isReady => status == StorySourceStatus.ready;
}

const List<StorySourceDefinition> storySourceDefinitions = [
  StorySourceDefinition(
    type: StorySourceType.driveFolder,
    label: 'Google Drive',
    hintText: 'Paste Google Drive folder or image link',
    icon: Icons.cloud_queue_rounded,
    status: StorySourceStatus.ready,
  ),
  StorySourceDefinition(
    type: StorySourceType.mangaDexChapter,
    label: 'MangaDex',
    hintText: 'Paste MangaDex chapter link',
    icon: Icons.public_rounded,
    status: StorySourceStatus.ready,
  ),
  StorySourceDefinition(
    type: StorySourceType.nHentaiGallery,
    label: 'NHentai',
    hintText: 'Paste NHentai gallery link',
    icon: Icons.lock_outline_rounded,
    status: StorySourceStatus.ready,
    privateSource: true,
  ),
  StorySourceDefinition(
    type: StorySourceType.hitomiGallery,
    label: 'Hitomi',
    hintText: 'Paste Hitomi gallery link',
    icon: Icons.lock_outline_rounded,
    status: StorySourceStatus.ready,
    privateSource: true,
  ),
];

StorySourceDefinition sourceDefinitionFor(StorySourceType sourceType) {
  return storySourceDefinitions.firstWhere(
    (definition) => definition.type == sourceType,
    orElse: () => storySourceDefinitions.first,
  );
}

List<StorySourceDefinition> get readyStorySources {
  return storySourceDefinitions
      .where((definition) => definition.isReady)
      .toList(growable: false);
}

List<StorySourceDefinition> get publicReadyStorySources {
  return readyStorySources
      .where((definition) => !definition.privateSource)
      .toList(growable: false);
}

List<StorySourceDefinition> get privateStorySources {
  return storySourceDefinitions
      .where((definition) => definition.privateSource)
      .toList(growable: false);
}

List<StorySourceDefinition> get plannedStorySources {
  return storySourceDefinitions
      .where((definition) => !definition.isReady)
      .toList(growable: false);
}

bool isPrivateSourceType(StorySourceType sourceType) {
  return sourceDefinitionFor(sourceType).privateSource;
}

class StoryMetadata {
  final StorySourceType sourceType;
  final String title;
  final String? chapterLabel;

  const StoryMetadata({
    required this.sourceType,
    required this.title,
    this.chapterLabel,
  });

  String get sourceLabel {
    switch (sourceType) {
      case StorySourceType.driveFolder:
        return 'Google Drive';
      case StorySourceType.mangaDexChapter:
        return 'MangaDex';
      case StorySourceType.nHentaiGallery:
        return 'NHentai';
      case StorySourceType.hitomiGallery:
        return 'Hitomi';
      case StorySourceType.singlePage:
        return 'Single Page';
    }
  }

  Map<String, Object?> toJson() {
    return {
      'sourceType': sourceType.name,
      'title': title,
      'chapterLabel': chapterLabel,
    };
  }

  static StoryMetadata? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final sourceTypeName = value['sourceType'];
    final title = value['title'];
    final chapterLabel = value['chapterLabel'];

    if (sourceTypeName is! String ||
        title is! String ||
        (chapterLabel != null && chapterLabel is! String)) {
      return null;
    }

    StorySourceType? sourceType;
    for (final type in StorySourceType.values) {
      if (type.name == sourceTypeName) {
        sourceType = type;
        break;
      }
    }

    if (sourceType == null) {
      return null;
    }

    return StoryMetadata(
      sourceType: sourceType,
      title: title,
      chapterLabel: chapterLabel as String?,
    );
  }
}

class PrivateSourceSettings {
  final bool enabled;
  final int? acceptedAtMs;
  final bool blurPrivateThumbnails;

  const PrivateSourceSettings({
    required this.enabled,
    this.acceptedAtMs,
    this.blurPrivateThumbnails = true,
  });

  bool get isAccepted => enabled && acceptedAtMs != null;

  PrivateSourceSettings copyWith({
    bool? enabled,
    int? acceptedAtMs,
    bool? blurPrivateThumbnails,
  }) {
    return PrivateSourceSettings(
      enabled: enabled ?? this.enabled,
      acceptedAtMs: acceptedAtMs ?? this.acceptedAtMs,
      blurPrivateThumbnails:
          blurPrivateThumbnails ?? this.blurPrivateThumbnails,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'acceptedAtMs': acceptedAtMs,
      'blurPrivateThumbnails': blurPrivateThumbnails,
    };
  }

  static PrivateSourceSettings? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final enabled = value['enabled'];
    final acceptedAtMs = value['acceptedAtMs'];
    final blurPrivateThumbnails = value['blurPrivateThumbnails'];

    if (enabled is! bool ||
        (acceptedAtMs != null && acceptedAtMs is! int) ||
        (blurPrivateThumbnails != null && blurPrivateThumbnails is! bool)) {
      return null;
    }

    return PrivateSourceSettings(
      enabled: enabled,
      acceptedAtMs: acceptedAtMs as int?,
      blurPrivateThumbnails: blurPrivateThumbnails as bool? ?? true,
    );
  }
}

Color _backgroundOverlay(double opacity) {
  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  return _appBackground.withAlpha(alpha);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KevDexMemory.load();
  runApp(const DriveReaderApp());
}

class DriveImage {
  final String thumbnailUrl;
  final String fullUrl;

  const DriveImage({required this.thumbnailUrl, required this.fullUrl});

  Map<String, String> toJson() {
    return {'thumbnailUrl': thumbnailUrl, 'fullUrl': fullUrl};
  }

  static DriveImage? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final thumbnailUrl = value['thumbnailUrl'];
    final fullUrl = value['fullUrl'];

    if (thumbnailUrl is! String || fullUrl is! String) {
      return null;
    }

    return DriveImage(
      thumbnailUrl: _normalizeReaderImageUrl(thumbnailUrl),
      fullUrl: _normalizeReaderImageUrl(fullUrl),
    );
  }
}

String _normalizeReaderImageUrl(String url) {
  final uri = Uri.tryParse(url);

  if (uri == null) {
    return url;
  }

  if (uri.host.toLowerCase() == 'a.hitomi.la' ||
      uri.host.toLowerCase() == _hitomiImageHost) {
    final hash = RegExp(
      r'([0-9a-f]{8,})',
      caseSensitive: false,
    ).firstMatch(uri.path)?.group(1);

    if (hash != null) {
      return _hitomiWebpImageUrl(hash, _fallbackHitomiRouting);
    }
  }

  return url;
}

class StoryFetchResult {
  final List<DriveImage> images;
  final StoryMetadata metadata;
  final String? errorMessage;

  const StoryFetchResult({
    required this.images,
    required this.metadata,
    this.errorMessage,
  });
}

class HitomiGalleryPreview {
  final String galleryId;
  final String title;
  final String sourceLink;
  final String thumbnailUrl;
  final int pageCount;
  final String? language;

  const HitomiGalleryPreview({
    required this.galleryId,
    required this.title,
    required this.sourceLink,
    required this.thumbnailUrl,
    required this.pageCount,
    this.language,
  });
}

class MangaDexChapterPreview {
  final String chapterId;
  final String sourceLink;
  final String title;
  final String? chapterLabel;
  final String? mangaId;
  final String? thumbnailUrl;
  final int? pageCount;
  final String? language;

  const MangaDexChapterPreview({
    required this.chapterId,
    required this.sourceLink,
    required this.title,
    this.chapterLabel,
    this.mangaId,
    this.thumbnailUrl,
    this.pageCount,
    this.language,
  });

  MangaDexChapterPreview copyWith({String? thumbnailUrl}) {
    return MangaDexChapterPreview(
      chapterId: chapterId,
      sourceLink: sourceLink,
      title: title,
      chapterLabel: chapterLabel,
      mangaId: mangaId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pageCount: pageCount,
      language: language,
    );
  }

  StoryMetadata get metadata {
    return StoryMetadata(
      sourceType: StorySourceType.mangaDexChapter,
      title: title,
      chapterLabel: chapterLabel,
    );
  }
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

enum ReaderFitMode {
  fitWidth(
    label: 'Width',
    icon: Icons.fit_screen_rounded,
    fit: BoxFit.fitWidth,
  ),
  fullPage(label: 'Page', icon: Icons.crop_free_rounded, fit: BoxFit.contain);

  final String label;
  final IconData icon;
  final BoxFit fit;

  const ReaderFitMode({
    required this.label,
    required this.icon,
    required this.fit,
  });
}

class ReaderComfortSettings {
  final ReaderFitMode fitMode;
  final double shade;

  const ReaderComfortSettings({required this.fitMode, required this.shade});

  ReaderComfortSettings copyWith({ReaderFitMode? fitMode, double? shade}) {
    return ReaderComfortSettings(
      fitMode: fitMode ?? this.fitMode,
      shade: shade ?? this.shade,
    );
  }

  Map<String, Object?> toJson() {
    return {'fitMode': fitMode.name, 'shade': shade};
  }

  static ReaderComfortSettings? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final fitModeName = value['fitMode'];
    final shadeValue = value['shade'];

    if (fitModeName is! String || shadeValue is! num) {
      return null;
    }

    ReaderFitMode? fitMode;
    for (final mode in ReaderFitMode.values) {
      if (mode.name == fitModeName) {
        fitMode = mode;
        break;
      }
    }

    if (fitMode == null) {
      return null;
    }

    return ReaderComfortSettings(
      fitMode: fitMode,
      shade: shadeValue.toDouble().clamp(0.0, 0.55),
    );
  }
}

const ReaderComfortSettings defaultReaderComfortSettings =
    ReaderComfortSettings(fitMode: ReaderFitMode.fitWidth, shade: 0);
const PrivateSourceSettings defaultPrivateSourceSettings =
    PrivateSourceSettings(enabled: false);
const int _maxLibraryItems = 10;

final ValueNotifier<ReadingProgress?> readingProgressNotifier =
    ValueNotifier<ReadingProgress?>(null);

final ValueNotifier<List<LibraryItem>> libraryNotifier =
    ValueNotifier<List<LibraryItem>>(const <LibraryItem>[]);

final ValueNotifier<UiBackground> uiBackgroundNotifier =
    ValueNotifier<UiBackground>(defaultUiBackground);

final ValueNotifier<ReaderComfortSettings> readerComfortNotifier =
    ValueNotifier<ReaderComfortSettings>(defaultReaderComfortSettings);

final ValueNotifier<PrivateSourceSettings> privateSourceSettingsNotifier =
    ValueNotifier<PrivateSourceSettings>(defaultPrivateSourceSettings);

class KevDexMemory {
  static const String _lastLinkKey = 'kevdex.lastLink';
  static const String _lastDriveLinkKey = 'kevdex.lastDriveLink';
  static const String _lastMangaDexLinkKey = 'kevdex.lastMangaDexLink';
  static const String _lastNHentaiLinkKey = 'kevdex.lastNHentaiLink';
  static const String _lastHitomiLinkKey = 'kevdex.lastHitomiLink';
  static const String _readerProgressKey = 'kevdex.readerProgress';
  static const String _libraryKey = 'kevdex.library';
  static const String _uiBackgroundKey = 'kevdex.uiBackground';
  static const String _readerComfortKey = 'kevdex.readerComfort';
  static const String _privateSourceSettingsKey =
      'kevdex.privateSourceSettings';
  static const String _customBackgroundFileName = 'kevdex_custom_background';

  static SharedPreferences? _preferences;
  static String? lastLink;
  static String? lastDriveLink;
  static String? lastMangaDexLink;
  static String? lastNHentaiLink;
  static String? lastHitomiLink;

  const KevDexMemory._();

  static Future<void> load() async {
    final preferences = await _loadPreferences();
    lastLink = preferences.getString(_lastLinkKey);
    lastDriveLink = preferences.getString(_lastDriveLinkKey);
    lastMangaDexLink = preferences.getString(_lastMangaDexLinkKey);
    lastNHentaiLink = preferences.getString(_lastNHentaiLinkKey);
    lastHitomiLink = preferences.getString(_lastHitomiLinkKey);
    _restoreReadingProgress(preferences);
    _restoreLibrary(preferences);
    _restoreUiBackground(preferences);
    _restoreReaderComfort(preferences);
    _restorePrivateSourceSettings(preferences);
  }

  static Future<void> saveLastLink(String link) async {
    final cleanedLink = link.trim();
    final preferences = await _loadPreferences();

    if (cleanedLink.isEmpty) {
      await preferences.remove(_lastLinkKey);
      lastLink = null;
      return;
    }

    lastLink = cleanedLink;
    await preferences.setString(_lastLinkKey, cleanedLink);
  }

  static Future<void> saveLastDriveLink(String link) async {
    final cleanedLink = link.trim();
    final preferences = await _loadPreferences();

    if (cleanedLink.isEmpty) {
      await preferences.remove(_lastDriveLinkKey);
      lastDriveLink = null;
      return;
    }

    lastDriveLink = cleanedLink;
    await preferences.setString(_lastDriveLinkKey, cleanedLink);
  }

  static Future<void> saveLastMangaDexLink(String link) async {
    final cleanedLink = link.trim();
    final preferences = await _loadPreferences();

    if (cleanedLink.isEmpty) {
      await preferences.remove(_lastMangaDexLinkKey);
      lastMangaDexLink = null;
      return;
    }

    lastMangaDexLink = cleanedLink;
    await preferences.setString(_lastMangaDexLinkKey, cleanedLink);
  }

  static Future<void> saveLastNHentaiLink(String link) async {
    final cleanedLink = link.trim();
    final preferences = await _loadPreferences();

    if (cleanedLink.isEmpty) {
      await preferences.remove(_lastNHentaiLinkKey);
      lastNHentaiLink = null;
      return;
    }

    lastNHentaiLink = cleanedLink;
    await preferences.setString(_lastNHentaiLinkKey, cleanedLink);
  }

  static Future<void> saveLastHitomiLink(String link) async {
    final cleanedLink = link.trim();
    final preferences = await _loadPreferences();

    if (cleanedLink.isEmpty) {
      await preferences.remove(_lastHitomiLinkKey);
      lastHitomiLink = null;
      return;
    }

    lastHitomiLink = cleanedLink;
    await preferences.setString(_lastHitomiLinkKey, cleanedLink);
  }

  static Future<void> saveReadingProgress(ReadingProgress progress) async {
    final preferences = await _loadPreferences();
    await preferences.setString(_readerProgressKey, jsonEncode(progress));
    await upsertLibraryItem(LibraryItem.fromProgress(progress));
  }

  static Future<void> upsertLibraryItem(LibraryItem item) async {
    final preferences = await _loadPreferences();
    final nextItems = <LibraryItem>[
      item,
      ...libraryNotifier.value.where(
        (currentItem) => currentItem.sourceLink != item.sourceLink,
      ),
    ];

    libraryNotifier.value = List<LibraryItem>.unmodifiable(
      nextItems.take(_maxLibraryItems).toList(growable: false),
    );
    await preferences.setString(_libraryKey, jsonEncode(libraryNotifier.value));
  }

  static Future<void> removeLibraryItem(String sourceLink) async {
    final preferences = await _loadPreferences();
    libraryNotifier.value = List<LibraryItem>.unmodifiable(
      libraryNotifier.value
          .where((item) => item.sourceLink != sourceLink)
          .toList(growable: false),
    );
    await preferences.setString(_libraryKey, jsonEncode(libraryNotifier.value));
  }

  static Future<void> saveUiBackground(UiBackground background) async {
    final preferences = await _loadPreferences();
    await preferences.setString(_uiBackgroundKey, jsonEncode(background));
  }

  static Future<void> saveReaderComfort(ReaderComfortSettings settings) async {
    final preferences = await _loadPreferences();
    await preferences.setString(_readerComfortKey, jsonEncode(settings));
  }

  static Future<void> savePrivateSourceSettings(
    PrivateSourceSettings settings,
  ) async {
    final preferences = await _loadPreferences();
    privateSourceSettingsNotifier.value = settings;

    if (!settings.enabled) {
      await preferences.remove(_privateSourceSettingsKey);
      return;
    }

    await preferences.setString(
      _privateSourceSettingsKey,
      jsonEncode(settings),
    );
  }

  static Future<void> clearPrivateHistory() async {
    final preferences = await _loadPreferences();
    final cachedUrls = _cachedImageUrls(privateOnly: true);
    final progress = readingProgressNotifier.value;

    if (progress != null && progress.isPrivateSource) {
      readingProgressNotifier.value = null;
      await preferences.remove(_readerProgressKey);
    }

    final publicItems = libraryNotifier.value
        .where((item) => !item.isPrivateSource)
        .toList(growable: false);

    libraryNotifier.value = List<LibraryItem>.unmodifiable(publicItems);
    await preferences.setString(_libraryKey, jsonEncode(libraryNotifier.value));

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await _evictCachedImages(cachedUrls);
  }

  static Future<void> clearAppCache() async {
    final preferences = await _loadPreferences();
    final cachedUrls = _cachedImageUrls();

    await Future.wait([
      preferences.remove(_lastLinkKey),
      preferences.remove(_lastDriveLinkKey),
      preferences.remove(_lastMangaDexLinkKey),
      preferences.remove(_lastNHentaiLinkKey),
      preferences.remove(_lastHitomiLinkKey),
      preferences.remove(_readerProgressKey),
      preferences.remove(_libraryKey),
      preferences.remove(_uiBackgroundKey),
      preferences.remove(_readerComfortKey),
      preferences.remove(_privateSourceSettingsKey),
    ]);

    lastLink = null;
    lastDriveLink = null;
    lastMangaDexLink = null;
    lastNHentaiLink = null;
    lastHitomiLink = null;
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;
    privateSourceSettingsNotifier.value = defaultPrivateSourceSettings;

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    await _evictCachedImages(cachedUrls);
    await _deleteCustomBackgrounds();
  }

  static Future<UiBackground> saveCustomUiBackground(XFile image) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final backgroundDirectory = Directory(
      '${appDirectory.path}${Platform.pathSeparator}kevdex_backgrounds',
    );
    await backgroundDirectory.create(recursive: true);

    final extension = _fileExtension(image.name).isEmpty
        ? _fileExtension(image.path)
        : _fileExtension(image.name);
    final targetPath =
        '${backgroundDirectory.path}${Platform.pathSeparator}'
        '$_customBackgroundFileName${extension.isEmpty ? '.jpg' : extension}';
    final copiedImage = await File(image.path).copy(targetPath);
    final background = UiBackground.file(
      title: 'My Image',
      path: copiedImage.path,
    );

    await saveUiBackground(background);
    return background;
  }

  static Set<String> _cachedImageUrls({bool privateOnly = false}) {
    final urls = <String>{};

    void addImage(DriveImage image) {
      urls.add(image.thumbnailUrl);
      urls.add(image.fullUrl);
    }

    void addProgress(ReadingProgress progress) {
      for (final image in progress.images) {
        addImage(image);
      }

      final thumbnailUrl = progress.thumbnailUrl;
      if (thumbnailUrl != null) {
        urls.add(thumbnailUrl);
      }
    }

    final progress = readingProgressNotifier.value;
    if (progress != null && (!privateOnly || progress.isPrivateSource)) {
      addProgress(progress);
    }

    for (final item in libraryNotifier.value) {
      if (privateOnly && !item.isPrivateSource) {
        continue;
      }

      for (final image in item.images) {
        addImage(image);
      }

      final thumbnailUrl = item.thumbnailUrl;
      if (thumbnailUrl != null) {
        urls.add(thumbnailUrl);
      }
    }

    urls.removeWhere((url) => url.trim().isEmpty);
    return urls;
  }

  static Future<void> _evictCachedImages(Set<String> urls) async {
    await Future.wait(
      urls.map((url) async {
        try {
          await CachedNetworkImage.evictFromCache(url);
        } catch (_) {}
      }),
    );
  }

  static Future<void> _deleteCustomBackgrounds() async {
    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final backgroundDirectory = Directory(
        '${appDirectory.path}${Platform.pathSeparator}kevdex_backgrounds',
      );

      if (await backgroundDirectory.exists()) {
        await backgroundDirectory.delete(recursive: true);
      }
    } catch (_) {}
  }

  static Future<SharedPreferences> _loadPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  static void _restoreReadingProgress(SharedPreferences preferences) {
    final rawProgress = preferences.getString(_readerProgressKey);

    if (rawProgress == null) {
      return;
    }

    try {
      final progress = ReadingProgress.fromJson(jsonDecode(rawProgress));

      if (progress != null) {
        readingProgressNotifier.value = progress;
      }
    } on FormatException {
      preferences.remove(_readerProgressKey);
    }
  }

  static void _restoreLibrary(SharedPreferences preferences) {
    final rawLibrary = preferences.getString(_libraryKey);

    if (rawLibrary == null) {
      return;
    }

    try {
      final decodedLibrary = jsonDecode(rawLibrary);

      if (decodedLibrary is! List) {
        return;
      }

      final items = decodedLibrary
          .map(LibraryItem.fromJson)
          .whereType<LibraryItem>()
          .toList(growable: false);

      if (items.isNotEmpty) {
        libraryNotifier.value = List<LibraryItem>.unmodifiable(items);
      }
    } on FormatException {
      preferences.remove(_libraryKey);
    }
  }

  static void _restoreUiBackground(SharedPreferences preferences) {
    final rawBackground = preferences.getString(_uiBackgroundKey);

    if (rawBackground == null) {
      return;
    }

    try {
      final background = UiBackground.fromJson(jsonDecode(rawBackground));

      if (background == null) {
        return;
      }

      if (!background.isAsset && !File(background.path).existsSync()) {
        return;
      }

      uiBackgroundNotifier.value = background;
    } on FormatException {
      preferences.remove(_uiBackgroundKey);
    }
  }

  static void _restoreReaderComfort(SharedPreferences preferences) {
    final rawSettings = preferences.getString(_readerComfortKey);

    if (rawSettings == null) {
      return;
    }

    try {
      final settings = ReaderComfortSettings.fromJson(jsonDecode(rawSettings));

      if (settings != null) {
        readerComfortNotifier.value = settings;
      }
    } on FormatException {
      preferences.remove(_readerComfortKey);
    }
  }

  static void _restorePrivateSourceSettings(SharedPreferences preferences) {
    final rawSettings = preferences.getString(_privateSourceSettingsKey);

    if (rawSettings == null) {
      return;
    }

    try {
      final settings = PrivateSourceSettings.fromJson(jsonDecode(rawSettings));

      if (settings != null) {
        privateSourceSettingsNotifier.value = settings;
      }
    } on FormatException {
      preferences.remove(_privateSourceSettingsKey);
    }
  }

  static String _fileExtension(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    final fileName = normalizedPath.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex).toLowerCase();
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
  StorySourceType selectedSourceType = StorySourceType.driveFolder;
  bool isOpening = false;

  @override
  void initState() {
    super.initState();
    final savedDriveLink = KevDexMemory.lastDriveLink;
    final savedMangaDexLink = KevDexMemory.lastMangaDexLink;
    final savedNHentaiLink = KevDexMemory.lastNHentaiLink;
    final savedHitomiLink = KevDexMemory.lastHitomiLink;
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
  }

  @override
  void dispose() {
    driveLinkController.dispose();
    mangaDexLinkController.dispose();
    nHentaiLinkController.dispose();
    hitomiLinkController.dispose();
    super.dispose();
  }

  TextEditingController _controllerForSource(StorySourceType sourceType) {
    return switch (sourceType) {
      StorySourceType.mangaDexChapter => mangaDexLinkController,
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

    if (requestedSourceType == StorySourceType.mangaDexChapter &&
        mangaDexChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a MangaDex chapter link.')),
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
                      isOpening: isOpening,
                      onSelectSource: _selectSource,
                      onShowSourceHub: _showSourceHub,
                      onOpenMangaDexHome: _openMangaDexHome,
                      onOpenHitomiHome: _openHitomiHome,
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

    final background = await KevDexMemory.saveCustomUiBackground(image);

    if (!context.mounted) {
      return;
    }

    uiBackgroundNotifier.value = background;
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
                  unawaited(KevDexMemory.saveUiBackground(defaultUiBackground));
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
              unawaited(KevDexMemory.saveUiBackground(background));
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
          'Google Drive / MangaDex Reader',
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

class _SourceHubPanel extends StatelessWidget {
  final StorySourceType selectedSourceType;
  final TextEditingController driveController;
  final TextEditingController mangaDexController;
  final TextEditingController nHentaiController;
  final TextEditingController hitomiController;
  final bool isOpening;
  final ValueChanged<StorySourceType> onSelectSource;
  final VoidCallback onShowSourceHub;
  final VoidCallback onOpenMangaDexHome;
  final VoidCallback onOpenHitomiHome;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  const _SourceHubPanel({
    required this.selectedSourceType,
    required this.driveController,
    required this.mangaDexController,
    required this.nHentaiController,
    required this.hitomiController,
    required this.isOpening,
    required this.onSelectSource,
    required this.onShowSourceHub,
    required this.onOpenMangaDexHome,
    required this.onOpenHitomiHome,
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
      StorySourceType.nHentaiGallery => nHentaiController,
      StorySourceType.hitomiGallery => hitomiController,
      StorySourceType.driveFolder ||
      StorySourceType.singlePage => driveController,
    };
  }
}

class _SourceFilterChip extends StatelessWidget {
  final StorySourceDefinition definition;
  final bool selected;
  final bool isOpening;
  final ValueChanged<StorySourceType> onSelectSource;

  const _SourceFilterChip({
    required this.definition,
    required this.selected,
    required this.isOpening,
    required this.onSelectSource,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(definition.label),
      avatar: Icon(definition.icon, size: 17),
      onSelected: isOpening ? null : (_) => onSelectSource(definition.type),
      backgroundColor: _fieldColor,
      selectedColor: _primaryAccent,
      checkmarkColor: const Color(0xFF101016),
      side: const BorderSide(color: Color(0xFF393745)),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF101016) : _mutedText,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
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

class _SourceHubSectionTitle extends StatelessWidget {
  final String label;

  const _SourceHubSectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _mutedText,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PrivateSourceGateCard extends StatelessWidget {
  final PrivateSourceSettings settings;
  final ValueChanged<bool> onChanged;
  final VoidCallback onClearPrivateHistory;
  final ValueChanged<bool> onBlurChanged;

  const _PrivateSourceGateCard({
    required this.settings,
    required this.onChanged,
    required this.onClearPrivateHistory,
    required this.onBlurChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAccepted = settings.isAccepted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171720),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAccepted ? _primaryAccent : const Color(0xFF393745),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isAccepted
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: isAccepted ? _primaryAccent : _mutedText,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Private Sources',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Tooltip(
                message: 'Toggle private sources',
                child: Switch(
                  value: isAccepted,
                  activeThumbColor: _primaryAccent,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAccepted
                ? 'Private adapters are visible in Source Hub.'
                : 'Private adapters stay hidden until you choose to show them.',
            style: const TextStyle(
              color: _mutedText,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isAccepted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _fieldColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF393745)),
              ),
              child: Row(
                children: [
                  Icon(
                    settings.blurPrivateThumbnails
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _primaryAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Blur Private Thumbnails',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Toggle thumbnail blur',
                    child: Switch(
                      value: settings.blurPrivateThumbnails,
                      activeThumbColor: _primaryAccent,
                      onChanged: onBlurChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: 'Clear private history',
              child: OutlinedButton.icon(
                onPressed: onClearPrivateHistory,
                icon: const Icon(Icons.hide_image_rounded),
                label: const Text('Clear Private History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _secondaryAccent,
                  side: const BorderSide(color: Color(0xFF7A5A34)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceHubTile extends StatelessWidget {
  final StorySourceDefinition definition;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SourceHubTile({
    required this.definition,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = enabled ? Colors.white : _mutedText;
    final statusLabel = selected
        ? 'Selected'
        : definition.isReady
        ? 'Ready'
        : definition.privateSource
        ? 'Staged'
        : 'Soon';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF25342E) : _fieldColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _primaryAccent : const Color(0xFF393745),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: enabled ? _surfaceColor : const Color(0xFF17171F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  definition.icon,
                  color: enabled ? _primaryAccent : const Color(0xFF6F6D7B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  definition.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? _primaryAccent : const Color(0xFF252431),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: selected ? const Color(0xFF101016) : _mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _SourceLinkField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final bool isOpening;
  final String openTooltip;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  const _SourceLinkField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    required this.isOpening,
    required this.openTooltip,
    required this.onOpen,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: _primaryAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: SizedBox(
                width: 104,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: isOpening ? null : onClear,
                    ),
                    IconButton(
                      tooltip: openTooltip,
                      icon: isOpening
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _primaryAccent,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      color: _primaryAccent,
                      onPressed: isOpening ? null : onOpen,
                    ),
                  ],
                ),
              ),
            ),
            onSubmitted: (_) {
              if (!isOpening) {
                onOpen();
              }
            },
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
  final Future<List<MangaDexChapterPreview>> Function()? chapterLoader;

  const MangaDexHomePage({super.key, this.chapterLoader});

  @override
  State<MangaDexHomePage> createState() => _MangaDexHomePageState();
}

class _MangaDexHomePageState extends State<MangaDexHomePage> {
  late Future<List<MangaDexChapterPreview>> chaptersFuture;
  String? openingChapterId;

  @override
  void initState() {
    super.initState();
    chaptersFuture = _loadChapters();
  }

  Future<List<MangaDexChapterPreview>> _loadChapters() {
    final loader = widget.chapterLoader;

    if (loader != null) {
      return loader();
    }

    return fetchMangaDexHomeChapters();
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
    StoryMetadata metadata = chapter.metadata;
    String? errorMessage;

    try {
      images = await fetchMangaDexChapterImages(chapter.chapterId);
      metadata = await fetchMangaDexChapterMetadata(chapter.chapterId);
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
                            'Latest Chapters',
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
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<MangaDexChapterPreview>>(
                  future: chaptersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _MangaLoadingState();
                    }

                    if (snapshot.hasError) {
                      return const _ReaderMessageState(
                        icon: Icons.explore_rounded,
                        title: 'MangaDex Home could not load.',
                        message: 'Refresh or check the network.',
                      );
                    }

                    final chapters =
                        snapshot.data ?? const <MangaDexChapterPreview>[];

                    if (chapters.isEmpty) {
                      return const _ReaderMessageState(
                        icon: Icons.explore_rounded,
                        title: 'No MangaDex chapters found.',
                        message: 'Refresh or check the network.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: chapters.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];

                        return _MangaDexChapterCard(
                          chapter: chapter,
                          isOpening: openingChapterId == chapter.chapterId,
                          onOpen: () => _openChapter(chapter),
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

class _MangaDexChapterCard extends StatelessWidget {
  final MangaDexChapterPreview chapter;
  final bool isOpening;
  final VoidCallback onOpen;

  const _MangaDexChapterCard({
    required this.chapter,
    required this.isOpening,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      chapter.chapterLabel ?? 'Chapter',
      if (chapter.pageCount != null) '${chapter.pageCount} pages',
      if (chapter.language != null) chapter.language!,
    ].join(' - ');
    final thumbnailUrl = chapter.thumbnailUrl;

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
                      chapter.title,
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

class HitomiHomePage extends StatefulWidget {
  final Future<List<HitomiGalleryPreview>> Function()? galleryLoader;

  const HitomiHomePage({super.key, this.galleryLoader});

  @override
  State<HitomiHomePage> createState() => _HitomiHomePageState();
}

class _HitomiHomePageState extends State<HitomiHomePage> {
  late Future<List<HitomiGalleryPreview>> galleriesFuture;
  String? openingGalleryId;

  @override
  void initState() {
    super.initState();
    galleriesFuture = _loadGalleries();
  }

  Future<List<HitomiGalleryPreview>> _loadGalleries() {
    final loader = widget.galleryLoader;

    if (loader != null) {
      return loader();
    }

    return fetchHitomiHomeGalleries();
  }

  void _refresh() {
    setState(() {
      galleriesFuture = _loadGalleries();
    });
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
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<HitomiGalleryPreview>>(
                  future: galleriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _MangaLoadingState();
                    }

                    if (snapshot.hasError) {
                      return const _ReaderMessageState(
                        icon: Icons.travel_explore_rounded,
                        title: 'Hitomi Home could not load.',
                        message: 'Refresh or check the network.',
                      );
                    }

                    final galleries =
                        snapshot.data ?? const <HitomiGalleryPreview>[];

                    if (galleries.isEmpty) {
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: galleries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final gallery = galleries[index];

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

class _ReaderProgressHud extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onComfort;
  final VoidCallback? onGallery;

  const _ReaderProgressHud({
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    required this.onBack,
    required this.onComfort,
    this.onGallery,
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
          if (onGallery != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton(
                tooltip: 'Gallery',
                icon: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onGallery,
              ),
            ),
          ],
          const SizedBox(width: 4),
          SizedBox(
            width: 42,
            height: 42,
            child: IconButton(
              tooltip: 'Reader comfort',
              icon: const Icon(
                Icons.tune_rounded,
                color: _primaryAccent,
                size: 21,
              ),
              onPressed: onComfort,
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

bool isDriveFolderLink(String link) {
  return link.contains('/drive/folders/');
}

bool isMangaDexChapterLink(String link) {
  return extractMangaDexChapterId(link) != null;
}

StorySourceType detectStorySource(String link) {
  if (extractNHentaiGalleryId(link) != null) {
    return StorySourceType.nHentaiGallery;
  }

  if (extractHitomiGalleryId(link) != null) {
    return StorySourceType.hitomiGallery;
  }

  if (extractMangaDexChapterId(link) != null) {
    return StorySourceType.mangaDexChapter;
  }

  if (extractDriveFolderId(link) != null) {
    return StorySourceType.driveFolder;
  }

  return StorySourceType.singlePage;
}

bool _matchesRequestedPrivateSource(
  StorySourceType requestedSourceType,
  String link,
) {
  return switch (requestedSourceType) {
    StorySourceType.nHentaiGallery => extractNHentaiGalleryId(link) != null,
    StorySourceType.hitomiGallery => extractHitomiGalleryId(link) != null,
    StorySourceType.driveFolder ||
    StorySourceType.mangaDexChapter ||
    StorySourceType.singlePage => true,
  };
}

bool _sourceNeedsFetchedPages(StorySourceType sourceType) {
  return switch (sourceType) {
    StorySourceType.driveFolder ||
    StorySourceType.mangaDexChapter ||
    StorySourceType.nHentaiGallery ||
    StorySourceType.hitomiGallery => true,
    StorySourceType.singlePage => false,
  };
}

String? extractDriveFolderId(String link) {
  final regExp = RegExp(r'/folders/([^/?]+)');
  final match = regExp.firstMatch(link);

  if (match == null) {
    return null;
  }

  return match.group(1);
}

String? extractMangaDexChapterId(String link) {
  const uuidPattern =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
  final chapterPathMatch = RegExp(
    '/chapter/($uuidPattern)',
    caseSensitive: false,
  ).firstMatch(link);

  if (chapterPathMatch != null) {
    return chapterPathMatch.group(1);
  }

  final directIdMatch = RegExp(
    '^$uuidPattern\$',
    caseSensitive: false,
  ).firstMatch(link.trim());

  return directIdMatch?.group(0);
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
}) async {
  if (kIsWeb) {
    return const <HitomiGalleryPreview>[];
  }

  try {
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

    final galleryIds = parseHitomiNozomiIds(
      response.bodyBytes,
      limit: limit * 4,
    );
    final routing = await fetchHitomiRouting();
    final previews = <HitomiGalleryPreview>[];

    for (final galleryId in galleryIds) {
      final preview = await fetchHitomiGalleryPreview(galleryId, routing);

      if (preview == null) {
        continue;
      }

      previews.add(preview);

      if (previews.length >= limit) {
        break;
      }
    }

    return List<HitomiGalleryPreview>.unmodifiable(previews);
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
  versionPath: '1782259201/',
);

class HitomiRouting {
  final String versionPath;
  final Set<int> zeroSubdomainKeys;

  const HitomiRouting({
    this.versionPath = '',
    this.zeroSubdomainKeys = const <int>{},
  });

  int mirrorForHash(String hash) {
    return zeroSubdomainKeys.contains(hitomiRoutingKey(hash)) ? 0 : 1;
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

HitomiRouting parseHitomiRoutingScript(String script) {
  final versionPath =
      RegExp(r"\bb\s*:\s*'([^']*)'").firstMatch(script)?.group(1) ?? '';
  final zeroBlock = RegExp(
    r'switch\s*\(g\)\s*\{(.*?)o\s*=\s*0\s*;',
    dotAll: true,
  ).firstMatch(script);
  final zeroSubdomainKeys = <int>{};

  if (zeroBlock != null) {
    for (final match in RegExp(
      r'case\s+(\d+)\s*:',
    ).allMatches(zeroBlock.group(1)!)) {
      final key = int.tryParse(match.group(1)!);

      if (key != null) {
        zeroSubdomainKeys.add(key);
      }
    }
  }

  return HitomiRouting(
    versionPath: versionPath,
    zeroSubdomainKeys: Set<int>.unmodifiable(zeroSubdomainKeys),
  );
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
