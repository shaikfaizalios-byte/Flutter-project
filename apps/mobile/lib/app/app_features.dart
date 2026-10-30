import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Features that are built but hidden for now. Turn one on here when it becomes useful.
@immutable
class AppFeatures {
  const AppFeatures({this.repeatRadar = false, this.quotes = false, this.learnStart = false});

  /// Repeat Radar ("All learners" in Repeated models, and its sharing card in Profile). It
  /// shows nothing until 2 opted-in learners review the same exam shift, so it stays hidden
  /// until there are enough learners.
  final bool repeatRadar;

  /// Daily quotes on Home and after a focus session.
  final bool quotes;

  /// "How do you want to start?" on Home, Learn / Test me on topic cards and the lesson and
  /// knowledge-check screens. They need PrepLoop Plus, which can't be bought yet, so they stay
  /// hidden until it can (docs/ai.md "Topic lesson").
  final bool learnStart;
}

final appFeaturesProvider = Provider<AppFeatures>((ref) => const AppFeatures());
