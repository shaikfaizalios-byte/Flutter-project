{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Privacy: never fetch fonts from fonts.gstatic.com (that sends the visitor's IP to Google).
    // The app bundles Roboto and Noto Sans Devanagari; a character no bundled font has is drawn
    // as a box instead of being downloaded. Builds also use --no-web-resources-cdn, so the
    // CanvasKit engine is served from this site rather than www.gstatic.com.
    fontFallbackBaseUrl: 'assets/fonts/fallback/',
  },
});
