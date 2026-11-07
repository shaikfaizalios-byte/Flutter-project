import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Features that are built but hidden for now. Turn one on here when it becomes useful.
@immutable
class AppFeatures {
  const AppFeatures({
    this.repeatRadar = false,
    this.quotes = false,
    this.learnStart = false,
    this.examProfiles = false,
  });

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

  /// The custom exam builder and the "What are you preparing for?" wording in onboarding. Off
  /// until the any-exam work is complete (docs/any-exam).
  final bool examProfiles;
}

/// `--dart-define=LEARN_START=true` turns lessons and knowledge checks on in a local test build.
/// `--dart-define=EXAM_PROFILES=true` turns the exam builder on.
final appFeaturesProvider = Provider<AppFeatures>(
  (ref) => const AppFeatures(
    learnStart: bool.fromEnvironment('LEARN_START'),
    examProfiles: bool.fromEnvironment('EXAM_PROFILES'),
  ),
);
