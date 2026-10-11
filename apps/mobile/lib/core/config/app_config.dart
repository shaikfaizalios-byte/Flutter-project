import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppFlavor { development, staging, production }

/// Build-time configuration, supplied with `--dart-define` (or
/// `--dart-define-from-file`). Never put secrets here: anything compiled into
/// the app can be extracted from it.
class AppConfig {
  const AppConfig({required this.appName, required this.apiBaseUrl, required this.flavor});

  factory AppConfig.fromEnvironment() => AppConfig.parse(
    appName: const String.fromEnvironment('APP_NAME', defaultValue: 'PrepLoop'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000'),
    flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'development'),
  );

  /// Validates raw values. Throws [FormatException] for invalid configuration
  /// so a misconfigured build fails at startup instead of misbehaving later.
  factory AppConfig.parse({
    required String appName,
    required String apiBaseUrl,
    required String flavor,
  }) {
    final parsedFlavor = AppFlavor.values.asNameMap()[flavor];
    if (parsedFlavor == null) {
      throw FormatException('Unknown FLAVOR "$flavor".');
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('API_BASE_URL "$apiBaseUrl" is not an absolute URL.');
    }
    if (parsedFlavor != AppFlavor.development && uri.scheme != 'https') {
      throw FormatException('API_BASE_URL must use https for ${parsedFlavor.name} builds.');
    }
    final normalizedUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return AppConfig(appName: appName, apiBaseUrl: normalizedUrl, flavor: parsedFlavor);
  }

  final String appName;
  final String apiBaseUrl;
  final AppFlavor flavor;
}

/// Overridden in `bootstrap()` (and in tests).
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden.'),
);
