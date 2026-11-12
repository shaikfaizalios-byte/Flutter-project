part of 'session_screen.dart';

const _notVisited = Color(0xFFE0E0E0);
const _notAnswered = Color(0xFFD84315);
const _answered = Color(0xFF2E7D32);
const _marked = Color(0xFF6A3FA0);
const _palettePanelWidth = 300.0;
const _sideBySideWidth = 900.0;

String cbtStatusName(AppLocalizations l10n, CbtStatus status) => switch (status) {
  CbtStatus.notVisited => l10n.cbtNotVisited,
  CbtStatus.notAnswered => l10n.cbtNotAnswered,
  CbtStatus.answered => l10n.cbtAnswered,
  CbtStatus.marked => l10n.cbtMarked,
  CbtStatus.answeredMarked => l10n.cbtAnsweredMarked,
};

/// A computer-based mock, on the conventions of the official instructions: an answer counts once
/// saved, the palette shows each question's state, and sections are open to move between.
class _CbtView extends ConsumerStatefulWidget {
  const _CbtView({required this.sessionId, required this.state});

  final String sessionId;
  final SessionState state;

  @override
  ConsumerState<_CbtView> createState() => _CbtViewState();
}

class _CbtViewState extends ConsumerState<_CbtView> {
  /// What is on the screen but not saved, by position. Leaving by the palette drops it.
  final _drafts = <int, CbtDraft>{};

  SessionController get _controller =>
      ref.read(sessionControllerProvider(widget.sessionId).notifier);

  SessionItemView get _item => widget.state.item;

  CbtDraft get _draft => _drafts[_item.position] ?? CbtDraft.of(_item);

  void _setDraft(CbtDraft draft) => setState(() => _drafts[_item.position] = draft);

  void _toggle(int position) =>
      _setDraft(CbtDraft(selected: _draft.selected == position ? null : position));

