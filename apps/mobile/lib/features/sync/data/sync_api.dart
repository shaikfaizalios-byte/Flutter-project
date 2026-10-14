import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';

/// One record change, as exchanged with the server.
@immutable
class SyncChange {
  const SyncChange({required this.entity, required this.id, this.deleted = false, this.data});

  factory SyncChange.fromJson(Map<String, dynamic> json) => SyncChange(
    entity: json['entity'] as String,
    id: json['id'] as String,
    deleted: json['deleted'] as bool,
    data: json['data'] as Map<String, dynamic>?,
  );

  final String entity;
  final String id;
  final bool deleted;
  final Map<String, dynamic>? data;

  String get key => '$entity:$id';

  Map<String, Object?> toJson() => {
    'entity': entity,
    'id': id,
    'deleted': deleted,
    if (data != null) 'data': data,
  };
}

@immutable
class PushOutcome {
  const PushOutcome({
    required this.accepted,
    this.ignoredDeleted = const [],
    this.rejected = const {},
  });

  final int accepted;

  /// `entity:id` keys the server kept deleted (a delete elsewhere wins).
  final List<String> ignoredDeleted;

  /// `entity:id` → reason. These are dropped, not retried.
  final Map<String, String> rejected;
}

@immutable
class PullPage {
  const PullPage({required this.changes, required this.cursor, required this.hasMore});

  final List<SyncChange> changes;
  final int cursor;
  final bool hasMore;
}

/// The server's sync endpoints. Tests use a fake.
abstract interface class SyncApi {
  Future<PushOutcome> push(List<SyncChange> changes);

  Future<PullPage> pull(int cursor);
}

class RemoteSyncApi implements SyncApi {
  RemoteSyncApi(this._dio);

  final Dio _dio;

  @override
  Future<PushOutcome> push(List<SyncChange> changes) => _guard(() async {
    final data = (await _dio.post<Map<String, dynamic>>(
      '/api/v1/sync/push',
      data: {
        'changes': [for (final c in changes) c.toJson()],
      },
    )).data!;
    return PushOutcome(
      accepted: data['accepted'] as int,
      ignoredDeleted: (data['ignored_deleted'] as List<dynamic>).cast<String>(),
      rejected: (data['rejected'] as Map<String, dynamic>).cast<String, String>(),
    );
  });

  @override
  Future<PullPage> pull(int cursor) => _guard(() async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/api/v1/sync/pull',
      queryParameters: {'cursor': cursor},
    )).data!;
    return PullPage(
      changes: [
        for (final c in data['changes'] as List<dynamic>)
          SyncChange.fromJson(c as Map<String, dynamic>),
      ],
      cursor: data['cursor'] as int,
      hasMore: data['has_more'] as bool,
    );
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
