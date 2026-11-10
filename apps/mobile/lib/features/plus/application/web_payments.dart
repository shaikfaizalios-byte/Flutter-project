import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';

/// Plus is paid for on the website only: the Android app uses Google Play, as Play requires.
final webPaymentsSupportedProvider = Provider<bool>((ref) => kIsWeb);

/// Opens Paytm's payment page in this browser tab (the learner comes back to the app after).
/// Overridden in tests so nothing leaves the app.
final paymentPageOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri, webOnlyWindowName: '_self'),
);

/// The payment page link on the API's address.
Uri paymentPageUri(AppConfig config, String payPath) =>
    Uri.parse(config.apiBaseUrl).resolve(payPath);
