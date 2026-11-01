import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../documents/application/paper_providers.dart';

/// Smallest region a reviewer can keep, as a share of the page in each direction (the server
/// checks the same).
const minFigureRegion = 0.02;

/// A region marked on one of the paper's pages: page (1-based) and
/// [left, top, right, bottom] as fractions of the page.
typedef FigureRegion = ({int page, List<double> box});

/// The region between two drag points on an image of [size], as page fractions; null when it
/// is too small to keep.
List<double>? regionFromDrag(Offset a, Offset b, Size size) {
  if (size.width <= 0 || size.height <= 0) return null;
  double x(double v) => (v / size.width).clamp(0.0, 1.0);
  double y(double v) => (v / size.height).clamp(0.0, 1.0);
  final left = x(a.dx < b.dx ? a.dx : b.dx);
  final right = x(a.dx < b.dx ? b.dx : a.dx);
  final top = y(a.dy < b.dy ? a.dy : b.dy);
  final bottom = y(a.dy < b.dy ? b.dy : a.dy);
  if (right - left < minFigureRegion || bottom - top < minFigureRegion) return null;
  return [left, top, right, bottom];
}

/// The reviewer drags a box around a figure on the paper's page (scans and layouts PrepLoop
/// couldn't read). Returns the region; the server crops it from the original PDF.
class MarkFigureScreen extends ConsumerStatefulWidget {
  const MarkFigureScreen({super.key, required this.documentId, required this.pages});

  final String documentId;

  /// The pages the question is on (shown first to last).
  final List<int> pages;

  @override
  ConsumerState<MarkFigureScreen> createState() => _MarkFigureScreenState();
}

class _MarkFigureScreenState extends ConsumerState<MarkFigureScreen> {
  final _imageKey = GlobalKey();
  late int _index = 0;
  Offset? _start;
  Offset? _end;

  int get _page => widget.pages[_index];

  Size? get _imageSize => (_imageKey.currentContext?.findRenderObject() as RenderBox?)?.size;

  List<double>? get _region => _start == null || _end == null
      ? null
      : regionFromDrag(_start!, _end!, _imageSize ?? Size.zero);

  void _showPage(int index) => setState(() {
    _index = index;
    _start = _end = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = ref.watch(paperPageProvider((widget.documentId, _page)));
    final region = _region;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.markFigureTitle),
        actions: [
          TextButton(
            onPressed: region == null
                ? null
                : () => Navigator.of(context).pop<FigureRegion>((page: _page, box: region)),
            child: Text(l10n.markFigureKeep),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(l10n.markFigureHint),
              if (widget.pages.length > 1)
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.markFigurePreviousPage,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _index > 0 ? () => _showPage(_index - 1) : null,
                    ),
                    Text(l10n.markFigurePage(_page)),
                    IconButton(
                      tooltip: l10n.markFigureNextPage,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _index < widget.pages.length - 1
                          ? () => _showPage(_index + 1)
                          : null,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              switch (image) {
                AsyncData(:final value) => GestureDetector(
                  onPanStart: (d) => setState(() => _start = _end = d.localPosition),
                  onPanUpdate: (d) => setState(() => _end = d.localPosition),
                  child: Stack(
                    children: [
                      Image.memory(value, key: _imageKey, gaplessPlayback: true),
                      if (_start != null && _end != null)
                        Positioned.fromRect(
                          rect: Rect.fromPoints(_start!, _end!),
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AsyncError() => Text(l10n.markFigurePageFailed),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ],
          ),
        ),
      ),
    );
  }
}
