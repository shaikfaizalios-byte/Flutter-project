import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Records an error. Never pass user content (notes, document text) as [message].
///
/// Goes to the platform log via `dart:developer`; non-release builds also print
/// to the console. A crash-reporting backend can be plugged in here later.
void logError(String message, Object error, [StackTrace? stackTrace]) {
  developer.log(message, name: 'preploop', error: error, stackTrace: stackTrace, level: 1000);
  if (!kReleaseMode) {
    debugPrint('[preploop] $message: $error');
  }
}
