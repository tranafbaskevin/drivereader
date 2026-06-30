part of 'package:kevdex/main.dart';

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
