import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(const DriveReaderApp());
}

class DriveImage {
  final String thumbnailUrl;
  final String fullUrl;

  const DriveImage({required this.thumbnailUrl, required this.fullUrl});
}

class DriveReaderApp extends StatelessWidget {
  const DriveReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveReader',
      theme: ThemeData.dark(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DriveReader"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(Icons.menu_book, size: 100),

            const SizedBox(height: 20),

            const Text(
              "DriveReader KEVINOS v1",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              "Dán link Google Drive để đọc truyện",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            TextField(
              controller: linkController,
              decoration: InputDecoration(
                hintText: "https://drive.google.com/...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final link = linkController.text.trim();
                  print('OPEN BUTTON CLICKED: $link');

                  final folderId = extractDriveFolderId(link);
                  print('FOLDER ID: $folderId');

                  List<DriveImage> images = [];

                  if (folderId != null) {
                    images = await fetchDriveFolderImages(folderId);
                    print('IMAGES FOUND: ${images.length}');
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderPage(
                        link: link,
                        images: images,
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
                child: const Text("MỞ TRUYỆN"),
              ),
            ),
          ],
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
  bool showControls = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = convertDriveLinkToImageUrl(widget.link);
    final isFolder = isDriveFolderLink(widget.link);

    final folderImages = widget.images;
    final pageController = PageController(initialPage: widget.initialIndex);

    void preloadImage(String url) {
      precacheImage(NetworkImage(url), context);
    }

    void preloadAround(int index) {
      if (index > 0) {
        preloadImage(folderImages[index - 1].fullUrl);
      }

      if (index < folderImages.length - 1) {
        preloadImage(folderImages[index + 1].fullUrl);
      }
    }

    void showReaderControls() {
      setState(() {
        showControls = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            showControls = false;
          });
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(0),
            child: Center(
              child: isFolder
                  ? GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.all(16),
                      children: List.generate(folderImages.length, (index) {
                        return InkWell(
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
                          child: Card(
                            color: Colors.grey[900],
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    child: Image.network(
                                      folderImages[index].thumbnailUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    "Page ${index + 1}",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    )
                  : PageView.builder(
                      controller: pageController,
                      itemCount: folderImages.length,
                      itemBuilder: (context, pageIndex) {
                        preloadAround(pageIndex);

                        final currentImage = folderImages[pageIndex];
                        return GestureDetector(
                          onTap: showReaderControls,
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: Image.network(
                              currentImage.fullUrl,
                              fit: BoxFit.fitWidth,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        "Failed to load image",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (
                                    BuildContext context,
                                    Widget child,
                                    ImageChunkEvent? loadingProgress,
                                  ) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }

                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (!isFolder && showControls)
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
                      onPressed: () {
                        pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                ),
              ),
            ),
          if (!isFolder && showControls)
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
                    onPressed: () {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
              ),
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

  print('DRIVE API RESPONSE: ${response.body}');

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
