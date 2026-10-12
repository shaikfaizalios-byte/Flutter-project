import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _load(String locale) =>
    jsonDecode(File('lib/core/localization/arb/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// `{name}` placeholders used in a message, ignoring ICU plural/select bodies.
Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)(?=[,}])').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final en = _load('en');
  final hi = _load('hi');

  test('English and Hindi define exactly the same messages', () {
    expect(_messageKeys(hi).difference(_messageKeys(en)), isEmpty, reason: 'extra in Hindi');
    expect(_messageKeys(en).difference(_messageKeys(hi)), isEmpty, reason: 'missing in Hindi');
  });

  test('translations keep the same placeholders', () {
    for (final key in _messageKeys(en)) {
      expect(
        _placeholders(hi[key]! as String),
        _placeholders(en[key]! as String),
        reason: 'placeholders differ for "$key"',
      );
    }
  });

  test('no message is empty', () {
    for (final arb in [en, hi]) {
      for (final key in _messageKeys(arb)) {
        expect((arb[key]! as String).trim(), isNotEmpty, reason: key);
      }
    }
  });
}
