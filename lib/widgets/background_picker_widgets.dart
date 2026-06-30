part of 'package:kevdex/main.dart';

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
