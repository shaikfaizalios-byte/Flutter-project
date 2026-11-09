import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/rich_question_text.dart';
import '../domain/practice_models.dart';

/// Answers a question whose format takes more than one tap: several options, pairs or an order.
class ResponseAnswer extends StatelessWidget {
  const ResponseAnswer({
    required this.item,
    required this.locked,
    required this.onSubmit,
    super.key,
  });

  final SessionItemView item;
  final bool locked;
  final Future<bool> Function(Map<String, dynamic> response) onSubmit;

  @override
  Widget build(BuildContext context) => switch (item.format) {
    'multiple_correct' => _MultipleCorrect(item: item, locked: locked, onSubmit: onSubmit),
    'match' => _Match(item: item, locked: locked, onSubmit: onSubmit),
    _ => _Ordering(item: item, locked: locked, onSubmit: onSubmit),
  };
}

class _MultipleCorrect extends StatefulWidget {
  const _MultipleCorrect({required this.item, required this.locked, required this.onSubmit});

  final SessionItemView item;
  final bool locked;
  final Future<bool> Function(Map<String, dynamic>) onSubmit;

  @override
  State<_MultipleCorrect> createState() => _MultipleCorrectState();
}

class _MultipleCorrectState extends State<_MultipleCorrect> {
  late final _chosen = <int>{
    for (final p in (widget.item.response?['positions'] as List<dynamic>?) ?? const []) p as int,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sessionChooseAllThatApply),
        for (final option in widget.item.options)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: RichQuestionText('${option.label}. ${option.text}', selectable: false),
            value: _chosen.contains(option.position),
            onChanged: widget.locked
                ? null
                : (on) => setState(
                    () => on ?? false
                        ? _chosen.add(option.position)
                        : _chosen.remove(option.position),
                  ),
          ),
        if (!widget.locked)
          FilledButton(
            onPressed: _chosen.isEmpty
                ? null
                : () => widget.onSubmit({'positions': _chosen.toList()..sort()}),
            child: Text(l10n.sessionTypedAnswerSave),
          ),
      ],
    );
  }
}

class _Match extends StatefulWidget {
  const _Match({required this.item, required this.locked, required this.onSubmit});

  final SessionItemView item;
  final bool locked;
  final Future<bool> Function(Map<String, dynamic>) onSubmit;

  @override
  State<_Match> createState() => _MatchState();
}

class _MatchState extends State<_Match> {
  List<String> get _left => widget.item.formatData?['left'] ?? const [];
  List<String> get _right => widget.item.formatData?['right'] ?? const [];

  late final _chosen = <int, int>{
    for (final pair in (widget.item.response?['pairs'] as List<dynamic>?) ?? const [])
      (pair as List<dynamic>)[0] as int: pair[1] as int,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        for (final (index, text) in _left.indexed)
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(child: RichQuestionText(text, selectable: false)),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _chosen[index],
                  hint: Text(l10n.sessionMatchChoose),
                  onChanged: widget.locked
                      ? null
                      : (value) => setState(() => _chosen[index] = value!),
                  items: [
                    for (final (position, right) in _right.indexed)
                      DropdownMenuItem(
                        value: position,
                        child: RichQuestionText(right, selectable: false),
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (!widget.locked)
          FilledButton(
            onPressed: _chosen.length < _left.length
                ? null
                : () => widget.onSubmit({
                    'pairs': [
                      for (final e in _chosen.entries) [e.key, e.value],
                    ],
                  }),
            child: Text(l10n.sessionTypedAnswerSave),
          ),
      ],
    );
  }
}

class _Ordering extends StatefulWidget {
  const _Ordering({required this.item, required this.locked, required this.onSubmit});

  final SessionItemView item;
  final bool locked;
  final Future<bool> Function(Map<String, dynamic>) onSubmit;

  @override
  State<_Ordering> createState() => _OrderingState();
}

class _OrderingState extends State<_Ordering> {
  List<String> get _items => widget.item.formatData?['items'] ?? const [];

  late final _order = <int>[
    ...((widget.item.response?['order'] as List<dynamic>?)?.cast<int>() ??
        List<int>.generate(_items.length, (i) => i)),
  ];

  void _move(int from, int to) => setState(() => _order.insert(to, _order.removeAt(from)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sessionOrderHelp),
        for (final (place, index) in _order.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text('${place + 1}'),
            title: RichQuestionText(_items[index], selectable: false),
            trailing: widget.locked
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.sessionOrderUp,
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: place == 0 ? null : () => _move(place, place - 1),
                      ),
                      IconButton(
                        tooltip: l10n.sessionOrderDown,
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: place == _order.length - 1
                            ? null
                            : () => _move(place, place + 1),
                      ),
                    ],
                  ),
          ),
        if (!widget.locked)
          FilledButton(
            onPressed: () => widget.onSubmit({'order': _order}),
            child: Text(l10n.sessionTypedAnswerSave),
          ),
      ],
    );
  }
}
