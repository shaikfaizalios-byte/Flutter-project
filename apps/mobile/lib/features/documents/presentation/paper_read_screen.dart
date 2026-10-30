import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/paper_providers.dart';

/// A paper exactly as it was uploaded: every page of the original PDF, rendered by the server.
/// Tapping a page opens it full screen to zoom.
class PaperReadScreen extends StatelessWidget {
  const PaperReadScreen({
    super.key,
    required this.documentId,
    required this.name,
    required this.pages,
  });

  final String documentId;
  final String name;
  final int pages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paperReadTitle(name))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: pages,
            itemBuilder: (context, index) =>
                _PageView(documentId: documentId, page: index + 1, pages: pages),
          ),
        ),
      ),
    );
  }
}

class _PageView extends ConsumerWidget {
  const _PageView({required this.documentId, required this.page, required this.pages});

  final String documentId;
  final int page;
  final int pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final key = (documentId, page);
    final label = l10n.paperPageOf(page, pages);
    final Widget content = switch (ref.watch(paperPageProvider(key))) {
      AsyncData(:final value) => Semantics(
        image: true,
        label: label,
        button: true,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog.fullscreen(
              child: Stack(
                children: [
                  InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.memory(value, gaplessPlayback: true)),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: IconButton.filledTonal(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Image.memory(value, width: double.infinity, fit: BoxFit.fitWidth),
        ),
      ),
      AsyncError() => AspectRatio(
        aspectRatio: 1 / 1.414,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.paperPageFailed),
              TextButton(
                onPressed: () => ref.invalidate(paperPageProvider(key)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      _ => const AspectRatio(
        aspectRatio: 1 / 1.414, // A4, until the page arrives
        child: Center(child: CircularProgressIndicator()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Card(clipBehavior: Clip.antiAlias, margin: EdgeInsets.zero, child: content),
        ],
      ),
    );
  }
}
