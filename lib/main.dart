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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đọc truyện"),
      ),
      body: Center(
        child: Text(
          "Đang mở truyện...\nDriveReader v1.2\n\n$link",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}