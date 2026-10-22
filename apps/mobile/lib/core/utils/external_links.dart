import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] outside the app (the browser); false when nothing could open it.
typedef LinkOpener = Future<bool> Function(Uri uri);

/// Overridden in tests so nothing leaves the app.
final linkOpenerProvider = Provider<LinkOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Longer queries add nothing: Google reads only the first 32 words.
const webSearchMaxLength = 300;

/// A Google search for [query], whitespace collapsed and cut to [webSearchMaxLength].
Uri googleSearchUri(String query) {
  var text = query.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > webSearchMaxLength) text = text.substring(0, webSearchMaxLength).trim();
  return Uri.https('www.google.com', '/search', {'q': text});
}
