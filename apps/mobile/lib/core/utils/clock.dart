import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time. Override in tests to make date-dependent UI deterministic.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
