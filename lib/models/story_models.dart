part of 'package:kevdex/main.dart';

enum StorySourceStatus { ready, planned }

enum StorySourceType {
  driveFolder,
  mangaDexChapter,
  hentai2ReadChapter,
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
    type: StorySourceType.hentai2ReadChapter,
    label: 'Hentai2Read',
    hintText: 'Paste Hentai2Read story or chapter link',
    icon: Icons.auto_stories_rounded,
    status: StorySourceStatus.ready,
    privateSource: true,
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

  StoryMetadata copyWith({
    StorySourceType? sourceType,
    String? title,
    String? chapterLabel,
  }) {
    return StoryMetadata(
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      chapterLabel: chapterLabel ?? this.chapterLabel,
    );
  }

  String get sourceLabel {
    switch (sourceType) {
      case StorySourceType.driveFolder:
        return 'Google Drive';
      case StorySourceType.mangaDexChapter:
        return 'MangaDex';
      case StorySourceType.hentai2ReadChapter:
        return 'Hentai2Read';
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

class Hentai2ReadStoryPreview {
  final String slug;
  final String title;
  final String sourceLink;
  final String? thumbnailUrl;
  final String? description;

  const Hentai2ReadStoryPreview({
    required this.slug,
    required this.title,
    required this.sourceLink,
    this.thumbnailUrl,
    this.description,
  });
}

class Hentai2ReadChapterPreview {
  final String chapterId;
  final String sourceLink;
  final String title;
  final String? chapterLabel;
  final String? thumbnailUrl;

  const Hentai2ReadChapterPreview({
    required this.chapterId,
    required this.sourceLink,
    required this.title,
    this.chapterLabel,
    this.thumbnailUrl,
  });

  StoryMetadata get metadata {
    return StoryMetadata(
      sourceType: StorySourceType.hentai2ReadChapter,
      title: title,
      chapterLabel: chapterLabel,
    );
  }
}

class Hentai2ReadStoryDetail {
  final Hentai2ReadStoryPreview story;
  final List<Hentai2ReadChapterPreview> chapters;

  const Hentai2ReadStoryDetail({required this.story, required this.chapters});
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

class MangaDexMangaPreview {
  final String mangaId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String sourceLink;

  const MangaDexMangaPreview({
    required this.mangaId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.sourceLink,
  });
}