  Future<void> _save({required bool marked}) async {
    final position = _item.position;
    final saved = await _controller.saveCbt(_draft, marked: marked);
    if (!mounted) return;
    if (saved) {
      setState(() => _drafts.remove(position));
    } else {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cbtNotSaved)));
    }
  }

  Future<void> _clear() async {
    setState(() => _drafts[_item.position] = const CbtDraft());
    await _controller.clearCbt();
    if (mounted) setState(() => _drafts.remove(_item.position));
  }

  void _jump(int index) {
    setState(() => _drafts.remove(_item.position)); // the palette doesn't save
    _controller.visitCbt(index);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = widget.state.session;
    final counts = cbtCounts(session.items, _item.position);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionSubmitTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final status in CbtStatus.values)
              Text('${cbtStatusName(l10n, status)}: ${counts[status]}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionSubmit),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _controller.submit();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionSubmitFailed)));
    }
  }

  void _showPalette() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: _Palette(
            state: widget.state,
            onJump: (index) {
              Navigator.of(sheetContext).pop();
              _jump(index);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final session = state.session;
    final wide = MediaQuery.sizeOf(context).width >= _sideBySideWidth;
    final sections = cbtSections(session.items);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionQuestionOf(state.current + 1, session.items.length)),
        actions: [
          _Countdown(sessionId: widget.sessionId, state: state),
          if (!wide)
            IconButton(
              tooltip: l10n.sessionPalette,
              icon: const Icon(Icons.grid_view),
              onPressed: _showPalette,
            ),
          TextButton(onPressed: state.submitting ? null : _submit, child: Text(l10n.sessionSubmit)),
        ],
        bottom: sections.length < 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final section in sections)
                        ChoiceChip(
                          label: Text(section.name),
                          selected: _item.section == section.name,
                          onSelected: (_) => _jump(section.first),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _question(context)),
          if (wide)
            SizedBox(
              width: _palettePanelWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _Palette(state: state, onJump: _jump),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: _clear, child: Text(l10n.cbtClear)),
              OutlinedButton(
                onPressed: () => _save(marked: true),
                child: Text(l10n.cbtMarkAndNext),
              ),
              FilledButton(onPressed: () => _save(marked: false), child: Text(l10n.cbtSaveAndNext)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final item = _item;
    final shown = item.translationIn(ref.watch(shownLanguageProvider));
    final draft = _draft;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (state.session.cbt?.basis case final String basis)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(basis, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (item.origin != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OriginChip(origin: item.origin!, librarySource: item.librarySource),
          ),
        if (item.passage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: RichQuestionText(item.passage!.text),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (item.translations.isNotEmpty) _LanguageChoice(item: item),
        if (item.stem == null)
          Text(l10n.sessionQuestionRemoved)
        else
          PrintedOrText(
            key: ValueKey('cbt-printed-${item.position}'),
            questionId: item.questionId,
            figures: item.figures,
            text: RichQuestionText(
              shown?.stem ?? item.stem!,
              key: ValueKey('cbt-stem-${item.position}-${shown?.language}'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (item.isTyped)
          TextFormField(
            key: ValueKey('cbt-typed-${item.position}-${draft.typed == null}'),
            initialValue: draft.typed,
            maxLength: 100,
            keyboardType: item.typedAnswerNumeric
                ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                : TextInputType.text,
            decoration: InputDecoration(labelText: l10n.sessionTypedAnswerLabel),
            onChanged: (text) {
              _drafts[item.position] = CbtDraft(typed: text.trim().isEmpty ? null : text.trim());
            },
          ),
        if (item.format == 'multiple_correct')
          for (final option in item.options)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: RichQuestionText(
                '${option.label}. ${shown?.option(option.position) ?? option.text}',
                selectable: false,
              ),
              value: _positions(draft).contains(option.position),
              onChanged: (on) {
                final chosen = {..._positions(draft)};
                on ?? false ? chosen.add(option.position) : chosen.remove(option.position);
                _setDraft(
                  CbtDraft(
                    response: chosen.isEmpty ? null : {'positions': chosen.toList()..sort()},
                  ),
                );
              },
            )
        else if (item.takesResponse)
          ResponseAnswer(
            key: ValueKey('cbt-response-${item.position}-${draft.response == null}'),
            item: item,
            locked: false,
            onSubmit: (response) async {
              _setDraft(CbtDraft(response: response));
              return true;
            },
          )
        else
          for (final option in item.options)
            _OptionTile(
              label: option.label,
              text: shown?.option(option.position) ?? option.text,
              figure: item.questionId == null
                  ? null
                  : switch (optionFigure(item.figures, option.position)) {
                      final f? => QuestionFigureView(
                        questionId: item.questionId!,
                        figure: f,
                        zoomable: false,
                      ),
                      null => null,
                    },
              selected: draft.selected == option.position,
              correct: false,
              showFeedback: false,
              onTap: () => _toggle(option.position),
            ),
        if (state.queuedPositions.contains(item.position))
          Text(l10n.sessionSavedOffline, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<int> _positions(CbtDraft draft) =>
      ((draft.response?['positions'] as List<dynamic>?) ?? const []).cast<int>();
}

/// The current section's summary and its questions by state.
class _Palette extends StatelessWidget {
  const _Palette({required this.state, required this.onJump});

  final SessionState state;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = state.item;
    final inSection = [
      for (final (index, item) in state.session.items.indexed)
        if (item.section == current.section) (index: index, item: item),
    ];
    final counts = cbtCounts(inSection.map((e) => e.item), current.position);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          current.section ?? l10n.sessionPalette,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final status in CbtStatus.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                _StatusMark(status: status, label: '${counts[status]}', size: 28),
                Expanded(child: Text(cbtStatusName(l10n, status))),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final entry in inSection)
              Semantics(
                button: true,
                selected: entry.index == state.current,
                label: l10n.cbtQuestionStatus(
                  entry.index + 1,
                  cbtStatusName(l10n, cbtStatus(entry.item, current: entry.index == state.current)),
                ),
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onJump(entry.index),
                  child: _StatusMark(
                    status: cbtStatus(entry.item, current: entry.index == state.current),
                    label: '${entry.index + 1}',
                    size: 44,
                    current: entry.index == state.current,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One palette symbol. Shape as well as colour tells the states apart.
class _StatusMark extends StatelessWidget {
  const _StatusMark({
    required this.status,
    required this.label,
    required this.size,
    this.current = false,
  });

  final CbtStatus status;
  final String label;
  final double size;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CbtStatus.notVisited => (_notVisited, Colors.black87),
      CbtStatus.notAnswered => (_notAnswered, Colors.white),
      CbtStatus.answered => (_answered, Colors.white),
      CbtStatus.marked || CbtStatus.answeredMarked => (_marked, Colors.white),
    };
    final round = status == CbtStatus.marked || status == CbtStatus.answeredMarked;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: switch ((round, status)) {
              (true, _) => null,
              (_, CbtStatus.notAnswered) => const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              (_, CbtStatus.answered) => const BorderRadius.vertical(top: Radius.circular(12)),
              _ => BorderRadius.circular(4),
            },
            border: current
                ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
          ),
        ),
        if (status == CbtStatus.answeredMarked)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size / 3,
              height: size / 3,
              decoration: const BoxDecoration(color: _answered, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}
