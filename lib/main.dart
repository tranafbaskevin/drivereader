import 'package:flutter/material.dart';

void main() {
  runApp(const DriveReaderApp());
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
      appBar: AppBar(
        title: const Text("DriveReader"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.menu_book,
              size: 100,
            ),

            const SizedBox(height: 20),

            const Text(
              "DriveReader KEVINOS v1",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
                onPressed: () {
                  final link = linkController.text.trim();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderPage(link: link),
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
class ReaderPage extends StatelessWidget {
  final String link;

  const ReaderPage({
    super.key,
    required this.link,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = convertDriveLinkToImageUrl(link);
    final isFolder = isDriveFolderLink(link);

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
                children: List.generate(6, (index) {
                  return Card(
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
                            child: const Icon(
                              Icons.image,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            "Page ${index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              )
                  : InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  imageUrl!,
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
                  loadingBuilder: (
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

String? convertDriveLinkToImageUrl(String link) {
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