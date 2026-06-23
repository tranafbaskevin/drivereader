import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivereader/main.dart';

void main() {
  testWidgets('Home screen shows KevDex identity', (WidgetTester tester) async {
    readingProgressNotifier.value = null;
    uiBackgroundNotifier.value = defaultUiBackground;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('KevDex'), findsOneWidget);
    expect(find.text('Read Anywhere.'), findsOneWidget);
    expect(find.text('Open Reader'), findsOneWidget);
    expect(find.text('By Kevin and Dora-chan'), findsOneWidget);
  });

  testWidgets('Home screen shows continue reading when progress exists', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = const ReadingProgress(
      sourceLink: 'not-a-drive-link',
      images: [],
      pageIndex: 0,
    );
    uiBackgroundNotifier.value = defaultUiBackground;

    await tester.pumpWidget(const DriveReaderApp());

    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Page 1 / 1'), findsOneWidget);

    readingProgressNotifier.value = null;
    uiBackgroundNotifier.value = defaultUiBackground;
  });

  testWidgets('Reader empty state uses manga-friendly copy', (
    WidgetTester tester,
  ) async {
    readingProgressNotifier.value = null;
    uiBackgroundNotifier.value = defaultUiBackground;

    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(link: 'not-a-drive-link', images: [], initialIndex: 0),
      ),
    );

    expect(find.text('This page could not be opened.'), findsOneWidget);
    expect(find.text('Check the link or try again.'), findsOneWidget);
  });
}
