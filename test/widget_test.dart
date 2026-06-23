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

    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('NHentai'), findsWidgets);
    expect(find.text('Hitomi'), findsWidgets);
    expect(find.byTooltip('Clear private history'), findsOneWidget);

    resetKevDexTestState();
  });

  testWidgets('Home can stage private source links without opening reader', (
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
    await tester.tap(find.text('NHentai').last);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open NHentai'), findsOneWidget);
    expect(
      find.text('NHentai reader is staged for the next adapter build.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField),
      'https://nhentai.xxx/g/123456/',
    );
    await tester.ensureVisible(find.byTooltip('Open NHentai'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(const Duration(milliseconds: 250));

    expect(KevDexMemory.lastNHentaiLink, 'https://nhentai.xxx/g/123456/');
    expect(KevDexMemory.lastLink, 'https://nhentai.xxx/g/123456/');
    expect(find.byType(ReaderPage), findsNothing);

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
