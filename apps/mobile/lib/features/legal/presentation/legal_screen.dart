import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';

enum LegalDocument {
  privacy('assets/legal/privacy-policy.md'),
  terms('assets/legal/terms.md');

  const LegalDocument(this.asset);

  final String asset;
}

/// Shows a bundled legal document (privacy policy or terms). Renders the small Markdown
/// subset the documents use: `#`/`##` headings, `-` bullets, `**bold**` and paragraphs.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document, this.bundle});

  final LegalDocument document;

  /// For tests; defaults to the app's asset bundle.
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = document == LegalDocument.privacy ? l10n.legalPrivacy : l10n.legalTerms;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: (bundle ?? DefaultAssetBundle.of(context)).loadString(document.asset),
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(:final data?) => _MarkdownView(text: data),
          AsyncSnapshot(hasError: true) => Center(child: Text(l10n.legalLoadError)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _MarkdownView extends StatelessWidget {
  const _MarkdownView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    for (final raw in text.split(RegExp(r'\n\s*\n'))) {
      final block = raw.trim();
      if (block.isEmpty) continue;
      if (block.startsWith('## ')) {
        blocks.add(_heading(block.substring(3), theme.textTheme.titleMedium));
      } else if (block.startsWith('# ')) {
        blocks.add(_heading(block.substring(2), theme.textTheme.headlineSmall));
      } else if (block
          .split('\n')
          .every((l) => l.trimLeft().startsWith('- ') || l.startsWith('  '))) {
        blocks.add(_bullets(block, theme));
      } else {
        blocks.add(_paragraph(block.replaceAll('\n', ' '), theme.textTheme.bodyMedium));
      }
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: SelectionArea(
          child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: blocks),
        ),
      ),
    );
  }

  static Widget _heading(String text, TextStyle? style) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Semantics(header: true, child: Text(text, style: style)),
  );

  static Widget _paragraph(String text, TextStyle? style) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text.rich(_inline(text, style)),
  );

  static Widget _bullets(String block, ThemeData theme) {
    // Join wrapped continuation lines onto their bullet.
    final items = <String>[];
    for (final line in block.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('- ')) {
        items.add(trimmed.substring(2));
      } else if (items.isNotEmpty) {
        items[items.length - 1] = '${items.last} ${line.trim()}';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text.rich(_inline(item, theme.textTheme.bodyMedium))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static TextSpan _inline(String text, TextStyle? style) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}
