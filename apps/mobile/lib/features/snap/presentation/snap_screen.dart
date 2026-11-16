import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/utils/app_log.dart';
import '../../ai/presentation/search_answer_panel.dart';
import '../../exams/application/active_exam.dart';
import '../../settings/application/app_preferences.dart';
import '../data/snap_repository.dart';

/// Longest text the "ask from my material" answer takes.
const snapAskMaxLength = 300;

/// Snap a question: a photo of a printed question is read on the server, and the same question
/// is looked for in the learner's own papers, questions and concepts. The photo isn't stored.
class SnapScreen extends ConsumerStatefulWidget {
  const SnapScreen({super.key});

  @override
  ConsumerState<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends ConsumerState<SnapScreen> {
  final _text = TextEditingController();
  SnapReading? _reading;
  List<SnapMatch> _matches = const [];
  bool _busy = false;
  Object? _failure;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _snap({required bool camera}) async {
    final exam = ref.read(activeExamProvider);
    if (exam == null) return;
    final photo = await ref.read(snapPhotoProvider)(camera: camera);
    if (photo == null || !mounted) return;
    final language = ref
        .read(appPreferencesProvider)
        .contentLanguageFor(Localizations.localeOf(context));
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final reading = await ref
          .read(snapRepositoryProvider)
          .readPhoto(examCode: exam, name: photo.name, bytes: photo.bytes, language: language);
      if (!mounted) return;
      _text.text = reading.text;
      setState(() {
        _reading = reading;
        _matches = reading.matches;
      });
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Snap a question failed', error, stack);
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchAgain() async {
    final exam = ref.read(activeExamProvider);
    final text = _text.text.trim();
    if (exam == null || text.length < 2) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final matches = await ref.read(snapRepositoryProvider).match(examCode: exam, text: text);
      if (mounted) setState(() => _matches = matches);
    } on Object catch (error, stack) {
      if (error is! AppFailure) logError('Snap search failed', error, stack);
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Watched so the current exam is known when the learner chooses a photo.
    final exam = ref.watch(activeExamProvider);
    final reading = _reading;
    final query = _text.text.trim();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.snapTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(l10n.snapIntro),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.snapTake),
                    onPressed: _busy || exam == null ? null : () => _snap(camera: true),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(reading == null ? l10n.snapChoose : l10n.snapAnother),
                    onPressed: _busy || exam == null ? null : () => _snap(camera: false),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
              ],
              if (_failure case final failure?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_message(l10n, failure), style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (reading != null) ...[
                const SizedBox(height: AppSpacing.lg),
                if (reading.lowConfidence) ...[
                  Text(l10n.snapUnsure, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                ],
                TextField(
                  controller: _text,
                  minLines: 2,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.snapReadText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.search),
                    label: Text(l10n.snapSearchAgain),
                    onPressed: _busy || query.length < 2 ? null : _searchAgain,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.snapMatches, style: theme.textTheme.titleSmall),
                if (_matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(l10n.snapNoMatches),
                  ),
                for (final match in _matches) _MatchTile(match: match),
                if (query.length >= 2) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.snapAsk, style: theme.textTheme.titleSmall),
                  SearchAnswerPanel(
                    query: query.length > snapAskMaxLength
                        ? query.substring(0, snapAskMaxLength)
                        : query,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _message(AppLocalizations l10n, Object failure) => switch (failure) {
    NetworkFailure() || TimeoutFailure() => l10n.snapOffline,
    ServerFailure(code: 'photo_too_large') => l10n.snapTooLarge,
    ServerFailure(code: 'ocr_unavailable') => l10n.snapNoOcr,
    _ => l10n.snapUnreadable,
  };
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});

  final SnapMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = switch (match.kind) {
      SnapMatchKind.question when match.questionId != null => AppRoutes.question(match.questionId!),
      SnapMatchKind.concept when match.conceptId != null => AppRoutes.concept(match.conceptId!),
      _ => null,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (match.kind) {
        SnapMatchKind.question => Icons.quiz_outlined,
        SnapMatchKind.concept => Icons.lightbulb_outline,
        SnapMatchKind.page => Icons.description_outlined,
      }),
      title: Text(match.label),
      subtitle: Text(
        [match.snippet, if (match.kind == SnapMatchKind.page) l10n.snapPageAsRead].join('\n'),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: route == null ? null : () => context.push(route),
    );
  }
}
