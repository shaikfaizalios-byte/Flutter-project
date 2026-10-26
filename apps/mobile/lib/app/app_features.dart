import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Features that are built but hidden for now. Turn one on here when it becomes useful.
@immutable
class AppFeatures {
  const AppFeatures({this.repeatRadar = false, this.quotes = false});

  /// Repeat Radar ("All learners" in Repeated models, and its sharing card in Profile). It
  /// shows nothing until 2 opted-in learners review the same exam shift, so it stays hidden
  /// until there are enough learners.
  final bool repeatRadar;

  /// Daily quotes on Home and after a focus session.
  final bool quotes;
}

final appFeaturesProvider = Provider<AppFeatures>((ref) => const AppFeatures());
