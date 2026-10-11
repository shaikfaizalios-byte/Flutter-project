import 'package:flutter/foundation.dart';

@immutable
class ServerHealth {
  const ServerHealth({required this.version, required this.environment});

  final String version;
  final String environment;
}
