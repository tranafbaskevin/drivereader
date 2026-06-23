import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivereader/main.dart';

void main() {
  test('MangaDex chapter links are detected', () {
    const chapterId = '2a1d7c6c-1234-4abc-8def-1234567890ab';

    expect(
      extractMangaDexChapterId('https://mangadex.org/chapter/$chapterId/1'),
      chapterId,
    );
    expect(detectStorySource(chapterId), StorySourceType.mangaDexChapter);
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

  testWidgets('Source Hub shows planned adapters', (WidgetTester tester) async {
    readingProgressNotifier.value = null;
    libraryNotifier.value = const <LibraryItem>[];
    uiBackgroundNotifier.value = defaultUiBackground;
    readerComfortNotifier.value = defaultReaderComfortSettings;

    await tester.pumpWidget(const DriveReaderApp());

    await tester.tap(find.byTooltip('Manage sources'));
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsWidgets);
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('NHentai'), findsOneWidget);
    expect(find.text('Hitomi'), findsOneWidget);
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
