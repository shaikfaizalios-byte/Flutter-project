/// Text as shown on screen. Some papers' PDFs give letters of an equation as Unicode
/// "mathematical" letters (italic x is U+1D465, bold A is U+1D400) that the app's fonts can't
/// draw, so they show as boxes. On screen they are shown as the plain letter or digit they stand
/// for; the stored text is never changed (what a learner edits and saves is still theirs).
String displayText(String text) {
  if (!_hasMath.hasMatch(text)) return text;
  final out = StringBuffer();
  for (final rune in text.runes) {
    out.writeCharCode(_plain(rune));
  }
  return out.toString();
}

final _hasMath = RegExp('[\u{1D400}-\u{1D7FF}\u{210E}]', unicode: true);

int _plain(int rune) {
  // Letters: 13 styles (bold, italic, script, ...) of A-Z then a-z, 52 each.
  if (rune >= 0x1D400 && rune <= 0x1D6A3) {
    final i = (rune - 0x1D400) % 52;
    return i < 26 ? 0x41 + i : 0x61 + i - 26;
  }
  // Digits: 5 styles of 0-9.
  if (rune >= 0x1D7CE && rune <= 0x1D7FF) return 0x30 + (rune - 0x1D7CE) % 10;
  if (rune == 0x210E) return 0x68; // PLANCK CONSTANT stands in for italic h
  return rune; // Greek and other symbols: as found
}
