/// Formats a reviewer can give a question. The first group has one correct option and needs
/// nothing more; the others are saved with an answer built by [buildAnswerSpec].
const singleAnswerFormats = ['single_correct', 'assertion_reason', 'statement', 'true_false'];
const specFormats = ['multiple_correct', 'numeric', 'fill_blank', 'match', 'ordering'];

/// What a reviewer typed for a format's answer. One value per line where it takes several.
class SpecInput {
  const SpecInput({
    this.positions = const {},
    this.value = '',
    this.tolerance = '',
    this.low = '',
    this.high = '',
    this.lines = '',
  });

  final Set<int> positions;
  final String value;
  final String tolerance;
  final String low;
  final String high;
  final String lines;
}

List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

/// The answer to save, or null when what was typed isn't complete. The server checks it again.
Map<String, dynamic>? buildAnswerSpec(String format, SpecInput input) {
  switch (format) {
    case 'multiple_correct':
      if (input.positions.isEmpty) return null;
      return {'correct_positions': input.positions.toList()..sort()};
    case 'numeric':
      if (input.value.trim().isNotEmpty) {
        return {
          'value': input.value.trim(),
          if (input.tolerance.trim().isNotEmpty) 'tolerance': input.tolerance.trim(),
        };
      }
      if (input.low.trim().isEmpty || input.high.trim().isEmpty) return null;
      return {'min': input.low.trim(), 'max': input.high.trim()};
    case 'fill_blank':
      final accepted = _lines(input.lines);
      return accepted.isEmpty ? null : {'accepted': accepted};
    case 'match':
      return _matchSpec(_lines(input.lines));
    case 'ordering':
      return _orderingSpec(_lines(input.lines));
  }
  return null;
}

/// "left = right" on each line. A right side used twice is one item.
Map<String, dynamic>? _matchSpec(List<String> lines) {
  final left = <String>[];
  final right = <String>[];
  final pairs = <List<int>>[];
  for (final line in lines) {
    final at = line.indexOf('=');
    if (at <= 0 || at == line.length - 1) return null;
    final a = line.substring(0, at).trim();
    final b = line.substring(at + 1).trim();
    if (a.isEmpty || b.isEmpty) return null;
    if (!left.contains(a)) left.add(a);
    if (!right.contains(b)) right.add(b);
    pairs.add([left.indexOf(a), right.indexOf(b)]);
  }
  if (pairs.isEmpty) return null;
  // Listed in sorted order, so the right column doesn't give the pairs away.
  final sorted = [...right]..sort();
  return {
    'left': left,
    'right': sorted,
    'pairs': [
      for (final pair in pairs) [pair[0], sorted.indexOf(right[pair[1]])],
    ],
  };
}

/// The items in their correct order, one per line. Shown sorted, so the list isn't the answer.
Map<String, dynamic>? _orderingSpec(List<String> lines) {
  if (lines.length < 2 || lines.toSet().length != lines.length) return null;
  final items = [...lines]..sort();
  return {
    'items': items,
    'order': [for (final line in lines) items.indexOf(line)],
  };
}

/// [buildAnswerSpec] the other way round, to show a saved answer for editing.
SpecInput specInputOf(String format, Map<String, dynamic>? spec) {
  if (spec == null) return const SpecInput();
  switch (format) {
    case 'multiple_correct':
      return SpecInput(positions: (spec['correct_positions'] as List<dynamic>).cast<int>().toSet());
    case 'numeric':
      return SpecInput(
        value: '${spec['value'] ?? ''}',
        tolerance: '${spec['tolerance'] ?? ''}',
        low: '${spec['min'] ?? ''}',
        high: '${spec['max'] ?? ''}',
      );
    case 'fill_blank':
      return SpecInput(lines: (spec['accepted'] as List<dynamic>).join('\n'));
    case 'match':
      final left = spec['left'] as List<dynamic>;
      final right = spec['right'] as List<dynamic>;
      return SpecInput(
        lines: [
          for (final pair in spec['pairs'] as List<dynamic>)
            '${left[(pair as List<dynamic>)[0] as int]} = ${right[pair[1] as int]}',
        ].join('\n'),
      );
    case 'ordering':
      final items = spec['items'] as List<dynamic>;
      return SpecInput(
        lines: [for (final i in spec['order'] as List<dynamic>) items[i as int]].join('\n'),
      );
  }
  return const SpecInput();
}
