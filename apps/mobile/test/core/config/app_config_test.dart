import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('accepts a development http URL and trims trailing slash', () {
      final config = AppConfig.parse(
        appName: 'PrepLoop',
        apiBaseUrl: 'http://10.0.2.2:8000/',
        flavor: 'development',
      );

      expect(config.apiBaseUrl, 'http://10.0.2.2:8000');
      expect(config.flavor, AppFlavor.development);
    });

    test('rejects http for production', () {
      expect(
        () => AppConfig.parse(
          appName: 'P',
          apiBaseUrl: 'http://api.example.com',
          flavor: 'production',
        ),
        throwsFormatException,
      );
    });

    test('accepts https for production', () {
      final config = AppConfig.parse(
        appName: 'P',
        apiBaseUrl: 'https://api.example.com',
        flavor: 'production',
      );

      expect(config.flavor, AppFlavor.production);
    });

    test('rejects unknown flavor and relative URL', () {
      expect(
        () => AppConfig.parse(appName: 'P', apiBaseUrl: 'https://a.example', flavor: 'qa'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parse(appName: 'P', apiBaseUrl: '/api', flavor: 'development'),
        throwsFormatException,
      );
    });
  });
}
