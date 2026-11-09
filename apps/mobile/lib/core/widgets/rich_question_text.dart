import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_features.dart';
import '../../app/theme/app_spacing.dart';

/// A piece of question text.
sealed class TextPart {
  const TextPart();
}

class PlainPart extends TextPart {
  const PlainPart(this.text);
  final String text;
}

class MathPart extends TextPart {
  const MathPart(this.tex, {this.display = false});
  final String tex;
  final bool display;
}

class TablePart extends TextPart {
  const TablePart(this.rows);
  final List<List<String>> rows;
}

final _delimited = RegExp(
  r'\$\$(.+?)\$\$|\\\[(.+?)\\\]|\\\((.+?)\\\)|(?<![\\$\w])\$(?![\s$])([^$\n]*?[^\s\\$])\$(?![\d$])|\\ce\{((?:[^{}]|\{[^{}]*\})*)\}',
  dotAll: true,
);
final _chemistry = RegExp(r'\\ce\{((?:[^{}]|\{[^{}]*\})*)\}');
final _tableRule = RegExp(r'^\s*\|?[\s:|-]*-[\s:|-]*\|?\s*$');

/// Splits text into plain text, TeX (`$..$`, `\(..\)` inline; `$$..$$`, `\[..\]` on their own
/// line) and pipe tables. Text is shown as written: a dollar amount such as "$5 and $6" stays
/// text, because TeX can't start before a space or end before a digit.
List<TextPart> splitQuestionText(String text) {
  final known = _parsed.remove(text);
  final parts = known ?? _split(text);
  _parsed[text] = parts; // most recently used last
  if (_parsed.length > _parsedLimit) _parsed.remove(_parsed.keys.first);
  return parts;
}

/// Questions rebuild often (timers, answers), so their text is parsed once.
const _parsedLimit = 300;
final _parsed = <String, List<TextPart>>{};

/// `\ce{...}` chemistry as TeX: `H2O`, `SO4^2-`, `2H2 + O2 -> 2H2O`, `N2 + 3H2 <=> 2NH3`.
String ceToTex(String formula) {
  var tex = formula.trim();
  tex = tex.replaceAll('<=>', r' \rightleftharpoons ');
  tex = tex.replaceAll('<-', r' \leftarrow ').replaceAll('->', r' \rightarrow ');
  tex = tex.replaceAllMapped(RegExp(r'([A-Za-z)\]])(\d+)'), (m) => '${m[1]}_{${m[2]}}');
  tex = tex.replaceAllMapped(RegExp(r'\^(?!\{)(\d*[+-])'), (m) => '^{${m[1]}}');
  tex = tex.trim().replaceAll(RegExp(r'\s+'), r'\ ');
  return '\\mathrm{$tex}';
}

List<TextPart> _split(String text) {
  final parts = <TextPart>[];
  void math(String block) {
    var at = 0;
    for (final match in _delimited.allMatches(block)) {
      if (match.start > at) parts.add(PlainPart(block.substring(at, match.start)));
      final display = match.group(1) ?? match.group(2);
      final inline = match.group(3) ?? match.group(4);
      final tex = match.group(5) != null
          ? ceToTex(match.group(5)!)
          : (display ?? inline)!.trim().replaceAllMapped(_chemistry, (m) => ceToTex(m[1]!));
      parts.add(MathPart(tex, display: display != null));
      at = match.end;
    }
    if (at < block.length) parts.add(PlainPart(block.substring(at)));
  }

  final lines = text.split('\n');
  final plain = <String>[];
  void flush() {
    if (plain.isNotEmpty) math(plain.join('\n'));
    plain.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final isTable =
        lines[i].contains('|') && i + 1 < lines.length && _tableRule.hasMatch(lines[i + 1]);
    if (!isTable) {
      plain.add(lines[i++]);
      continue;
    }
    flush();
    final rows = [_cells(lines[i])];
    i += 2;
    while (i < lines.length && lines[i].contains('|')) {
      rows.add(_cells(lines[i++]));
    }
    parts.add(TablePart(rows));
  }
  flush();
  return parts;
}

List<String> _cells(String line) {
  var row = line.trim();
  if (row.startsWith('|')) row = row.substring(1);
  if (row.endsWith('|')) row = row.substring(0, row.length - 1);
  return [for (final cell in row.split('|')) cell.trim()];
}

/// Question, option or solution text with maths and tables. Without [AppFeatures.examProfiles],
/// or when the text has neither, it is the plain selectable text it always was.
class RichQuestionText extends ConsumerWidget {
  const RichQuestionText(this.text, {this.style, this.selectable = true, super.key});

  final String text;
  final TextStyle? style;

  /// False inside something tappable, such as an option: selection would take the tap.
  final bool selectable;

  Widget _plain() => selectable ? SelectableText(text, style: style) : Text(text, style: style);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appFeaturesProvider).examProfiles) return _plain();
    final parts = splitQuestionText(text);
    if (parts.every((p) => p is PlainPart)) return _plain();
    final base = style ?? DefaultTextStyle.of(context).style;
    final blocks = <Widget>[];
    var inline = <InlineSpan>[];
    void endLine() {
      if (inline.isEmpty) return;
      blocks.add(Text.rich(TextSpan(children: inline), style: base));
      inline = [];
    }

    for (final part in parts) {
      switch (part) {
        case PlainPart(:final text):
          inline.add(TextSpan(text: text));
        case MathPart(:final tex, display: false):
          inline.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _Tex(tex, style: base, mathStyle: MathStyle.text),
            ),
          );
        case MathPart(:final tex):
          endLine();
          blocks.add(
            RepaintBoundary(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _Tex(tex, style: base, mathStyle: MathStyle.display),
              ),
            ),
          );
        case TablePart(:final rows):
          endLine();
          blocks.add(_QuestionTable(rows: rows, style: base));
      }
    }
    endLine();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: blocks,
    );
  }
}

class _Tex extends StatelessWidget {
  const _Tex(this.tex, {required this.style, required this.mathStyle});

  final String tex;
  final TextStyle style;
  final MathStyle mathStyle;

  @override
  Widget build(BuildContext context) => Math.tex(
    tex,
    mathStyle: mathStyle,
    textStyle: style,
    // TeX that can't be read is shown as written, never dropped.
    onErrorFallback: (_) => Text(tex, style: style),
  );
}

class _QuestionTable extends StatelessWidget {
  const _QuestionTable({required this.rows, required this.style});

  final List<List<String>> rows;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: Theme.of(context).dividerColor),
        children: [
          for (final (index, row) in rows.indexed)
            TableRow(
              children: [
                for (var c = 0; c < columns; c++)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Text(
                      c < row.length ? row[c] : '',
                      style: index == 0 ? style.copyWith(fontWeight: FontWeight.w600) : style,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
