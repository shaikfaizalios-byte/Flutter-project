import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../application/question_bank_providers.dart';
import '../domain/question.dart';

/// A figure cropped from the source PDF, shown as printed (never redrawn). Tapping opens a
/// zoomable view. The space is reserved from the stored size, so the layout doesn't jump.
class QuestionFigureView extends ConsumerWidget {
  const QuestionFigureView({
    super.key,
    required this.questionId,
    required this.figure,
    this.zoomable = true,
  });

  final String questionId;
  final QuestionFigure figure;

  /// False inside a tappable parent (an answer option), where a tap must select it.
  final bool zoomable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final label = switch (figure.kind) {
      FigureKind.original => l10n.figureOriginalLabel(figure.pageNumber),
      FigureKind.option => l10n.figureOptionLabel(figure.pageNumber),
      FigureKind.stem => l10n.figureLabel(figure.pageNumber),
    };
    final image = ref.watch(figureBytesProvider((questionId, figure.id)));
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Rendered at 2x, so half the pixel width is the printed size.
        final width = math.min(figure.width / 2, constraints.maxWidth);
        final aspect = figure.width / math.max(figure.height, 1);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: aspect,
              child: Semantics(
                label: label,
                image: true,
                button: zoomable && image.hasValue,
                child: switch (image) {
                  AsyncData(:final value) => InkWell(
                    onTap: !zoomable
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (context) =>
                                _ZoomDialog(label: label, image: Image.memory(value)),
                          ),
                    child: ColoredBox(
                      // Figures are printed on white; keep them legible in dark mode.
                      color: Colors.white,
                      child: Image.memory(value, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  ),
                  AsyncError() => DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant)),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          l10n.figureLoadError,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  _ => ColoredBox(color: colors.surfaceContainerHighest),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The figures that belong with the question text (printed original first), one per row.
class QuestionFigures extends StatelessWidget {
  const QuestionFigures({super.key, required this.questionId, required this.figures});

  final String questionId;
  final List<QuestionFigure> figures;

  @override
  Widget build(BuildContext context) {
    final shown = questionFigures(figures);
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          for (final figure in shown) QuestionFigureView(questionId: questionId, figure: figure),
        ],
      ),
    );
  }
}

class _ZoomDialog extends StatelessWidget {
  const _ZoomDialog({required this.label, required this.image});

  final String label;
  final Image image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(label),
          leading: IconButton(
            tooltip: l10n.close,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ColoredBox(
          color: Colors.white,
          child: InteractiveViewer(maxScale: 6, child: Center(child: image)),
        ),
      ),
    );
  }
}
