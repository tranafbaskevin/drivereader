import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivereader/main.dart';

void resetKevDexTestState() {
  readingProgressNotifier.value = null;
  libraryNotifier.value = const <LibraryItem>[];
  uiBackgroundNotifier.value = defaultUiBackground;
  readerComfortNotifier.value = defaultReaderComfortSettings;
  privateSourceSettingsNotifier.value = defaultPrivateSourceSettings;
}

void main() {
  test('MangaDex chapter links are detected', () {
    const chapterId = '2a1d7c6c-1234-4abc-8def-1234567890ab';

    expect(
      extractMangaDexChapterId('https://mangadex.org/chapter/$chapterId/1'),
      chapterId,
    );
    expect(detectStorySource(chapterId), StorySourceType.mangaDexChapter);
  });

  test('Private source links are detected', () {
    expect(extractNHentaiGalleryId('https://nhentai.xxx/g/123456/'), '123456');
    expect(extractNHentaiGalleryId('nhentai:987654'), '987654');
    expect(
      detectStorySource('https://nhentai.net/g/123456/'),
      StorySourceType.nHentaiGallery,
    );

    expect(
      extractHitomiGalleryId('https://hitomi.la/reader/7654321.html#1'),
      '7654321',
    );
    expect(extractHitomiGalleryId('hitomi:112233'), '112233');
    expect(
      detectStorySource('https://hitomi.la/galleries/7654321.html'),
      StorySourceType.hitomiGallery,
    );
  });

  test('Private source settings migrate thumbnail blur on', () {
    final settings = PrivateSourceSettings.fromJson({
      'enabled': true,
      'acceptedAtMs': 123,
    });

    expect(settings, isNotNull);
    expect(settings!.isAccepted, isTrue);
    expect(settings.blurPrivateThumbnails, isTrue);
    expect(settings.copyWith(blurPrivateThumbnails: false).toJson(), {
      'enabled': true,
      'acceptedAtMs': 123,
      'blurPrivateThumbnails': false,
    });
  });

  test('MangaDex home chapter payloads become chapter cards', () {
    final previews = parseMangaDexChapterPreviews({
      'data': [
        {
          'id': 'chapter-id-1',
          'attributes': {
            'chapter': '5',
            'title': 'A Rainy Day',
            'pages': 24,
            'translatedLanguage': 'en',
          },
          'relationships': [
            {
              'type': 'manga',
              'id': 'manga-id-1',
              'attributes': {
                'title': {'en': 'Digi Cat'},
              },
            },
          ],
        },
      ],
    });

    expect(previews, hasLength(1));
    expect(previews.first.chapterId, 'chapter-id-1');
    expect(
      previews.first.sourceLink,
      'https://mangadex.org/chapter/chapter-id-1',
    );
    expect(previews.first.title, 'Digi Cat');
    expect(previews.first.chapterLabel, 'Chapter 5 - A Rainy Day');
    expect(previews.first.mangaId, 'manga-id-1');
    expect(previews.first.pageCount, 24);
    expect(previews.first.language, 'en');
  });

  test('MangaDex cover payloads become cover URLs', () {
    final covers = parseMangaDexCoverUrls({
      'data': [
        {
          'attributes': {'fileName': 'cover-file.jpg'},
          'relationships': [
            {'type': 'manga', 'id': 'manga-id-1'},
          ],
        },
      ],
    });

    expect(
      covers['manga-id-1'],
      'https://uploads.mangadex.org/covers/manga-id-1/cover-file.jpg.256.jpg',
    );
  });

  test('NHentai gallery payloads become reader pages', () {
    final result = parseNHentaiGalleryPayload({
      'media_id': '999999',
      'title': {'pretty': 'Sample Private Gallery'},
      'images': {
        'pages': [
          {'t': 'j'},
          {'t': 'p'},
        ],
      },
    }, '123456');

    expect(result.metadata.sourceType, StorySourceType.nHentaiGallery);
    expect(result.metadata.title, 'Sample Private Gallery');
    expect(result.metadata.chapterLabel, 'Gallery 123456');
    expect(result.images, hasLength(2));
    expect(
      result.images.first.fullUrl,
      'https://i.nhentai.net/galleries/999999/1.jpg',
    );
    expect(
      result.images.last.fullUrl,
      'https://i.nhentai.net/galleries/999999/2.png',
    );
  });

  test('Hitomi gallery info scripts become reader pages', () {
    const script =
        'var galleryinfo = {"id":"7654321","title":"Hitomi Sample",'
        '"files":[{"name":"001.jpg","hash":"abcdef123456","haswebp":1},'
        '{"name":"002.png","hash":"001122334455"}]};';
    const routingScript =
        "gg = { m:function(g){var o=1;switch(g){case 1605:o=0;break;}"
        "return o;},s:function(h){return 'unused';},b:'1782259201/'};";
    final routing = parseHitomiRoutingScript(routingScript);

    final result = parseHitomiGalleryInfo(script, '7654321', routing: routing);

    expect(result.metadata.sourceType, StorySourceType.hitomiGallery);
    expect(result.metadata.title, 'Hitomi Sample');
    expect(result.metadata.chapterLabel, 'Gallery 7654321');
    expect(result.images, hasLength(2));
    expect(hitomiRoutingKey('abcdef123456'), 1605);
    expect(
      result.images.first.fullUrl,
      'https://w1.gold-usergeneratedcontent.net/1782259201/1605/abcdef123456.webp',
    );
    expect(
      result.images.last.fullUrl,
      'https://w2.gold-usergeneratedcontent.net/1782259201/1349/001122334455.webp',
    );
  });

  test('Hitomi home index bytes become gallery ids', () {
    expect(
      parseHitomiNozomiIds([0, 0, 0, 1, 0, 0, 15, 160], limit: 4),
      const <String>['1', '4000'],
    );
    expect(parseHitomiNozomiIds([0, 0, 0, 1], limit: 0), isEmpty);
  });

  test('Hitomi home preview parses gallery cards', () {
    const script =
        'var galleryinfo = {"id":"7654321","title":"Hitomi Sample",'
        '"language_localname":"English",'
        '"files":[{"name":"001.jpg","hash":"abcdef123456","haswebp":1},'
        '{"name":"002.png","hash":"001122334455"}]};';
    const routingScript =
        "gg = { m:function(g){var o=1;switch(g){case 1605:o=0;break;}"
        "return o;},s:function(h){return 'unused';},b:'1782259201/'};";
    final routing = parseHitomiRoutingScript(routingScript);

    final preview = parseHitomiGalleryPreview(
      script,
      '7654321',
      routing: routing,
    );

    expect(preview, isNotNull);
    expect(preview!.galleryId, '7654321');
    expect(preview.title, 'Hitomi Sample');
    expect(preview.language, 'English');
    expect(preview.pageCount, 2);
    expect(preview.sourceLink, 'https://hitomi.la/reader/7654321.html');
    expect(
      preview.thumbnailUrl,
      'https://w1.gold-usergeneratedcontent.net/1782259201/1605/abcdef123456.webp',
    );
  });

  test('Hitomi legacy image hosts migrate from saved cache', () {
    final image = DriveImage.fromJson({
      'thumbnailUrl': 'https://a.hitomi.la/webp/6/45/abcdef123456.webp',
      'fullUrl': 'https://a.hitomi.la/images/5/45/001122334455.png',
    });

    expect(image, isNotNull);
    expect(
      image!.thumbnailUrl,
      'https://w2.gold-usergeneratedcontent.net/1782259201/1605/abcdef123456.webp',
    );
    expect(
      image.fullUrl,
      'https://w2.gold-usergeneratedcontent.net/1782259201/1349/001122334455.webp',
    );
  });

  testWidgets('Home screen shows KevDex identity', (WidgetTester tester) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('KevDex'), findsOneWidget);
    expect(find.text('Read Anywhere.'), findsOneWidget);
    expect(find.text('Source Hub'), findsOneWidget);
    expect(find.text('Google Drive'), findsWidgets);
    expect(find.text('MangaDex'), findsOneWidget);
    expect(find.byTooltip('Open Google Drive'), findsOneWidget);
    expect(find.byTooltip('Manage sources'), findsOneWidget);
    expect(find.text('By Kevin and Dora-chan'), findsOneWidget);
  });

  testWidgets('Home screen switches ready sources', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    await tester.tap(find.widgetWithText(FilterChip, 'MangaDex'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open MangaDex'), findsOneWidget);
    expect(find.byTooltip('Open MangaDex Home'), findsOneWidget);
    expect(find.byTooltip('Open Google Drive'), findsNothing);
  });

  testWidgets('Source Hub keeps private adapters hidden by default', (
    WidgetTester tester,
  ) async {
    resetKevDexTestState();

    await tester.pumpWidget(const DriveReaderApp());

    await tester.tap(find.byTooltip('Manage sources'));
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsWidgets);
    expect(find.text('Private Sources'), findsOneWidget);
    expect(find.text('NHentai'), findsNothing);
    expect(find.text('Hitomi'), findsNothing);
    expect(find.byTooltip('Clear app cache'), findsOneWidget);
  });

  testWidgets('Source Hub reveals private adapters after confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    resetKevDexTestState();

    await tester.pumpWidget(const DriveReaderApp());

    await tester.tap(find.byTooltip('Manage sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Toggle private sources'));
    await tester.pumpAndSettle();

    expect(find.text('Enable Private Sources?'), findsOneWidget);

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();

    expect(find.text('Private Ready'), findsOneWidget);
    expect(find.text('NHentai'), findsWidgets);
    expect(find.text('Hitomi'), findsWidgets);
    expect(find.text('Blur Private Thumbnails'), findsOneWidget);
    expect(find.byTooltip('Toggle thumbnail blur'), findsOneWidget);
    expect(find.byTooltip('Clear private history'), findsOneWidget);

    resetKevDexTestState();
  });

  testWidgets('Private thumbnail blur can be turned off', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    resetKevDexTestState();
    privateSourceSettingsNotifier.value = const PrivateSourceSettings(
      enabled: true,
      acceptedAtMs: 123,
      blurPrivateThumbnails: false,
    );
    libraryNotifier.value = const <LibraryItem>[
      LibraryItem(
        sourceLink: 'private-gallery-link',
        images: [],
        pageIndex: 0,
        updatedAtMs: 1,
        metadata: StoryMetadata(
          sourceType: StorySourceType.nHentaiGallery,
          title: 'Private Gallery',
        ),
      ),
    ];

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Private Gallery'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);

    resetKevDexTestState();
  });

  testWidgets('Home can select private source inputs after confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    resetKevDexTestState();

    await tester.pumpWidget(const DriveReaderApp());

    await tester.tap(find.byTooltip('Manage sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Toggle private sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'NHentai'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open NHentai'), findsOneWidget);
    expect(find.text('NHentai opens through Private Sources.'), findsOneWidget);
    expect(find.text('Paste NHentai gallery link'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Hitomi'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open Hitomi Home'), findsOneWidget);
    expect(find.byTooltip('Open Hitomi'), findsOneWidget);
    expect(find.text('Paste Hitomi gallery link'), findsOneWidget);

    resetKevDexTestState();
  });

  testWidgets('Source Hub confirms before clearing cache', (
    WidgetTester tester,
  ) async {
    resetKevDexTestState();

    await tester.pumpWidget(const DriveReaderApp());

    await tester.tap(find.byTooltip('Manage sources'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Clear app cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear app cache'));
    await tester.pumpAndSettle();

    expect(find.text('Clear cache?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('Home screen shows continue reading when progress exists', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = const ReadingProgress(
      sourceLink: 'not-a-drive-link',
      images: [],
      pageIndex: 0,
    );
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Page 1 / 1'), findsOneWidget);

    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;
  });

  testWidgets('Home screen shows saved library items', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[
      LibraryItem(
        sourceLink: 'saved-library-link',
        images: [],
        pageIndex: 0,
        updatedAtMs: 1,
      ),
    ];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Single Page'), findsOneWidget);
    expect(find.text('Page 1 / 1'), findsOneWidget);

    libraryNotifier.value = const <LibraryItem>[];
  });

  testWidgets('Home screen covers private library thumbnails', (
    WidgetTester tester,
  ) async {
    resetKevDexTestState();
    libraryNotifier.value = const <LibraryItem>[
      LibraryItem(
        sourceLink: 'private-gallery-link',
        images: [],
        pageIndex: 0,
        updatedAtMs: 1,
        metadata: StoryMetadata(
          sourceType: StorySourceType.nHentaiGallery,
          title: 'Private Gallery',
        ),
      ),
    ];

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Private Gallery'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

    resetKevDexTestState();
  });

  testWidgets('Full Library page shows items outside home preview', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = List<LibraryItem>.unmodifiable(
      List.generate(
        4,
        (index) => LibraryItem(
          sourceLink: 'saved-library-link-$index',
          images: const [],
          pageIndex: 0,
          updatedAtMs: index,
          metadata: StoryMetadata(
            sourceType: StorySourceType.singlePage,
            title: 'Saved Story ${index + 1}',
          ),
        ),
      ),
    );
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Saved Story 1'), findsOneWidget);
    expect(find.text('Saved Story 2'), findsOneWidget);
    expect(find.text('Saved Story 3'), findsOneWidget);
    expect(find.text('Saved Story 4'), findsNothing);

    await tester.tap(find.byTooltip('Open full Library'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Story 4'), findsOneWidget);
    expect(find.text('4 saved'), findsOneWidget);

    libraryNotifier.value = const <LibraryItem>[];
  });

  testWidgets('Home screen labels MangaDex library items', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[
      LibraryItem(
        sourceLink:
            'https://mangadex.org/chapter/2a1d7c6c-1234-4abc-8def-1234567890ab',
        images: [],
        pageIndex: 0,
        updatedAtMs: 1,
        metadata: StoryMetadata(
          sourceType: StorySourceType.mangaDexChapter,
          title: 'Digi Cat',
          chapterLabel: 'Chapter 1 - First Read',
        ),
      ),
    ];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Digi Cat'), findsOneWidget);
    expect(find.text('Chapter 1 - First Read - Page 1 / 1'), findsOneWidget);
    expect(find.text('MangaDex'), findsWidgets);

    libraryNotifier.value = const <LibraryItem>[];
  });

  testWidgets('MangaDex Home shows latest chapter cards', (
    WidgetTester tester,
  ) async {
    resetKevDexTestState();

    await tester.pumpWidget(
      MaterialApp(
        home: MangaDexHomePage(
          chapterLoader: () async => const <MangaDexChapterPreview>[
            MangaDexChapterPreview(
              chapterId: 'chapter-id-1',
              sourceLink: 'https://mangadex.org/chapter/chapter-id-1',
              title: 'Digi Cat',
              chapterLabel: 'Chapter 5',
              pageCount: 24,
              language: 'en',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MangaDex Home'), findsOneWidget);
    expect(find.text('Latest Chapters'), findsOneWidget);
    expect(find.text('Digi Cat'), findsOneWidget);
    expect(find.text('Chapter 5 - 24 pages - en'), findsOneWidget);
    expect(find.byTooltip('Refresh MangaDex Home'), findsOneWidget);

    resetKevDexTestState();
  });

  testWidgets('Reader empty state uses manga-friendly copy', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(link: 'not-a-drive-link', images: [], initialIndex: 0),
      ),
    );

    expect(find.text('This page could not be opened.'), findsOneWidget);
    expect(find.text('Check the link or try again.'), findsOneWidget);
  });

  testWidgets('Folder reader keeps reader controls after gallery selection', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          link: 'https://drive.google.com/drive/folders/folder-id',
          images: [
            DriveImage(thumbnailUrl: 'page-1-thumb', fullUrl: 'page-1-full'),
            DriveImage(thumbnailUrl: 'page-2-thumb', fullUrl: 'page-2-full'),
          ],
          initialIndex: 0,
          startInGallery: false,
        ),
      ),
    );

    expect(find.text('Page 1 / 2'), findsOneWidget);
    expect(find.byTooltip('Gallery'), findsOneWidget);
    expect(find.byTooltip('Reader comfort'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
