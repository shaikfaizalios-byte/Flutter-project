// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ConceptsTable extends Concepts with TableInfo<$ConceptsTable, ConceptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConceptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examCodeMeta = const VerificationMeta('examCode');
  @override
  late final GeneratedColumn<String> examCode = GeneratedColumn<String>(
    'exam_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 32),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtopicMeta = const VerificationMeta('subtopic');
  @override
  late final GeneratedColumn<String> subtopic = GeneratedColumn<String>(
    'subtopic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 2, maxTextLength: 8),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($ConceptsTable.$convertertags);
  static const VerificationMeta _sourceReferenceMeta = const VerificationMeta('sourceReference');
  @override
  late final GeneratedColumn<String> sourceReference = GeneratedColumn<String>(
    'source_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta('archivedAt');
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examCode,
    title,
    notes,
    subject,
    topic,
    subtopic,
    language,
    tags,
    sourceReference,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'concepts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConceptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exam_code')) {
      context.handle(
        _examCodeMeta,
        examCode.isAcceptableOrUnknown(data['exam_code']!, _examCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_examCodeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta, subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(_topicMeta, topic.isAcceptableOrUnknown(data['topic']!, _topicMeta));
    } else if (isInserting) {
      context.missing(_topicMeta);
    }
    if (data.containsKey('subtopic')) {
      context.handle(
        _subtopicMeta,
        subtopic.isAcceptableOrUnknown(data['subtopic']!, _subtopicMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('source_reference')) {
      context.handle(
        _sourceReferenceMeta,
        sourceReference.isAcceptableOrUnknown(data['source_reference']!, _sourceReferenceMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConceptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConceptRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      examCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_code'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      )!,
      subtopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtopic'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      tags: $ConceptsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      ),
      sourceReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_reference'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConceptsTable createAlias(String alias) {
    return $ConceptsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags = const StringListConverter();
}

class ConceptRow extends DataClass implements Insertable<ConceptRow> {
  final String id;
  final String examCode;
  final String title;
  final String notes;
  final String subject;
  final String topic;
  final String? subtopic;
  final String language;
  final List<String> tags;
  final String? sourceReference;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConceptRow({
    required this.id,
    required this.examCode,
    required this.title,
    required this.notes,
    required this.subject,
    required this.topic,
    this.subtopic,
    required this.language,
    required this.tags,
    this.sourceReference,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exam_code'] = Variable<String>(examCode);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    map['subject'] = Variable<String>(subject);
    map['topic'] = Variable<String>(topic);
    if (!nullToAbsent || subtopic != null) {
      map['subtopic'] = Variable<String>(subtopic);
    }
    map['language'] = Variable<String>(language);
    {
      map['tags'] = Variable<String>($ConceptsTable.$convertertags.toSql(tags));
    }
    if (!nullToAbsent || sourceReference != null) {
      map['source_reference'] = Variable<String>(sourceReference);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConceptsCompanion toCompanion(bool nullToAbsent) {
    return ConceptsCompanion(
      id: Value(id),
      examCode: Value(examCode),
      title: Value(title),
      notes: Value(notes),
      subject: Value(subject),
      topic: Value(topic),
      subtopic: subtopic == null && nullToAbsent ? const Value.absent() : Value(subtopic),
      language: Value(language),
      tags: Value(tags),
      sourceReference: sourceReference == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceReference),
      archivedAt: archivedAt == null && nullToAbsent ? const Value.absent() : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConceptRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConceptRow(
      id: serializer.fromJson<String>(json['id']),
      examCode: serializer.fromJson<String>(json['examCode']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      subject: serializer.fromJson<String>(json['subject']),
      topic: serializer.fromJson<String>(json['topic']),
      subtopic: serializer.fromJson<String?>(json['subtopic']),
      language: serializer.fromJson<String>(json['language']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      sourceReference: serializer.fromJson<String?>(json['sourceReference']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'examCode': serializer.toJson<String>(examCode),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'subject': serializer.toJson<String>(subject),
      'topic': serializer.toJson<String>(topic),
      'subtopic': serializer.toJson<String?>(subtopic),
      'language': serializer.toJson<String>(language),
      'tags': serializer.toJson<List<String>>(tags),
      'sourceReference': serializer.toJson<String?>(sourceReference),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConceptRow copyWith({
    String? id,
    String? examCode,
    String? title,
    String? notes,
    String? subject,
    String? topic,
    Value<String?> subtopic = const Value.absent(),
    String? language,
    List<String>? tags,
    Value<String?> sourceReference = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConceptRow(
    id: id ?? this.id,
    examCode: examCode ?? this.examCode,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    subject: subject ?? this.subject,
    topic: topic ?? this.topic,
    subtopic: subtopic.present ? subtopic.value : this.subtopic,
    language: language ?? this.language,
    tags: tags ?? this.tags,
    sourceReference: sourceReference.present ? sourceReference.value : this.sourceReference,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConceptRow copyWithCompanion(ConceptsCompanion data) {
    return ConceptRow(
      id: data.id.present ? data.id.value : this.id,
      examCode: data.examCode.present ? data.examCode.value : this.examCode,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      subject: data.subject.present ? data.subject.value : this.subject,
      topic: data.topic.present ? data.topic.value : this.topic,
      subtopic: data.subtopic.present ? data.subtopic.value : this.subtopic,
      language: data.language.present ? data.language.value : this.language,
      tags: data.tags.present ? data.tags.value : this.tags,
      sourceReference: data.sourceReference.present
          ? data.sourceReference.value
          : this.sourceReference,
      archivedAt: data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConceptRow(')
          ..write('id: $id, ')
          ..write('examCode: $examCode, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('subject: $subject, ')
          ..write('topic: $topic, ')
          ..write('subtopic: $subtopic, ')
          ..write('language: $language, ')
          ..write('tags: $tags, ')
          ..write('sourceReference: $sourceReference, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    examCode,
    title,
    notes,
    subject,
    topic,
    subtopic,
    language,
    tags,
    sourceReference,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConceptRow &&
          other.id == this.id &&
          other.examCode == this.examCode &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.subject == this.subject &&
          other.topic == this.topic &&
          other.subtopic == this.subtopic &&
          other.language == this.language &&
          other.tags == this.tags &&
          other.sourceReference == this.sourceReference &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConceptsCompanion extends UpdateCompanion<ConceptRow> {
  final Value<String> id;
  final Value<String> examCode;
  final Value<String> title;
  final Value<String> notes;
  final Value<String> subject;
  final Value<String> topic;
  final Value<String?> subtopic;
  final Value<String> language;
  final Value<List<String>> tags;
  final Value<String?> sourceReference;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConceptsCompanion({
    this.id = const Value.absent(),
    this.examCode = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.subject = const Value.absent(),
    this.topic = const Value.absent(),
    this.subtopic = const Value.absent(),
    this.language = const Value.absent(),
    this.tags = const Value.absent(),
    this.sourceReference = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConceptsCompanion.insert({
    required String id,
    required String examCode,
    required String title,
    this.notes = const Value.absent(),
    required String subject,
    required String topic,
    this.subtopic = const Value.absent(),
    required String language,
    this.tags = const Value.absent(),
    this.sourceReference = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       examCode = Value(examCode),
       title = Value(title),
       subject = Value(subject),
       topic = Value(topic),
       language = Value(language),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConceptRow> custom({
    Expression<String>? id,
    Expression<String>? examCode,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? subject,
    Expression<String>? topic,
    Expression<String>? subtopic,
    Expression<String>? language,
    Expression<String>? tags,
    Expression<String>? sourceReference,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examCode != null) 'exam_code': examCode,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (subject != null) 'subject': subject,
      if (topic != null) 'topic': topic,
      if (subtopic != null) 'subtopic': subtopic,
      if (language != null) 'language': language,
      if (tags != null) 'tags': tags,
      if (sourceReference != null) 'source_reference': sourceReference,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConceptsCompanion copyWith({
    Value<String>? id,
    Value<String>? examCode,
    Value<String>? title,
    Value<String>? notes,
    Value<String>? subject,
    Value<String>? topic,
    Value<String?>? subtopic,
    Value<String>? language,
    Value<List<String>>? tags,
    Value<String?>? sourceReference,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConceptsCompanion(
      id: id ?? this.id,
      examCode: examCode ?? this.examCode,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      subtopic: subtopic ?? this.subtopic,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      sourceReference: sourceReference ?? this.sourceReference,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (examCode.present) {
      map['exam_code'] = Variable<String>(examCode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (subtopic.present) {
      map['subtopic'] = Variable<String>(subtopic.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>($ConceptsTable.$convertertags.toSql(tags.value));
    }
    if (sourceReference.present) {
      map['source_reference'] = Variable<String>(sourceReference.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConceptsCompanion(')
          ..write('id: $id, ')
          ..write('examCode: $examCode, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('subject: $subject, ')
          ..write('topic: $topic, ')
          ..write('subtopic: $subtopic, ')
          ..write('language: $language, ')
          ..write('tags: $tags, ')
          ..write('sourceReference: $sourceReference, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  const AppSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSettingRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingRow copyWith({String? key, String? value}) =>
      AppSettingRow(key: key ?? this.key, value: value ?? this.value);
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow && other.key == this.key && other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyProfilesTable extends StudyProfiles
    with TableInfo<$StudyProfilesTable, StudyProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> examCodes =
      GeneratedColumn<String>(
        'exam_codes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($StudyProfilesTable.$converterexamCodes);
  static const VerificationMeta _targetExamDateMeta = const VerificationMeta('targetExamDate');
  @override
  late final GeneratedColumn<String> targetExamDate = GeneratedColumn<String>(
    'target_exam_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyStudyMinutesMeta = const VerificationMeta(
    'dailyStudyMinutes',
  );
  @override
  late final GeneratedColumn<int> dailyStudyMinutes = GeneratedColumn<int>(
    'daily_study_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta('reminderMinutes');
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onboardingCompletedAtMeta = const VerificationMeta(
    'onboardingCompletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> onboardingCompletedAt = GeneratedColumn<DateTime>(
    'onboarding_completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examCodes,
    targetExamDate,
    dailyStudyMinutes,
    reminderMinutes,
    onboardingCompletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_exam_date')) {
      context.handle(
        _targetExamDateMeta,
        targetExamDate.isAcceptableOrUnknown(data['target_exam_date']!, _targetExamDateMeta),
      );
    }
    if (data.containsKey('daily_study_minutes')) {
      context.handle(
        _dailyStudyMinutesMeta,
        dailyStudyMinutes.isAcceptableOrUnknown(
          data['daily_study_minutes']!,
          _dailyStudyMinutesMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(data['reminder_minutes']!, _reminderMinutesMeta),
      );
    }
    if (data.containsKey('onboarding_completed_at')) {
      context.handle(
        _onboardingCompletedAtMeta,
        onboardingCompletedAt.isAcceptableOrUnknown(
          data['onboarding_completed_at']!,
          _onboardingCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudyProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyProfileRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      examCodes: $StudyProfilesTable.$converterexamCodes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exam_codes'],
        )!,
      ),
      targetExamDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_exam_date'],
      ),
      dailyStudyMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_study_minutes'],
      ),
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      onboardingCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}onboarding_completed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StudyProfilesTable createAlias(String alias) {
    return $StudyProfilesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterexamCodes = const StringListConverter();
}

class StudyProfileRow extends DataClass implements Insertable<StudyProfileRow> {
  final int id;

  /// Selected exam codes as a JSON array; empty means "not chosen yet".
  final List<String> examCodes;

  /// Calendar date `yyyy-MM-dd` (no time or timezone, so it never shifts).
  final String? targetExamDate;
  final int? dailyStudyMinutes;

  /// Local wall-clock time as minutes after midnight (0–1439).
  final int? reminderMinutes;
  final DateTime? onboardingCompletedAt;
  final DateTime updatedAt;
  const StudyProfileRow({
    required this.id,
    required this.examCodes,
    this.targetExamDate,
    this.dailyStudyMinutes,
    this.reminderMinutes,
    this.onboardingCompletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['exam_codes'] = Variable<String>(
        $StudyProfilesTable.$converterexamCodes.toSql(examCodes),
      );
    }
    if (!nullToAbsent || targetExamDate != null) {
      map['target_exam_date'] = Variable<String>(targetExamDate);
    }
    if (!nullToAbsent || dailyStudyMinutes != null) {
      map['daily_study_minutes'] = Variable<int>(dailyStudyMinutes);
    }
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    if (!nullToAbsent || onboardingCompletedAt != null) {
      map['onboarding_completed_at'] = Variable<DateTime>(onboardingCompletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudyProfilesCompanion toCompanion(bool nullToAbsent) {
    return StudyProfilesCompanion(
      id: Value(id),
      examCodes: Value(examCodes),
      targetExamDate: targetExamDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetExamDate),
      dailyStudyMinutes: dailyStudyMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyStudyMinutes),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      onboardingCompletedAt: onboardingCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(onboardingCompletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StudyProfileRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyProfileRow(
      id: serializer.fromJson<int>(json['id']),
      examCodes: serializer.fromJson<List<String>>(json['examCodes']),
      targetExamDate: serializer.fromJson<String?>(json['targetExamDate']),
      dailyStudyMinutes: serializer.fromJson<int?>(json['dailyStudyMinutes']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      onboardingCompletedAt: serializer.fromJson<DateTime?>(json['onboardingCompletedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'examCodes': serializer.toJson<List<String>>(examCodes),
      'targetExamDate': serializer.toJson<String?>(targetExamDate),
      'dailyStudyMinutes': serializer.toJson<int?>(dailyStudyMinutes),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'onboardingCompletedAt': serializer.toJson<DateTime?>(onboardingCompletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StudyProfileRow copyWith({
    int? id,
    List<String>? examCodes,
    Value<String?> targetExamDate = const Value.absent(),
    Value<int?> dailyStudyMinutes = const Value.absent(),
    Value<int?> reminderMinutes = const Value.absent(),
    Value<DateTime?> onboardingCompletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => StudyProfileRow(
    id: id ?? this.id,
    examCodes: examCodes ?? this.examCodes,
    targetExamDate: targetExamDate.present ? targetExamDate.value : this.targetExamDate,
    dailyStudyMinutes: dailyStudyMinutes.present ? dailyStudyMinutes.value : this.dailyStudyMinutes,
    reminderMinutes: reminderMinutes.present ? reminderMinutes.value : this.reminderMinutes,
    onboardingCompletedAt: onboardingCompletedAt.present
        ? onboardingCompletedAt.value
        : this.onboardingCompletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StudyProfileRow copyWithCompanion(StudyProfilesCompanion data) {
    return StudyProfileRow(
      id: data.id.present ? data.id.value : this.id,
      examCodes: data.examCodes.present ? data.examCodes.value : this.examCodes,
      targetExamDate: data.targetExamDate.present ? data.targetExamDate.value : this.targetExamDate,
      dailyStudyMinutes: data.dailyStudyMinutes.present
          ? data.dailyStudyMinutes.value
          : this.dailyStudyMinutes,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      onboardingCompletedAt: data.onboardingCompletedAt.present
          ? data.onboardingCompletedAt.value
          : this.onboardingCompletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyProfileRow(')
          ..write('id: $id, ')
          ..write('examCodes: $examCodes, ')
          ..write('targetExamDate: $targetExamDate, ')
          ..write('dailyStudyMinutes: $dailyStudyMinutes, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    examCodes,
    targetExamDate,
    dailyStudyMinutes,
    reminderMinutes,
    onboardingCompletedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyProfileRow &&
          other.id == this.id &&
          other.examCodes == this.examCodes &&
          other.targetExamDate == this.targetExamDate &&
          other.dailyStudyMinutes == this.dailyStudyMinutes &&
          other.reminderMinutes == this.reminderMinutes &&
          other.onboardingCompletedAt == this.onboardingCompletedAt &&
          other.updatedAt == this.updatedAt);
}

class StudyProfilesCompanion extends UpdateCompanion<StudyProfileRow> {
  final Value<int> id;
  final Value<List<String>> examCodes;
  final Value<String?> targetExamDate;
  final Value<int?> dailyStudyMinutes;
  final Value<int?> reminderMinutes;
  final Value<DateTime?> onboardingCompletedAt;
  final Value<DateTime> updatedAt;
  const StudyProfilesCompanion({
    this.id = const Value.absent(),
    this.examCodes = const Value.absent(),
    this.targetExamDate = const Value.absent(),
    this.dailyStudyMinutes = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StudyProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.examCodes = const Value.absent(),
    this.targetExamDate = const Value.absent(),
    this.dailyStudyMinutes = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<StudyProfileRow> custom({
    Expression<int>? id,
    Expression<String>? examCodes,
    Expression<String>? targetExamDate,
    Expression<int>? dailyStudyMinutes,
    Expression<int>? reminderMinutes,
    Expression<DateTime>? onboardingCompletedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examCodes != null) 'exam_codes': examCodes,
      if (targetExamDate != null) 'target_exam_date': targetExamDate,
      if (dailyStudyMinutes != null) 'daily_study_minutes': dailyStudyMinutes,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (onboardingCompletedAt != null) 'onboarding_completed_at': onboardingCompletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StudyProfilesCompanion copyWith({
    Value<int>? id,
    Value<List<String>>? examCodes,
    Value<String?>? targetExamDate,
    Value<int?>? dailyStudyMinutes,
    Value<int?>? reminderMinutes,
    Value<DateTime?>? onboardingCompletedAt,
    Value<DateTime>? updatedAt,
  }) {
    return StudyProfilesCompanion(
      id: id ?? this.id,
      examCodes: examCodes ?? this.examCodes,
      targetExamDate: targetExamDate ?? this.targetExamDate,
      dailyStudyMinutes: dailyStudyMinutes ?? this.dailyStudyMinutes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (examCodes.present) {
      map['exam_codes'] = Variable<String>(
        $StudyProfilesTable.$converterexamCodes.toSql(examCodes.value),
      );
    }
    if (targetExamDate.present) {
      map['target_exam_date'] = Variable<String>(targetExamDate.value);
    }
    if (dailyStudyMinutes.present) {
      map['daily_study_minutes'] = Variable<int>(dailyStudyMinutes.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (onboardingCompletedAt.present) {
      map['onboarding_completed_at'] = Variable<DateTime>(onboardingCompletedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyProfilesCompanion(')
          ..write('id: $id, ')
          ..write('examCodes: $examCodes, ')
          ..write('targetExamDate: $targetExamDate, ')
          ..write('dailyStudyMinutes: $dailyStudyMinutes, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PendingAnswersTable extends PendingAnswers
    with TableInfo<$PendingAnswersTable, PendingAnswerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedPositionMeta = const VerificationMeta('selectedPosition');
  @override
  late final GeneratedColumn<int> selectedPosition = GeneratedColumn<int>(
    'selected_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typedAnswerMeta = const VerificationMeta('typedAnswer');
  @override
  late final GeneratedColumn<String> typedAnswer = GeneratedColumn<String>(
    'typed_answer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientSeqMeta = const VerificationMeta('clientSeq');
  @override
  late final GeneratedColumn<int> clientSeq = GeneratedColumn<int>(
    'client_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeSpentMsMeta = const VerificationMeta('timeSpentMs');
  @override
  late final GeneratedColumn<int> timeSpentMs = GeneratedColumn<int>(
    'time_spent_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    position,
    selectedPosition,
    typedAnswer,
    clientSeq,
    timeSpentMs,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_answers';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAnswerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('selected_position')) {
      context.handle(
        _selectedPositionMeta,
        selectedPosition.isAcceptableOrUnknown(data['selected_position']!, _selectedPositionMeta),
      );
    }
    if (data.containsKey('typed_answer')) {
      context.handle(
        _typedAnswerMeta,
        typedAnswer.isAcceptableOrUnknown(data['typed_answer']!, _typedAnswerMeta),
      );
    }
    if (data.containsKey('client_seq')) {
      context.handle(
        _clientSeqMeta,
        clientSeq.isAcceptableOrUnknown(data['client_seq']!, _clientSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_clientSeqMeta);
    }
    if (data.containsKey('time_spent_ms')) {
      context.handle(
        _timeSpentMsMeta,
        timeSpentMs.isAcceptableOrUnknown(data['time_spent_ms']!, _timeSpentMsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, position};
  @override
  PendingAnswerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAnswerRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      selectedPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selected_position'],
      ),
      typedAnswer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}typed_answer'],
      ),
      clientSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_seq'],
      )!,
      timeSpentMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_spent_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingAnswersTable createAlias(String alias) {
    return $PendingAnswersTable(attachedDatabase, alias);
  }
}

class PendingAnswerRow extends DataClass implements Insertable<PendingAnswerRow> {
  final String sessionId;
  final int position;

  /// Null clears the answer.
  final int? selectedPosition;

  /// The answer of a typed-in question (instead of [selectedPosition]). Added in schema v6.
  final String? typedAnswer;

  /// Monotonic per device; the server ignores updates older than the one it has.
  final int clientSeq;
  final int? timeSpentMs;
  final DateTime createdAt;
  const PendingAnswerRow({
    required this.sessionId,
    required this.position,
    this.selectedPosition,
    this.typedAnswer,
    required this.clientSeq,
    this.timeSpentMs,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || selectedPosition != null) {
      map['selected_position'] = Variable<int>(selectedPosition);
    }
    if (!nullToAbsent || typedAnswer != null) {
      map['typed_answer'] = Variable<String>(typedAnswer);
    }
    map['client_seq'] = Variable<int>(clientSeq);
    if (!nullToAbsent || timeSpentMs != null) {
      map['time_spent_ms'] = Variable<int>(timeSpentMs);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingAnswersCompanion toCompanion(bool nullToAbsent) {
    return PendingAnswersCompanion(
      sessionId: Value(sessionId),
      position: Value(position),
      selectedPosition: selectedPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedPosition),
      typedAnswer: typedAnswer == null && nullToAbsent ? const Value.absent() : Value(typedAnswer),
      clientSeq: Value(clientSeq),
      timeSpentMs: timeSpentMs == null && nullToAbsent ? const Value.absent() : Value(timeSpentMs),
      createdAt: Value(createdAt),
    );
  }

  factory PendingAnswerRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAnswerRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      position: serializer.fromJson<int>(json['position']),
      selectedPosition: serializer.fromJson<int?>(json['selectedPosition']),
      typedAnswer: serializer.fromJson<String?>(json['typedAnswer']),
      clientSeq: serializer.fromJson<int>(json['clientSeq']),
      timeSpentMs: serializer.fromJson<int?>(json['timeSpentMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'position': serializer.toJson<int>(position),
      'selectedPosition': serializer.toJson<int?>(selectedPosition),
      'typedAnswer': serializer.toJson<String?>(typedAnswer),
      'clientSeq': serializer.toJson<int>(clientSeq),
      'timeSpentMs': serializer.toJson<int?>(timeSpentMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingAnswerRow copyWith({
    String? sessionId,
    int? position,
    Value<int?> selectedPosition = const Value.absent(),
    Value<String?> typedAnswer = const Value.absent(),
    int? clientSeq,
    Value<int?> timeSpentMs = const Value.absent(),
    DateTime? createdAt,
  }) => PendingAnswerRow(
    sessionId: sessionId ?? this.sessionId,
    position: position ?? this.position,
    selectedPosition: selectedPosition.present ? selectedPosition.value : this.selectedPosition,
    typedAnswer: typedAnswer.present ? typedAnswer.value : this.typedAnswer,
    clientSeq: clientSeq ?? this.clientSeq,
    timeSpentMs: timeSpentMs.present ? timeSpentMs.value : this.timeSpentMs,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingAnswerRow copyWithCompanion(PendingAnswersCompanion data) {
    return PendingAnswerRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      position: data.position.present ? data.position.value : this.position,
      selectedPosition: data.selectedPosition.present
          ? data.selectedPosition.value
          : this.selectedPosition,
      typedAnswer: data.typedAnswer.present ? data.typedAnswer.value : this.typedAnswer,
      clientSeq: data.clientSeq.present ? data.clientSeq.value : this.clientSeq,
      timeSpentMs: data.timeSpentMs.present ? data.timeSpentMs.value : this.timeSpentMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAnswerRow(')
          ..write('sessionId: $sessionId, ')
          ..write('position: $position, ')
          ..write('selectedPosition: $selectedPosition, ')
          ..write('typedAnswer: $typedAnswer, ')
          ..write('clientSeq: $clientSeq, ')
          ..write('timeSpentMs: $timeSpentMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    position,
    selectedPosition,
    typedAnswer,
    clientSeq,
    timeSpentMs,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAnswerRow &&
          other.sessionId == this.sessionId &&
          other.position == this.position &&
          other.selectedPosition == this.selectedPosition &&
          other.typedAnswer == this.typedAnswer &&
          other.clientSeq == this.clientSeq &&
          other.timeSpentMs == this.timeSpentMs &&
          other.createdAt == this.createdAt);
}

class PendingAnswersCompanion extends UpdateCompanion<PendingAnswerRow> {
  final Value<String> sessionId;
  final Value<int> position;
  final Value<int?> selectedPosition;
  final Value<String?> typedAnswer;
  final Value<int> clientSeq;
  final Value<int?> timeSpentMs;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingAnswersCompanion({
    this.sessionId = const Value.absent(),
    this.position = const Value.absent(),
    this.selectedPosition = const Value.absent(),
    this.typedAnswer = const Value.absent(),
    this.clientSeq = const Value.absent(),
    this.timeSpentMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingAnswersCompanion.insert({
    required String sessionId,
    required int position,
    this.selectedPosition = const Value.absent(),
    this.typedAnswer = const Value.absent(),
    required int clientSeq,
    this.timeSpentMs = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       position = Value(position),
       clientSeq = Value(clientSeq),
       createdAt = Value(createdAt);
  static Insertable<PendingAnswerRow> custom({
    Expression<String>? sessionId,
    Expression<int>? position,
    Expression<int>? selectedPosition,
    Expression<String>? typedAnswer,
    Expression<int>? clientSeq,
    Expression<int>? timeSpentMs,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (position != null) 'position': position,
      if (selectedPosition != null) 'selected_position': selectedPosition,
      if (typedAnswer != null) 'typed_answer': typedAnswer,
      if (clientSeq != null) 'client_seq': clientSeq,
      if (timeSpentMs != null) 'time_spent_ms': timeSpentMs,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingAnswersCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? position,
    Value<int?>? selectedPosition,
    Value<String?>? typedAnswer,
    Value<int>? clientSeq,
    Value<int?>? timeSpentMs,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingAnswersCompanion(
      sessionId: sessionId ?? this.sessionId,
      position: position ?? this.position,
      selectedPosition: selectedPosition ?? this.selectedPosition,
      typedAnswer: typedAnswer ?? this.typedAnswer,
      clientSeq: clientSeq ?? this.clientSeq,
      timeSpentMs: timeSpentMs ?? this.timeSpentMs,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (selectedPosition.present) {
      map['selected_position'] = Variable<int>(selectedPosition.value);
    }
    if (typedAnswer.present) {
      map['typed_answer'] = Variable<String>(typedAnswer.value);
    }
    if (clientSeq.present) {
      map['client_seq'] = Variable<int>(clientSeq.value);
    }
    if (timeSpentMs.present) {
      map['time_spent_ms'] = Variable<int>(timeSpentMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingAnswersCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('position: $position, ')
          ..write('selectedPosition: $selectedPosition, ')
          ..write('typedAnswer: $typedAnswer, ')
          ..write('clientSeq: $clientSeq, ')
          ..write('timeSpentMs: $timeSpentMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RevisionCardsTable extends RevisionCards
    with TableInfo<$RevisionCardsTable, RevisionCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevisionCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conceptIdMeta = const VerificationMeta('conceptId');
  @override
  late final GeneratedColumn<String> conceptId = GeneratedColumn<String>(
    'concept_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES concepts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta('questionId');
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _frontMeta = const VerificationMeta('front');
  @override
  late final GeneratedColumn<String> front = GeneratedColumn<String>(
    'front',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backMeta = const VerificationMeta('back');
  @override
  late final GeneratedColumn<String> back = GeneratedColumn<String>(
    'back',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceFilenameMeta = const VerificationMeta('sourceFilename');
  @override
  late final GeneratedColumn<String> sourceFilename = GeneratedColumn<String>(
    'source_filename',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePageMeta = const VerificationMeta('sourcePage');
  @override
  late final GeneratedColumn<int> sourcePage = GeneratedColumn<int>(
    'source_page',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _examCodeMeta = const VerificationMeta('examCode');
  @override
  late final GeneratedColumn<String> examCode = GeneratedColumn<String>(
    'exam_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('added'),
  );
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<int> step = GeneratedColumn<int>(
    'step',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gapDaysMeta = const VerificationMeta('gapDays');
  @override
  late final GeneratedColumn<int> gapDays = GeneratedColumn<int>(
    'gap_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<String> dueOn = GeneratedColumn<String>(
    'due_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewCountMeta = const VerificationMeta('reviewCount');
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
    'review_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapseCountMeta = const VerificationMeta('lapseCount');
  @override
  late final GeneratedColumn<int> lapseCount = GeneratedColumn<int>(
    'lapse_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta('lastReviewedAt');
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt = GeneratedColumn<DateTime>(
    'last_reviewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    conceptId,
    questionId,
    front,
    back,
    sourceFilename,
    sourcePage,
    examCode,
    subject,
    topic,
    reason,
    step,
    gapDays,
    dueOn,
    reviewCount,
    lapseCount,
    lastReviewedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revision_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<RevisionCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('concept_id')) {
      context.handle(
        _conceptIdMeta,
        conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta),
      );
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    }
    if (data.containsKey('front')) {
      context.handle(_frontMeta, front.isAcceptableOrUnknown(data['front']!, _frontMeta));
    }
    if (data.containsKey('back')) {
      context.handle(_backMeta, back.isAcceptableOrUnknown(data['back']!, _backMeta));
    }
    if (data.containsKey('source_filename')) {
      context.handle(
        _sourceFilenameMeta,
        sourceFilename.isAcceptableOrUnknown(data['source_filename']!, _sourceFilenameMeta),
      );
    }
    if (data.containsKey('source_page')) {
      context.handle(
        _sourcePageMeta,
        sourcePage.isAcceptableOrUnknown(data['source_page']!, _sourcePageMeta),
      );
    }
    if (data.containsKey('exam_code')) {
      context.handle(
        _examCodeMeta,
        examCode.isAcceptableOrUnknown(data['exam_code']!, _examCodeMeta),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta, subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('topic')) {
      context.handle(_topicMeta, topic.isAcceptableOrUnknown(data['topic']!, _topicMeta));
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta, reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('step')) {
      context.handle(_stepMeta, step.isAcceptableOrUnknown(data['step']!, _stepMeta));
    } else if (isInserting) {
      context.missing(_stepMeta);
    }
    if (data.containsKey('gap_days')) {
      context.handle(_gapDaysMeta, gapDays.isAcceptableOrUnknown(data['gap_days']!, _gapDaysMeta));
    } else if (isInserting) {
      context.missing(_gapDaysMeta);
    }
    if (data.containsKey('due_on')) {
      context.handle(_dueOnMeta, dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta));
    } else if (isInserting) {
      context.missing(_dueOnMeta);
    }
    if (data.containsKey('review_count')) {
      context.handle(
        _reviewCountMeta,
        reviewCount.isAcceptableOrUnknown(data['review_count']!, _reviewCountMeta),
      );
    }
    if (data.containsKey('lapse_count')) {
      context.handle(
        _lapseCountMeta,
        lapseCount.isAcceptableOrUnknown(data['lapse_count']!, _lapseCountMeta),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(data['last_reviewed_at']!, _lastReviewedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RevisionCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RevisionCardRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      ),
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      ),
      front: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front'],
      ),
      back: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}back']),
      sourceFilename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_filename'],
      ),
      sourcePage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_page'],
      ),
      examCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_code'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      step: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}step'])!,
      gapDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gap_days'],
      )!,
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_on'],
      )!,
      reviewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_count'],
      )!,
      lapseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapse_count'],
      )!,
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RevisionCardsTable createAlias(String alias) {
    return $RevisionCardsTable(attachedDatabase, alias);
  }
}

class RevisionCardRow extends DataClass implements Insertable<RevisionCardRow> {
  final String id;

  /// `concept` or `question`.
  final String kind;
  final String? conceptId;

  /// Server question id (question cards).
  final String? questionId;

  /// Question cards: stem with options (front) and answer with explanation (back).
  final String? front;
  final String? back;
  final String? sourceFilename;
  final int? sourcePage;
  final String? examCode;
  final String? subject;
  final String? topic;

  /// Why the card exists: `added` (by the learner) or `incorrect_answer` (from practice).
  final String reason;
  final int step;
  final int gapDays;

  /// Calendar date `yyyy-MM-dd` (no timezone, so "due today" never shifts).
  final String dueOn;
  final int reviewCount;
  final int lapseCount;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RevisionCardRow({
    required this.id,
    required this.kind,
    this.conceptId,
    this.questionId,
    this.front,
    this.back,
    this.sourceFilename,
    this.sourcePage,
    this.examCode,
    this.subject,
    this.topic,
    required this.reason,
    required this.step,
    required this.gapDays,
    required this.dueOn,
    required this.reviewCount,
    required this.lapseCount,
    this.lastReviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || conceptId != null) {
      map['concept_id'] = Variable<String>(conceptId);
    }
    if (!nullToAbsent || questionId != null) {
      map['question_id'] = Variable<String>(questionId);
    }
    if (!nullToAbsent || front != null) {
      map['front'] = Variable<String>(front);
    }
    if (!nullToAbsent || back != null) {
      map['back'] = Variable<String>(back);
    }
    if (!nullToAbsent || sourceFilename != null) {
      map['source_filename'] = Variable<String>(sourceFilename);
    }
    if (!nullToAbsent || sourcePage != null) {
      map['source_page'] = Variable<int>(sourcePage);
    }
    if (!nullToAbsent || examCode != null) {
      map['exam_code'] = Variable<String>(examCode);
    }
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || topic != null) {
      map['topic'] = Variable<String>(topic);
    }
    map['reason'] = Variable<String>(reason);
    map['step'] = Variable<int>(step);
    map['gap_days'] = Variable<int>(gapDays);
    map['due_on'] = Variable<String>(dueOn);
    map['review_count'] = Variable<int>(reviewCount);
    map['lapse_count'] = Variable<int>(lapseCount);
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RevisionCardsCompanion toCompanion(bool nullToAbsent) {
    return RevisionCardsCompanion(
      id: Value(id),
      kind: Value(kind),
      conceptId: conceptId == null && nullToAbsent ? const Value.absent() : Value(conceptId),
      questionId: questionId == null && nullToAbsent ? const Value.absent() : Value(questionId),
      front: front == null && nullToAbsent ? const Value.absent() : Value(front),
      back: back == null && nullToAbsent ? const Value.absent() : Value(back),
      sourceFilename: sourceFilename == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFilename),
      sourcePage: sourcePage == null && nullToAbsent ? const Value.absent() : Value(sourcePage),
      examCode: examCode == null && nullToAbsent ? const Value.absent() : Value(examCode),
      subject: subject == null && nullToAbsent ? const Value.absent() : Value(subject),
      topic: topic == null && nullToAbsent ? const Value.absent() : Value(topic),
      reason: Value(reason),
      step: Value(step),
      gapDays: Value(gapDays),
      dueOn: Value(dueOn),
      reviewCount: Value(reviewCount),
      lapseCount: Value(lapseCount),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RevisionCardRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RevisionCardRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      conceptId: serializer.fromJson<String?>(json['conceptId']),
      questionId: serializer.fromJson<String?>(json['questionId']),
      front: serializer.fromJson<String?>(json['front']),
      back: serializer.fromJson<String?>(json['back']),
      sourceFilename: serializer.fromJson<String?>(json['sourceFilename']),
      sourcePage: serializer.fromJson<int?>(json['sourcePage']),
      examCode: serializer.fromJson<String?>(json['examCode']),
      subject: serializer.fromJson<String?>(json['subject']),
      topic: serializer.fromJson<String?>(json['topic']),
      reason: serializer.fromJson<String>(json['reason']),
      step: serializer.fromJson<int>(json['step']),
      gapDays: serializer.fromJson<int>(json['gapDays']),
      dueOn: serializer.fromJson<String>(json['dueOn']),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
      lapseCount: serializer.fromJson<int>(json['lapseCount']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'conceptId': serializer.toJson<String?>(conceptId),
      'questionId': serializer.toJson<String?>(questionId),
      'front': serializer.toJson<String?>(front),
      'back': serializer.toJson<String?>(back),
      'sourceFilename': serializer.toJson<String?>(sourceFilename),
      'sourcePage': serializer.toJson<int?>(sourcePage),
      'examCode': serializer.toJson<String?>(examCode),
      'subject': serializer.toJson<String?>(subject),
      'topic': serializer.toJson<String?>(topic),
      'reason': serializer.toJson<String>(reason),
      'step': serializer.toJson<int>(step),
      'gapDays': serializer.toJson<int>(gapDays),
      'dueOn': serializer.toJson<String>(dueOn),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'lapseCount': serializer.toJson<int>(lapseCount),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RevisionCardRow copyWith({
    String? id,
    String? kind,
    Value<String?> conceptId = const Value.absent(),
    Value<String?> questionId = const Value.absent(),
    Value<String?> front = const Value.absent(),
    Value<String?> back = const Value.absent(),
    Value<String?> sourceFilename = const Value.absent(),
    Value<int?> sourcePage = const Value.absent(),
    Value<String?> examCode = const Value.absent(),
    Value<String?> subject = const Value.absent(),
    Value<String?> topic = const Value.absent(),
    String? reason,
    int? step,
    int? gapDays,
    String? dueOn,
    int? reviewCount,
    int? lapseCount,
    Value<DateTime?> lastReviewedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RevisionCardRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    conceptId: conceptId.present ? conceptId.value : this.conceptId,
    questionId: questionId.present ? questionId.value : this.questionId,
    front: front.present ? front.value : this.front,
    back: back.present ? back.value : this.back,
    sourceFilename: sourceFilename.present ? sourceFilename.value : this.sourceFilename,
    sourcePage: sourcePage.present ? sourcePage.value : this.sourcePage,
    examCode: examCode.present ? examCode.value : this.examCode,
    subject: subject.present ? subject.value : this.subject,
    topic: topic.present ? topic.value : this.topic,
    reason: reason ?? this.reason,
    step: step ?? this.step,
    gapDays: gapDays ?? this.gapDays,
    dueOn: dueOn ?? this.dueOn,
    reviewCount: reviewCount ?? this.reviewCount,
    lapseCount: lapseCount ?? this.lapseCount,
    lastReviewedAt: lastReviewedAt.present ? lastReviewedAt.value : this.lastReviewedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RevisionCardRow copyWithCompanion(RevisionCardsCompanion data) {
    return RevisionCardRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      questionId: data.questionId.present ? data.questionId.value : this.questionId,
      front: data.front.present ? data.front.value : this.front,
      back: data.back.present ? data.back.value : this.back,
      sourceFilename: data.sourceFilename.present ? data.sourceFilename.value : this.sourceFilename,
      sourcePage: data.sourcePage.present ? data.sourcePage.value : this.sourcePage,
      examCode: data.examCode.present ? data.examCode.value : this.examCode,
      subject: data.subject.present ? data.subject.value : this.subject,
      topic: data.topic.present ? data.topic.value : this.topic,
      reason: data.reason.present ? data.reason.value : this.reason,
      step: data.step.present ? data.step.value : this.step,
      gapDays: data.gapDays.present ? data.gapDays.value : this.gapDays,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
      reviewCount: data.reviewCount.present ? data.reviewCount.value : this.reviewCount,
      lapseCount: data.lapseCount.present ? data.lapseCount.value : this.lapseCount,
      lastReviewedAt: data.lastReviewedAt.present ? data.lastReviewedAt.value : this.lastReviewedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RevisionCardRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('conceptId: $conceptId, ')
          ..write('questionId: $questionId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('sourceFilename: $sourceFilename, ')
          ..write('sourcePage: $sourcePage, ')
          ..write('examCode: $examCode, ')
          ..write('subject: $subject, ')
          ..write('topic: $topic, ')
          ..write('reason: $reason, ')
          ..write('step: $step, ')
          ..write('gapDays: $gapDays, ')
          ..write('dueOn: $dueOn, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    conceptId,
    questionId,
    front,
    back,
    sourceFilename,
    sourcePage,
    examCode,
    subject,
    topic,
    reason,
    step,
    gapDays,
    dueOn,
    reviewCount,
    lapseCount,
    lastReviewedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RevisionCardRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.conceptId == this.conceptId &&
          other.questionId == this.questionId &&
          other.front == this.front &&
          other.back == this.back &&
          other.sourceFilename == this.sourceFilename &&
          other.sourcePage == this.sourcePage &&
          other.examCode == this.examCode &&
          other.subject == this.subject &&
          other.topic == this.topic &&
          other.reason == this.reason &&
          other.step == this.step &&
          other.gapDays == this.gapDays &&
          other.dueOn == this.dueOn &&
          other.reviewCount == this.reviewCount &&
          other.lapseCount == this.lapseCount &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RevisionCardsCompanion extends UpdateCompanion<RevisionCardRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> conceptId;
  final Value<String?> questionId;
  final Value<String?> front;
  final Value<String?> back;
  final Value<String?> sourceFilename;
  final Value<int?> sourcePage;
  final Value<String?> examCode;
  final Value<String?> subject;
  final Value<String?> topic;
  final Value<String> reason;
  final Value<int> step;
  final Value<int> gapDays;
  final Value<String> dueOn;
  final Value<int> reviewCount;
  final Value<int> lapseCount;
  final Value<DateTime?> lastReviewedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RevisionCardsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.conceptId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.sourceFilename = const Value.absent(),
    this.sourcePage = const Value.absent(),
    this.examCode = const Value.absent(),
    this.subject = const Value.absent(),
    this.topic = const Value.absent(),
    this.reason = const Value.absent(),
    this.step = const Value.absent(),
    this.gapDays = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevisionCardsCompanion.insert({
    required String id,
    required String kind,
    this.conceptId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.sourceFilename = const Value.absent(),
    this.sourcePage = const Value.absent(),
    this.examCode = const Value.absent(),
    this.subject = const Value.absent(),
    this.topic = const Value.absent(),
    this.reason = const Value.absent(),
    required int step,
    required int gapDays,
    required String dueOn,
    this.reviewCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       step = Value(step),
       gapDays = Value(gapDays),
       dueOn = Value(dueOn),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RevisionCardRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? conceptId,
    Expression<String>? questionId,
    Expression<String>? front,
    Expression<String>? back,
    Expression<String>? sourceFilename,
    Expression<int>? sourcePage,
    Expression<String>? examCode,
    Expression<String>? subject,
    Expression<String>? topic,
    Expression<String>? reason,
    Expression<int>? step,
    Expression<int>? gapDays,
    Expression<String>? dueOn,
    Expression<int>? reviewCount,
    Expression<int>? lapseCount,
    Expression<DateTime>? lastReviewedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (conceptId != null) 'concept_id': conceptId,
      if (questionId != null) 'question_id': questionId,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (sourceFilename != null) 'source_filename': sourceFilename,
      if (sourcePage != null) 'source_page': sourcePage,
      if (examCode != null) 'exam_code': examCode,
      if (subject != null) 'subject': subject,
      if (topic != null) 'topic': topic,
      if (reason != null) 'reason': reason,
      if (step != null) 'step': step,
      if (gapDays != null) 'gap_days': gapDays,
      if (dueOn != null) 'due_on': dueOn,
      if (reviewCount != null) 'review_count': reviewCount,
      if (lapseCount != null) 'lapse_count': lapseCount,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevisionCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String?>? conceptId,
    Value<String?>? questionId,
    Value<String?>? front,
    Value<String?>? back,
    Value<String?>? sourceFilename,
    Value<int?>? sourcePage,
    Value<String?>? examCode,
    Value<String?>? subject,
    Value<String?>? topic,
    Value<String>? reason,
    Value<int>? step,
    Value<int>? gapDays,
    Value<String>? dueOn,
    Value<int>? reviewCount,
    Value<int>? lapseCount,
    Value<DateTime?>? lastReviewedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RevisionCardsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      conceptId: conceptId ?? this.conceptId,
      questionId: questionId ?? this.questionId,
      front: front ?? this.front,
      back: back ?? this.back,
      sourceFilename: sourceFilename ?? this.sourceFilename,
      sourcePage: sourcePage ?? this.sourcePage,
      examCode: examCode ?? this.examCode,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      reason: reason ?? this.reason,
      step: step ?? this.step,
      gapDays: gapDays ?? this.gapDays,
      dueOn: dueOn ?? this.dueOn,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (front.present) {
      map['front'] = Variable<String>(front.value);
    }
    if (back.present) {
      map['back'] = Variable<String>(back.value);
    }
    if (sourceFilename.present) {
      map['source_filename'] = Variable<String>(sourceFilename.value);
    }
    if (sourcePage.present) {
      map['source_page'] = Variable<int>(sourcePage.value);
    }
    if (examCode.present) {
      map['exam_code'] = Variable<String>(examCode.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (step.present) {
      map['step'] = Variable<int>(step.value);
    }
    if (gapDays.present) {
      map['gap_days'] = Variable<int>(gapDays.value);
    }
    if (dueOn.present) {
      map['due_on'] = Variable<String>(dueOn.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (lapseCount.present) {
      map['lapse_count'] = Variable<int>(lapseCount.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevisionCardsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('conceptId: $conceptId, ')
          ..write('questionId: $questionId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('sourceFilename: $sourceFilename, ')
          ..write('sourcePage: $sourcePage, ')
          ..write('examCode: $examCode, ')
          ..write('subject: $subject, ')
          ..write('topic: $topic, ')
          ..write('reason: $reason, ')
          ..write('step: $step, ')
          ..write('gapDays: $gapDays, ')
          ..write('dueOn: $dueOn, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardReviewsTable extends CardReviews with TableInfo<$CardReviewsTable, CardReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES revision_cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta('reviewedAt');
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueBeforeMeta = const VerificationMeta('dueBefore');
  @override
  late final GeneratedColumn<String> dueBefore = GeneratedColumn<String>(
    'due_before',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAfterMeta = const VerificationMeta('dueAfter');
  @override
  late final GeneratedColumn<String> dueAfter = GeneratedColumn<String>(
    'due_after',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gapDaysMeta = const VerificationMeta('gapDays');
  @override
  late final GeneratedColumn<int> gapDays = GeneratedColumn<int>(
    'gap_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    syncId,
    reviewedAt,
    rating,
    dueBefore,
    dueAfter,
    gapDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(_cardIdMeta, cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta));
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta, syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta, rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('due_before')) {
      context.handle(
        _dueBeforeMeta,
        dueBefore.isAcceptableOrUnknown(data['due_before']!, _dueBeforeMeta),
      );
    } else if (isInserting) {
      context.missing(_dueBeforeMeta);
    }
    if (data.containsKey('due_after')) {
      context.handle(
        _dueAfterMeta,
        dueAfter.isAcceptableOrUnknown(data['due_after']!, _dueAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAfterMeta);
    }
    if (data.containsKey('gap_days')) {
      context.handle(_gapDaysMeta, gapDays.isAcceptableOrUnknown(data['gap_days']!, _gapDaysMeta));
    } else if (isInserting) {
      context.missing(_gapDaysMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardReviewRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      )!,
      dueBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_before'],
      )!,
      dueAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_after'],
      )!,
      gapDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gap_days'],
      )!,
    );
  }

  @override
  $CardReviewsTable createAlias(String alias) {
    return $CardReviewsTable(attachedDatabase, alias);
  }
}

class CardReviewRow extends DataClass implements Insertable<CardReviewRow> {
  final int id;
  final String cardId;

  /// Stable id across devices (sync, schema v5); local [id]s are per device.
  final String? syncId;
  final DateTime reviewedAt;

  /// `again`, `hard`, `good` or `easy`.
  final String rating;
  final String dueBefore;
  final String dueAfter;
  final int gapDays;
  const CardReviewRow({
    required this.id,
    required this.cardId,
    this.syncId,
    required this.reviewedAt,
    required this.rating,
    required this.dueBefore,
    required this.dueAfter,
    required this.gapDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<String>(cardId);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    map['rating'] = Variable<String>(rating);
    map['due_before'] = Variable<String>(dueBefore);
    map['due_after'] = Variable<String>(dueAfter);
    map['gap_days'] = Variable<int>(gapDays);
    return map;
  }

  CardReviewsCompanion toCompanion(bool nullToAbsent) {
    return CardReviewsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      syncId: syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      reviewedAt: Value(reviewedAt),
      rating: Value(rating),
      dueBefore: Value(dueBefore),
      dueAfter: Value(dueAfter),
      gapDays: Value(gapDays),
    );
  }

  factory CardReviewRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardReviewRow(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<String>(json['cardId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      rating: serializer.fromJson<String>(json['rating']),
      dueBefore: serializer.fromJson<String>(json['dueBefore']),
      dueAfter: serializer.fromJson<String>(json['dueAfter']),
      gapDays: serializer.fromJson<int>(json['gapDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<String>(cardId),
      'syncId': serializer.toJson<String?>(syncId),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'rating': serializer.toJson<String>(rating),
      'dueBefore': serializer.toJson<String>(dueBefore),
      'dueAfter': serializer.toJson<String>(dueAfter),
      'gapDays': serializer.toJson<int>(gapDays),
    };
  }

  CardReviewRow copyWith({
    int? id,
    String? cardId,
    Value<String?> syncId = const Value.absent(),
    DateTime? reviewedAt,
    String? rating,
    String? dueBefore,
    String? dueAfter,
    int? gapDays,
  }) => CardReviewRow(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    syncId: syncId.present ? syncId.value : this.syncId,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    rating: rating ?? this.rating,
    dueBefore: dueBefore ?? this.dueBefore,
    dueAfter: dueAfter ?? this.dueAfter,
    gapDays: gapDays ?? this.gapDays,
  );
  CardReviewRow copyWithCompanion(CardReviewsCompanion data) {
    return CardReviewRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      reviewedAt: data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
      rating: data.rating.present ? data.rating.value : this.rating,
      dueBefore: data.dueBefore.present ? data.dueBefore.value : this.dueBefore,
      dueAfter: data.dueAfter.present ? data.dueAfter.value : this.dueAfter,
      gapDays: data.gapDays.present ? data.gapDays.value : this.gapDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardReviewRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('syncId: $syncId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('dueBefore: $dueBefore, ')
          ..write('dueAfter: $dueAfter, ')
          ..write('gapDays: $gapDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cardId, syncId, reviewedAt, rating, dueBefore, dueAfter, gapDays);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardReviewRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.syncId == this.syncId &&
          other.reviewedAt == this.reviewedAt &&
          other.rating == this.rating &&
          other.dueBefore == this.dueBefore &&
          other.dueAfter == this.dueAfter &&
          other.gapDays == this.gapDays);
}

class CardReviewsCompanion extends UpdateCompanion<CardReviewRow> {
  final Value<int> id;
  final Value<String> cardId;
  final Value<String?> syncId;
  final Value<DateTime> reviewedAt;
  final Value<String> rating;
  final Value<String> dueBefore;
  final Value<String> dueAfter;
  final Value<int> gapDays;
  const CardReviewsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rating = const Value.absent(),
    this.dueBefore = const Value.absent(),
    this.dueAfter = const Value.absent(),
    this.gapDays = const Value.absent(),
  });
  CardReviewsCompanion.insert({
    this.id = const Value.absent(),
    required String cardId,
    this.syncId = const Value.absent(),
    required DateTime reviewedAt,
    required String rating,
    required String dueBefore,
    required String dueAfter,
    required int gapDays,
  }) : cardId = Value(cardId),
       reviewedAt = Value(reviewedAt),
       rating = Value(rating),
       dueBefore = Value(dueBefore),
       dueAfter = Value(dueAfter),
       gapDays = Value(gapDays);
  static Insertable<CardReviewRow> custom({
    Expression<int>? id,
    Expression<String>? cardId,
    Expression<String>? syncId,
    Expression<DateTime>? reviewedAt,
    Expression<String>? rating,
    Expression<String>? dueBefore,
    Expression<String>? dueAfter,
    Expression<int>? gapDays,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (syncId != null) 'sync_id': syncId,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rating != null) 'rating': rating,
      if (dueBefore != null) 'due_before': dueBefore,
      if (dueAfter != null) 'due_after': dueAfter,
      if (gapDays != null) 'gap_days': gapDays,
    });
  }

  CardReviewsCompanion copyWith({
    Value<int>? id,
    Value<String>? cardId,
    Value<String?>? syncId,
    Value<DateTime>? reviewedAt,
    Value<String>? rating,
    Value<String>? dueBefore,
    Value<String>? dueAfter,
    Value<int>? gapDays,
  }) {
    return CardReviewsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      syncId: syncId ?? this.syncId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      dueBefore: dueBefore ?? this.dueBefore,
      dueAfter: dueAfter ?? this.dueAfter,
      gapDays: gapDays ?? this.gapDays,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (dueBefore.present) {
      map['due_before'] = Variable<String>(dueBefore.value);
    }
    if (dueAfter.present) {
      map['due_after'] = Variable<String>(dueAfter.value);
    }
    if (gapDays.present) {
      map['gap_days'] = Variable<int>(gapDays.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardReviewsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('syncId: $syncId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('dueBefore: $dueBefore, ')
          ..write('dueAfter: $dueAfter, ')
          ..write('gapDays: $gapDays')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox with TableInfo<$SyncOutboxTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta('changedAt');
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, entityId, version, changedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(_entityMeta, entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta, version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, entityId};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  /// `concept`, `study_profile`, `revision_card`, `card_review` or `setting`.
  final String entity;
  final String entityId;
  final int version;
  final DateTime changedAt;
  const SyncOutboxRow({
    required this.entity,
    required this.entityId,
    required this.version,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['version'] = Variable<int>(version);
    map['changed_at'] = Variable<DateTime>(changedAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      entity: Value(entity),
      entityId: Value(entityId),
      version: Value(version),
      changedAt: Value(changedAt),
    );
  }

  factory SyncOutboxRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      version: serializer.fromJson<int>(json['version']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'version': serializer.toJson<int>(version),
      'changedAt': serializer.toJson<DateTime>(changedAt),
    };
  }

  SyncOutboxRow copyWith({String? entity, String? entityId, int? version, DateTime? changedAt}) =>
      SyncOutboxRow(
        entity: entity ?? this.entity,
        entityId: entityId ?? this.entityId,
        version: version ?? this.version,
        changedAt: changedAt ?? this.changedAt,
      );
  SyncOutboxRow copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      version: data.version.present ? data.version.value : this.version,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, entityId, version, changedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.version == this.version &&
          other.changedAt == this.changedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<String> entity;
  final Value<String> entityId;
  final Value<int> version;
  final Value<DateTime> changedAt;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.version = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String entity,
    required String entityId,
    this.version = const Value.absent(),
    required DateTime changedAt,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       entityId = Value(entityId),
       changedAt = Value(changedAt);
  static Insertable<SyncOutboxRow> custom({
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<int>? version,
    Expression<DateTime>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (version != null) 'version': version,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? entity,
    Value<String>? entityId,
    Value<int>? version,
    Value<DateTime>? changedAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineQuestionsTable extends OfflineQuestions
    with TableInfo<$OfflineQuestionsTable, OfflineQuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examCodeMeta = const VerificationMeta('examCode');
  @override
  late final GeneratedColumn<String> examCode = GeneratedColumn<String>(
    'exam_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta('topicId');
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _patternIdMeta = const VerificationMeta('patternId');
  @override
  late final GeneratedColumn<String> patternId = GeneratedColumn<String>(
    'pattern_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta('savedAt');
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, examCode, subject, topicId, patternId, data, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineQuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exam_code')) {
      context.handle(
        _examCodeMeta,
        examCode.isAcceptableOrUnknown(data['exam_code']!, _examCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_examCodeMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta, subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('topic_id')) {
      context.handle(_topicIdMeta, topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta));
    }
    if (data.containsKey('pattern_id')) {
      context.handle(
        _patternIdMeta,
        patternId.isAcceptableOrUnknown(data['pattern_id']!, _patternIdMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta, savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta));
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineQuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineQuestionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      examCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_code'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      ),
      patternId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern_id'],
      ),
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $OfflineQuestionsTable createAlias(String alias) {
    return $OfflineQuestionsTable(attachedDatabase, alias);
  }
}

class OfflineQuestionRow extends DataClass implements Insertable<OfflineQuestionRow> {
  final String id;
  final String examCode;
  final String? subject;
  final String? topicId;
  final String? patternId;
  final String data;
  final DateTime savedAt;
  const OfflineQuestionRow({
    required this.id,
    required this.examCode,
    this.subject,
    this.topicId,
    this.patternId,
    required this.data,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exam_code'] = Variable<String>(examCode);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || topicId != null) {
      map['topic_id'] = Variable<String>(topicId);
    }
    if (!nullToAbsent || patternId != null) {
      map['pattern_id'] = Variable<String>(patternId);
    }
    map['data'] = Variable<String>(data);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  OfflineQuestionsCompanion toCompanion(bool nullToAbsent) {
    return OfflineQuestionsCompanion(
      id: Value(id),
      examCode: Value(examCode),
      subject: subject == null && nullToAbsent ? const Value.absent() : Value(subject),
      topicId: topicId == null && nullToAbsent ? const Value.absent() : Value(topicId),
      patternId: patternId == null && nullToAbsent ? const Value.absent() : Value(patternId),
      data: Value(data),
      savedAt: Value(savedAt),
    );
  }

  factory OfflineQuestionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineQuestionRow(
      id: serializer.fromJson<String>(json['id']),
      examCode: serializer.fromJson<String>(json['examCode']),
      subject: serializer.fromJson<String?>(json['subject']),
      topicId: serializer.fromJson<String?>(json['topicId']),
      patternId: serializer.fromJson<String?>(json['patternId']),
      data: serializer.fromJson<String>(json['data']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'examCode': serializer.toJson<String>(examCode),
      'subject': serializer.toJson<String?>(subject),
      'topicId': serializer.toJson<String?>(topicId),
      'patternId': serializer.toJson<String?>(patternId),
      'data': serializer.toJson<String>(data),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  OfflineQuestionRow copyWith({
    String? id,
    String? examCode,
    Value<String?> subject = const Value.absent(),
    Value<String?> topicId = const Value.absent(),
    Value<String?> patternId = const Value.absent(),
    String? data,
    DateTime? savedAt,
  }) => OfflineQuestionRow(
    id: id ?? this.id,
    examCode: examCode ?? this.examCode,
    subject: subject.present ? subject.value : this.subject,
    topicId: topicId.present ? topicId.value : this.topicId,
    patternId: patternId.present ? patternId.value : this.patternId,
    data: data ?? this.data,
    savedAt: savedAt ?? this.savedAt,
  );
  OfflineQuestionRow copyWithCompanion(OfflineQuestionsCompanion data) {
    return OfflineQuestionRow(
      id: data.id.present ? data.id.value : this.id,
      examCode: data.examCode.present ? data.examCode.value : this.examCode,
      subject: data.subject.present ? data.subject.value : this.subject,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      patternId: data.patternId.present ? data.patternId.value : this.patternId,
      data: data.data.present ? data.data.value : this.data,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineQuestionRow(')
          ..write('id: $id, ')
          ..write('examCode: $examCode, ')
          ..write('subject: $subject, ')
          ..write('topicId: $topicId, ')
          ..write('patternId: $patternId, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, examCode, subject, topicId, patternId, data, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineQuestionRow &&
          other.id == this.id &&
          other.examCode == this.examCode &&
          other.subject == this.subject &&
          other.topicId == this.topicId &&
          other.patternId == this.patternId &&
          other.data == this.data &&
          other.savedAt == this.savedAt);
}

class OfflineQuestionsCompanion extends UpdateCompanion<OfflineQuestionRow> {
  final Value<String> id;
  final Value<String> examCode;
  final Value<String?> subject;
  final Value<String?> topicId;
  final Value<String?> patternId;
  final Value<String> data;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const OfflineQuestionsCompanion({
    this.id = const Value.absent(),
    this.examCode = const Value.absent(),
    this.subject = const Value.absent(),
    this.topicId = const Value.absent(),
    this.patternId = const Value.absent(),
    this.data = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineQuestionsCompanion.insert({
    required String id,
    required String examCode,
    this.subject = const Value.absent(),
    this.topicId = const Value.absent(),
    this.patternId = const Value.absent(),
    required String data,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       examCode = Value(examCode),
       data = Value(data),
       savedAt = Value(savedAt);
  static Insertable<OfflineQuestionRow> custom({
    Expression<String>? id,
    Expression<String>? examCode,
    Expression<String>? subject,
    Expression<String>? topicId,
    Expression<String>? patternId,
    Expression<String>? data,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examCode != null) 'exam_code': examCode,
      if (subject != null) 'subject': subject,
      if (topicId != null) 'topic_id': topicId,
      if (patternId != null) 'pattern_id': patternId,
      if (data != null) 'data': data,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineQuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? examCode,
    Value<String?>? subject,
    Value<String?>? topicId,
    Value<String?>? patternId,
    Value<String>? data,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return OfflineQuestionsCompanion(
      id: id ?? this.id,
      examCode: examCode ?? this.examCode,
      subject: subject ?? this.subject,
      topicId: topicId ?? this.topicId,
      patternId: patternId ?? this.patternId,
      data: data ?? this.data,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (examCode.present) {
      map['exam_code'] = Variable<String>(examCode.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (patternId.present) {
      map['pattern_id'] = Variable<String>(patternId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineQuestionsCompanion(')
          ..write('id: $id, ')
          ..write('examCode: $examCode, ')
          ..write('subject: $subject, ')
          ..write('topicId: $topicId, ')
          ..write('patternId: $patternId, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineSessionsTable extends OfflineSessions
    with TableInfo<$OfflineSessionsTable, OfflineSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta('finished');
  @override
  late final GeneratedColumn<bool> finished = GeneratedColumn<bool>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("finished" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data, finished, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('finished')) {
      context.handle(
        _finishedMeta,
        finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineSessionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      finished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}finished'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OfflineSessionsTable createAlias(String alias) {
    return $OfflineSessionsTable(attachedDatabase, alias);
  }
}

class OfflineSessionRow extends DataClass implements Insertable<OfflineSessionRow> {
  final String id;
  final String data;
  final bool finished;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OfflineSessionRow({
    required this.id,
    required this.data,
    required this.finished,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    map['finished'] = Variable<bool>(finished);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OfflineSessionsCompanion toCompanion(bool nullToAbsent) {
    return OfflineSessionsCompanion(
      id: Value(id),
      data: Value(data),
      finished: Value(finished),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OfflineSessionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineSessionRow(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
      finished: serializer.fromJson<bool>(json['finished']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
      'finished': serializer.toJson<bool>(finished),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OfflineSessionRow copyWith({
    String? id,
    String? data,
    bool? finished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OfflineSessionRow(
    id: id ?? this.id,
    data: data ?? this.data,
    finished: finished ?? this.finished,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OfflineSessionRow copyWithCompanion(OfflineSessionsCompanion data) {
    return OfflineSessionRow(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
      finished: data.finished.present ? data.finished.value : this.finished,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSessionRow(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('finished: $finished, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data, finished, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineSessionRow &&
          other.id == this.id &&
          other.data == this.data &&
          other.finished == this.finished &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OfflineSessionsCompanion extends UpdateCompanion<OfflineSessionRow> {
  final Value<String> id;
  final Value<String> data;
  final Value<bool> finished;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OfflineSessionsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.finished = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineSessionsCompanion.insert({
    required String id,
    required String data,
    this.finished = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OfflineSessionRow> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<bool>? finished,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (finished != null) 'finished': finished,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? data,
    Value<bool>? finished,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OfflineSessionsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      finished: finished ?? this.finished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (finished.present) {
      map['finished'] = Variable<bool>(finished.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSessionsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('finished: $finished, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConceptsTable concepts = $ConceptsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $StudyProfilesTable studyProfiles = $StudyProfilesTable(this);
  late final $PendingAnswersTable pendingAnswers = $PendingAnswersTable(this);
  late final $RevisionCardsTable revisionCards = $RevisionCardsTable(this);
  late final $CardReviewsTable cardReviews = $CardReviewsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $OfflineQuestionsTable offlineQuestions = $OfflineQuestionsTable(this);
  late final $OfflineSessionsTable offlineSessions = $OfflineSessionsTable(this);
  late final Index cardReviewsSyncId = Index(
    'card_reviews_sync_id',
    'CREATE UNIQUE INDEX card_reviews_sync_id ON card_reviews (sync_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    concepts,
    appSettings,
    studyProfiles,
    pendingAnswers,
    revisionCards,
    cardReviews,
    syncOutbox,
    offlineQuestions,
    offlineSessions,
    cardReviewsSyncId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('concepts', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('revision_cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('revision_cards', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('card_reviews', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ConceptsTableCreateCompanionBuilder = ConceptsCompanion Function({
  required String id,
  required String examCode,
  required String title,
  Value<String> notes,
  required String subject,
  required String topic,
  Value<String?> subtopic,
  required String language,
  Value<List<String>> tags,
  Value<String?> sourceReference,
  Value<DateTime?> archivedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ConceptsTableUpdateCompanionBuilder = ConceptsCompanion Function({
  Value<String> id,
  Value<String> examCode,
  Value<String> title,
  Value<String> notes,
  Value<String> subject,
  Value<String> topic,
  Value<String?> subtopic,
  Value<String> language,
  Value<List<String>> tags,
  Value<String?> sourceReference,
  Value<DateTime?> archivedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ConceptsTableReferences
    extends BaseReferences<_$AppDatabase, $ConceptsTable, ConceptRow> {
  $$ConceptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RevisionCardsTable, List<RevisionCardRow>> _revisionCardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.revisionCards,
    aliasName: 'concepts__id__revision_cards__concept_id',
  );

  $$RevisionCardsTableProcessedTableManager get revisionCardsRefs {
    final manager = $$RevisionCardsTableTableManager(
      $_db,
      $_db.revisionCards,
    ).filter((f) => f.conceptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_revisionCardsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ConceptsTableFilterComposer extends Composer<_$AppDatabase, $ConceptsTable> {
  $$ConceptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subtopic =>
      $composableBuilder(column: $table.subtopic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> revisionCardsRefs(
    Expression<bool> Function($$RevisionCardsTableFilterComposer f) f,
  ) {
    final $$RevisionCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.revisionCards,
      getReferencedColumn: (t) => t.conceptId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RevisionCardsTableFilterComposer(
            $db: $db,
            $table: $db.revisionCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConceptsTableOrderingComposer extends Composer<_$AppDatabase, $ConceptsTable> {
  $$ConceptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subtopic =>
      $composableBuilder(column: $table.subtopic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConceptsTableAnnotationComposer extends Composer<_$AppDatabase, $ConceptsTable> {
  $$ConceptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get subtopic =>
      $composableBuilder(column: $table.subtopic, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get sourceReference =>
      $composableBuilder(column: $table.sourceReference, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> revisionCardsRefs<T extends Object>(
    Expression<T> Function($$RevisionCardsTableAnnotationComposer a) f,
  ) {
    final $$RevisionCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.revisionCards,
      getReferencedColumn: (t) => t.conceptId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RevisionCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.revisionCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConceptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConceptsTable,
          ConceptRow,
          $$ConceptsTableFilterComposer,
          $$ConceptsTableOrderingComposer,
          $$ConceptsTableAnnotationComposer,
          $$ConceptsTableCreateCompanionBuilder,
          $$ConceptsTableUpdateCompanionBuilder,
          (ConceptRow, $$ConceptsTableReferences),
          ConceptRow,
          PrefetchHooks Function({bool revisionCardsRefs})
        > {
  $$ConceptsTableTableManager(_$AppDatabase db, $ConceptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ConceptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ConceptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConceptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> examCode = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> topic = const Value.absent(),
                Value<String?> subtopic = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<String?> sourceReference = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConceptsCompanion(
                id: id,
                examCode: examCode,
                title: title,
                notes: notes,
                subject: subject,
                topic: topic,
                subtopic: subtopic,
                language: language,
                tags: tags,
                sourceReference: sourceReference,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String examCode,
                required String title,
                Value<String> notes = const Value.absent(),
                required String subject,
                required String topic,
                Value<String?> subtopic = const Value.absent(),
                required String language,
                Value<List<String>> tags = const Value.absent(),
                Value<String?> sourceReference = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConceptsCompanion.insert(
                id: id,
                examCode: examCode,
                title: title,
                notes: notes,
                subject: subject,
                topic: topic,
                subtopic: subtopic,
                language: language,
                tags: tags,
                sourceReference: sourceReference,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConceptsTable, ConceptRow>(table),
                  $$ConceptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({revisionCardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (revisionCardsRefs) db.revisionCards],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (revisionCardsRefs)
                    await $_getPrefetchedData<ConceptRow, $ConceptsTable, RevisionCardRow>(
                      currentTable: table,
                      referencedTable: $$ConceptsTableReferences._revisionCardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConceptsTableReferences(db, table, p0).revisionCardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.conceptId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ConceptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConceptsTable,
      ConceptRow,
      $$ConceptsTableFilterComposer,
      $$ConceptsTableOrderingComposer,
      $$ConceptsTableAnnotationComposer,
      $$ConceptsTableCreateCompanionBuilder,
      $$ConceptsTableUpdateCompanionBuilder,
      (ConceptRow, $$ConceptsTableReferences),
      ConceptRow,
      PrefetchHooks Function({bool revisionCardsRefs})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (AppSettingRow, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSettingRow>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (AppSettingRow, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$StudyProfilesTableCreateCompanionBuilder = StudyProfilesCompanion Function({
  Value<int> id,
  Value<List<String>> examCodes,
  Value<String?> targetExamDate,
  Value<int?> dailyStudyMinutes,
  Value<int?> reminderMinutes,
  Value<DateTime?> onboardingCompletedAt,
  required DateTime updatedAt,
});
typedef $$StudyProfilesTableUpdateCompanionBuilder = StudyProfilesCompanion Function({
  Value<int> id,
  Value<List<String>> examCodes,
  Value<String?> targetExamDate,
  Value<int?> dailyStudyMinutes,
  Value<int?> reminderMinutes,
  Value<DateTime?> onboardingCompletedAt,
  Value<DateTime> updatedAt,
});

class $$StudyProfilesTableFilterComposer extends Composer<_$AppDatabase, $StudyProfilesTable> {
  $$StudyProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get examCodes =>
      $composableBuilder(
        column: $table.examCodes,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get targetExamDate =>
      $composableBuilder(column: $table.targetExamDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyStudyMinutes => $composableBuilder(
    column: $table.dailyStudyMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$StudyProfilesTableOrderingComposer extends Composer<_$AppDatabase, $StudyProfilesTable> {
  $$StudyProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examCodes =>
      $composableBuilder(column: $table.examCodes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetExamDate => $composableBuilder(
    column: $table.targetExamDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyStudyMinutes => $composableBuilder(
    column: $table.dailyStudyMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$StudyProfilesTableAnnotationComposer extends Composer<_$AppDatabase, $StudyProfilesTable> {
  $$StudyProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get examCodes =>
      $composableBuilder(column: $table.examCodes, builder: (column) => column);

  GeneratedColumn<String> get targetExamDate =>
      $composableBuilder(column: $table.targetExamDate, builder: (column) => column);

  GeneratedColumn<int> get dailyStudyMinutes =>
      $composableBuilder(column: $table.dailyStudyMinutes, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutes =>
      $composableBuilder(column: $table.reminderMinutes, builder: (column) => column);

  GeneratedColumn<DateTime> get onboardingCompletedAt =>
      $composableBuilder(column: $table.onboardingCompletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StudyProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyProfilesTable,
          StudyProfileRow,
          $$StudyProfilesTableFilterComposer,
          $$StudyProfilesTableOrderingComposer,
          $$StudyProfilesTableAnnotationComposer,
          $$StudyProfilesTableCreateCompanionBuilder,
          $$StudyProfilesTableUpdateCompanionBuilder,
          (StudyProfileRow, BaseReferences<_$AppDatabase, $StudyProfilesTable, StudyProfileRow>),
          StudyProfileRow,
          PrefetchHooks Function()
        > {
  $$StudyProfilesTableTableManager(_$AppDatabase db, $StudyProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$StudyProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<List<String>> examCodes = const Value.absent(),
                Value<String?> targetExamDate = const Value.absent(),
                Value<int?> dailyStudyMinutes = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<DateTime?> onboardingCompletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StudyProfilesCompanion(
                id: id,
                examCodes: examCodes,
                targetExamDate: targetExamDate,
                dailyStudyMinutes: dailyStudyMinutes,
                reminderMinutes: reminderMinutes,
                onboardingCompletedAt: onboardingCompletedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<List<String>> examCodes = const Value.absent(),
                Value<String?> targetExamDate = const Value.absent(),
                Value<int?> dailyStudyMinutes = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<DateTime?> onboardingCompletedAt = const Value.absent(),
                required DateTime updatedAt,
              }) => StudyProfilesCompanion.insert(
                id: id,
                examCodes: examCodes,
                targetExamDate: targetExamDate,
                dailyStudyMinutes: dailyStudyMinutes,
                reminderMinutes: reminderMinutes,
                onboardingCompletedAt: onboardingCompletedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudyProfilesTable, StudyProfileRow>(table),
                  BaseReferences<_$AppDatabase, $StudyProfilesTable, StudyProfileRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyProfilesTable,
      StudyProfileRow,
      $$StudyProfilesTableFilterComposer,
      $$StudyProfilesTableOrderingComposer,
      $$StudyProfilesTableAnnotationComposer,
      $$StudyProfilesTableCreateCompanionBuilder,
      $$StudyProfilesTableUpdateCompanionBuilder,
      (StudyProfileRow, BaseReferences<_$AppDatabase, $StudyProfilesTable, StudyProfileRow>),
      StudyProfileRow,
      PrefetchHooks Function()
    >;
typedef $$PendingAnswersTableCreateCompanionBuilder = PendingAnswersCompanion Function({
  required String sessionId,
  required int position,
  Value<int?> selectedPosition,
  Value<String?> typedAnswer,
  required int clientSeq,
  Value<int?> timeSpentMs,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$PendingAnswersTableUpdateCompanionBuilder = PendingAnswersCompanion Function({
  Value<String> sessionId,
  Value<int> position,
  Value<int?> selectedPosition,
  Value<String?> typedAnswer,
  Value<int> clientSeq,
  Value<int?> timeSpentMs,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PendingAnswersTableFilterComposer extends Composer<_$AppDatabase, $PendingAnswersTable> {
  $$PendingAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get selectedPosition => $composableBuilder(
    column: $table.selectedPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typedAnswer =>
      $composableBuilder(column: $table.typedAnswer, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get clientSeq =>
      $composableBuilder(column: $table.clientSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeSpentMs =>
      $composableBuilder(column: $table.timeSpentMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingAnswersTableOrderingComposer extends Composer<_$AppDatabase, $PendingAnswersTable> {
  $$PendingAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get selectedPosition => $composableBuilder(
    column: $table.selectedPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typedAnswer =>
      $composableBuilder(column: $table.typedAnswer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get clientSeq =>
      $composableBuilder(column: $table.clientSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeSpentMs =>
      $composableBuilder(column: $table.timeSpentMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingAnswersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingAnswersTable> {
  $$PendingAnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get selectedPosition =>
      $composableBuilder(column: $table.selectedPosition, builder: (column) => column);

  GeneratedColumn<String> get typedAnswer =>
      $composableBuilder(column: $table.typedAnswer, builder: (column) => column);

  GeneratedColumn<int> get clientSeq =>
      $composableBuilder(column: $table.clientSeq, builder: (column) => column);

  GeneratedColumn<int> get timeSpentMs =>
      $composableBuilder(column: $table.timeSpentMs, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingAnswersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingAnswersTable,
          PendingAnswerRow,
          $$PendingAnswersTableFilterComposer,
          $$PendingAnswersTableOrderingComposer,
          $$PendingAnswersTableAnnotationComposer,
          $$PendingAnswersTableCreateCompanionBuilder,
          $$PendingAnswersTableUpdateCompanionBuilder,
          (PendingAnswerRow, BaseReferences<_$AppDatabase, $PendingAnswersTable, PendingAnswerRow>),
          PendingAnswerRow,
          PrefetchHooks Function()
        > {
  $$PendingAnswersTableTableManager(_$AppDatabase db, $PendingAnswersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> selectedPosition = const Value.absent(),
                Value<String?> typedAnswer = const Value.absent(),
                Value<int> clientSeq = const Value.absent(),
                Value<int?> timeSpentMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingAnswersCompanion(
                sessionId: sessionId,
                position: position,
                selectedPosition: selectedPosition,
                typedAnswer: typedAnswer,
                clientSeq: clientSeq,
                timeSpentMs: timeSpentMs,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int position,
                Value<int?> selectedPosition = const Value.absent(),
                Value<String?> typedAnswer = const Value.absent(),
                required int clientSeq,
                Value<int?> timeSpentMs = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingAnswersCompanion.insert(
                sessionId: sessionId,
                position: position,
                selectedPosition: selectedPosition,
                typedAnswer: typedAnswer,
                clientSeq: clientSeq,
                timeSpentMs: timeSpentMs,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingAnswersTable, PendingAnswerRow>(table),
                  BaseReferences<_$AppDatabase, $PendingAnswersTable, PendingAnswerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingAnswersTable,
      PendingAnswerRow,
      $$PendingAnswersTableFilterComposer,
      $$PendingAnswersTableOrderingComposer,
      $$PendingAnswersTableAnnotationComposer,
      $$PendingAnswersTableCreateCompanionBuilder,
      $$PendingAnswersTableUpdateCompanionBuilder,
      (PendingAnswerRow, BaseReferences<_$AppDatabase, $PendingAnswersTable, PendingAnswerRow>),
      PendingAnswerRow,
      PrefetchHooks Function()
    >;
typedef $$RevisionCardsTableCreateCompanionBuilder = RevisionCardsCompanion Function({
  required String id,
  required String kind,
  Value<String?> conceptId,
  Value<String?> questionId,
  Value<String?> front,
  Value<String?> back,
  Value<String?> sourceFilename,
  Value<int?> sourcePage,
  Value<String?> examCode,
  Value<String?> subject,
  Value<String?> topic,
  Value<String> reason,
  required int step,
  required int gapDays,
  required String dueOn,
  Value<int> reviewCount,
  Value<int> lapseCount,
  Value<DateTime?> lastReviewedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$RevisionCardsTableUpdateCompanionBuilder = RevisionCardsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String?> conceptId,
  Value<String?> questionId,
  Value<String?> front,
  Value<String?> back,
  Value<String?> sourceFilename,
  Value<int?> sourcePage,
  Value<String?> examCode,
  Value<String?> subject,
  Value<String?> topic,
  Value<String> reason,
  Value<int> step,
  Value<int> gapDays,
  Value<String> dueOn,
  Value<int> reviewCount,
  Value<int> lapseCount,
  Value<DateTime?> lastReviewedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$RevisionCardsTableReferences
    extends BaseReferences<_$AppDatabase, $RevisionCardsTable, RevisionCardRow> {
  $$RevisionCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConceptsTable _conceptIdTable(_$AppDatabase db) =>
      db.concepts.createAlias('revision_cards__concept_id__concepts__id');

  $$ConceptsTableProcessedTableManager? get conceptId {
    final $_column = $_itemColumn<String>('concept_id');
    if ($_column == null) return null;
    final manager = $$ConceptsTableTableManager(
      $_db,
      $_db.concepts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conceptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$CardReviewsTable, List<CardReviewRow>> _cardReviewsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cardReviews,
    aliasName: 'revision_cards__id__card_reviews__card_id',
  );

  $$CardReviewsTableProcessedTableManager get cardReviewsRefs {
    final manager = $$CardReviewsTableTableManager(
      $_db,
      $_db.cardReviews,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardReviewsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RevisionCardsTableFilterComposer extends Composer<_$AppDatabase, $RevisionCardsTable> {
  $$RevisionCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionId =>
      $composableBuilder(column: $table.questionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceFilename =>
      $composableBuilder(column: $table.sourceFilename, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sourcePage =>
      $composableBuilder(column: $table.sourcePage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get gapDays =>
      $composableBuilder(column: $table.gapDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviewCount =>
      $composableBuilder(column: $table.reviewCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lapseCount =>
      $composableBuilder(column: $table.lapseCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReviewedAt =>
      $composableBuilder(column: $table.lastReviewedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$ConceptsTableFilterComposer get conceptId {
    final $$ConceptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conceptId,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ConceptsTableFilterComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardReviewsRefs(
    Expression<bool> Function($$CardReviewsTableFilterComposer f) f,
  ) {
    final $$CardReviewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardReviews,
      getReferencedColumn: (t) => t.cardId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardReviewsTableFilterComposer(
            $db: $db,
            $table: $db.cardReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RevisionCardsTableOrderingComposer extends Composer<_$AppDatabase, $RevisionCardsTable> {
  $$RevisionCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionId =>
      $composableBuilder(column: $table.questionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceFilename => $composableBuilder(
    column: $table.sourceFilename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourcePage =>
      $composableBuilder(column: $table.sourcePage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get gapDays =>
      $composableBuilder(column: $table.gapDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviewCount =>
      $composableBuilder(column: $table.reviewCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lapseCount =>
      $composableBuilder(column: $table.lapseCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$ConceptsTableOrderingComposer get conceptId {
    final $$ConceptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conceptId,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ConceptsTableOrderingComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RevisionCardsTableAnnotationComposer extends Composer<_$AppDatabase, $RevisionCardsTable> {
  $$RevisionCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get questionId =>
      $composableBuilder(column: $table.questionId, builder: (column) => column);

  GeneratedColumn<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => column);

  GeneratedColumn<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => column);

  GeneratedColumn<String> get sourceFilename =>
      $composableBuilder(column: $table.sourceFilename, builder: (column) => column);

  GeneratedColumn<int> get sourcePage =>
      $composableBuilder(column: $table.sourcePage, builder: (column) => column);

  GeneratedColumn<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<int> get gapDays =>
      $composableBuilder(column: $table.gapDays, builder: (column) => column);

  GeneratedColumn<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);

  GeneratedColumn<int> get reviewCount =>
      $composableBuilder(column: $table.reviewCount, builder: (column) => column);

  GeneratedColumn<int> get lapseCount =>
      $composableBuilder(column: $table.lapseCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewedAt =>
      $composableBuilder(column: $table.lastReviewedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ConceptsTableAnnotationComposer get conceptId {
    final $$ConceptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conceptId,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ConceptsTableAnnotationComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardReviewsRefs<T extends Object>(
    Expression<T> Function($$CardReviewsTableAnnotationComposer a) f,
  ) {
    final $$CardReviewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardReviews,
      getReferencedColumn: (t) => t.cardId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardReviewsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RevisionCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RevisionCardsTable,
          RevisionCardRow,
          $$RevisionCardsTableFilterComposer,
          $$RevisionCardsTableOrderingComposer,
          $$RevisionCardsTableAnnotationComposer,
          $$RevisionCardsTableCreateCompanionBuilder,
          $$RevisionCardsTableUpdateCompanionBuilder,
          (RevisionCardRow, $$RevisionCardsTableReferences),
          RevisionCardRow,
          PrefetchHooks Function({bool conceptId, bool cardReviewsRefs})
        > {
  $$RevisionCardsTableTableManager(_$AppDatabase db, $RevisionCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RevisionCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RevisionCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RevisionCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> conceptId = const Value.absent(),
                Value<String?> questionId = const Value.absent(),
                Value<String?> front = const Value.absent(),
                Value<String?> back = const Value.absent(),
                Value<String?> sourceFilename = const Value.absent(),
                Value<int?> sourcePage = const Value.absent(),
                Value<String?> examCode = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> step = const Value.absent(),
                Value<int> gapDays = const Value.absent(),
                Value<String> dueOn = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RevisionCardsCompanion(
                id: id,
                kind: kind,
                conceptId: conceptId,
                questionId: questionId,
                front: front,
                back: back,
                sourceFilename: sourceFilename,
                sourcePage: sourcePage,
                examCode: examCode,
                subject: subject,
                topic: topic,
                reason: reason,
                step: step,
                gapDays: gapDays,
                dueOn: dueOn,
                reviewCount: reviewCount,
                lapseCount: lapseCount,
                lastReviewedAt: lastReviewedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String?> conceptId = const Value.absent(),
                Value<String?> questionId = const Value.absent(),
                Value<String?> front = const Value.absent(),
                Value<String?> back = const Value.absent(),
                Value<String?> sourceFilename = const Value.absent(),
                Value<int?> sourcePage = const Value.absent(),
                Value<String?> examCode = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<String> reason = const Value.absent(),
                required int step,
                required int gapDays,
                required String dueOn,
                Value<int> reviewCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RevisionCardsCompanion.insert(
                id: id,
                kind: kind,
                conceptId: conceptId,
                questionId: questionId,
                front: front,
                back: back,
                sourceFilename: sourceFilename,
                sourcePage: sourcePage,
                examCode: examCode,
                subject: subject,
                topic: topic,
                reason: reason,
                step: step,
                gapDays: gapDays,
                dueOn: dueOn,
                reviewCount: reviewCount,
                lapseCount: lapseCount,
                lastReviewedAt: lastReviewedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RevisionCardsTable, RevisionCardRow>(table),
                  $$RevisionCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conceptId = false, cardReviewsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardReviewsRefs) db.cardReviews],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conceptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.conceptId,
                        referencedTable: $$RevisionCardsTableReferences._conceptIdTable(db),
                        referencedColumn: $$RevisionCardsTableReferences._conceptIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardReviewsRefs)
                    await $_getPrefetchedData<RevisionCardRow, $RevisionCardsTable, CardReviewRow>(
                      currentTable: table,
                      referencedTable: $$RevisionCardsTableReferences._cardReviewsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RevisionCardsTableReferences(db, table, p0).cardReviewsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RevisionCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RevisionCardsTable,
      RevisionCardRow,
      $$RevisionCardsTableFilterComposer,
      $$RevisionCardsTableOrderingComposer,
      $$RevisionCardsTableAnnotationComposer,
      $$RevisionCardsTableCreateCompanionBuilder,
      $$RevisionCardsTableUpdateCompanionBuilder,
      (RevisionCardRow, $$RevisionCardsTableReferences),
      RevisionCardRow,
      PrefetchHooks Function({bool conceptId, bool cardReviewsRefs})
    >;
typedef $$CardReviewsTableCreateCompanionBuilder = CardReviewsCompanion Function({
  Value<int> id,
  required String cardId,
  Value<String?> syncId,
  required DateTime reviewedAt,
  required String rating,
  required String dueBefore,
  required String dueAfter,
  required int gapDays,
});
typedef $$CardReviewsTableUpdateCompanionBuilder = CardReviewsCompanion Function({
  Value<int> id,
  Value<String> cardId,
  Value<String?> syncId,
  Value<DateTime> reviewedAt,
  Value<String> rating,
  Value<String> dueBefore,
  Value<String> dueAfter,
  Value<int> gapDays,
});

final class $$CardReviewsTableReferences
    extends BaseReferences<_$AppDatabase, $CardReviewsTable, CardReviewRow> {
  $$CardReviewsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RevisionCardsTable _cardIdTable(_$AppDatabase db) =>
      db.revisionCards.createAlias('card_reviews__card_id__revision_cards__id');

  $$RevisionCardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<String>('card_id')!;

    final manager = $$RevisionCardsTableTableManager(
      $_db,
      $_db.revisionCards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CardReviewsTableFilterComposer extends Composer<_$AppDatabase, $CardReviewsTable> {
  $$CardReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reviewedAt =>
      $composableBuilder(column: $table.reviewedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dueBefore =>
      $composableBuilder(column: $table.dueBefore, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dueAfter =>
      $composableBuilder(column: $table.dueAfter, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get gapDays =>
      $composableBuilder(column: $table.gapDays, builder: (column) => ColumnFilters(column));

  $$RevisionCardsTableFilterComposer get cardId {
    final $$RevisionCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.revisionCards,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RevisionCardsTableFilterComposer(
            $db: $db,
            $table: $db.revisionCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardReviewsTableOrderingComposer extends Composer<_$AppDatabase, $CardReviewsTable> {
  $$CardReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reviewedAt =>
      $composableBuilder(column: $table.reviewedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dueBefore =>
      $composableBuilder(column: $table.dueBefore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dueAfter =>
      $composableBuilder(column: $table.dueAfter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get gapDays =>
      $composableBuilder(column: $table.gapDays, builder: (column) => ColumnOrderings(column));

  $$RevisionCardsTableOrderingComposer get cardId {
    final $$RevisionCardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.revisionCards,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RevisionCardsTableOrderingComposer(
            $db: $db,
            $table: $db.revisionCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardReviewsTableAnnotationComposer extends Composer<_$AppDatabase, $CardReviewsTable> {
  $$CardReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt =>
      $composableBuilder(column: $table.reviewedAt, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get dueBefore =>
      $composableBuilder(column: $table.dueBefore, builder: (column) => column);

  GeneratedColumn<String> get dueAfter =>
      $composableBuilder(column: $table.dueAfter, builder: (column) => column);

  GeneratedColumn<int> get gapDays =>
      $composableBuilder(column: $table.gapDays, builder: (column) => column);

  $$RevisionCardsTableAnnotationComposer get cardId {
    final $$RevisionCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.revisionCards,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RevisionCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.revisionCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardReviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardReviewsTable,
          CardReviewRow,
          $$CardReviewsTableFilterComposer,
          $$CardReviewsTableOrderingComposer,
          $$CardReviewsTableAnnotationComposer,
          $$CardReviewsTableCreateCompanionBuilder,
          $$CardReviewsTableUpdateCompanionBuilder,
          (CardReviewRow, $$CardReviewsTableReferences),
          CardReviewRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$CardReviewsTableTableManager(_$AppDatabase db, $CardReviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CardReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CardReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime> reviewedAt = const Value.absent(),
                Value<String> rating = const Value.absent(),
                Value<String> dueBefore = const Value.absent(),
                Value<String> dueAfter = const Value.absent(),
                Value<int> gapDays = const Value.absent(),
              }) => CardReviewsCompanion(
                id: id,
                cardId: cardId,
                syncId: syncId,
                reviewedAt: reviewedAt,
                rating: rating,
                dueBefore: dueBefore,
                dueAfter: dueAfter,
                gapDays: gapDays,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cardId,
                Value<String?> syncId = const Value.absent(),
                required DateTime reviewedAt,
                required String rating,
                required String dueBefore,
                required String dueAfter,
                required int gapDays,
              }) => CardReviewsCompanion.insert(
                id: id,
                cardId: cardId,
                syncId: syncId,
                reviewedAt: reviewedAt,
                rating: rating,
                dueBefore: dueBefore,
                dueAfter: dueAfter,
                gapDays: gapDays,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardReviewsTable, CardReviewRow>(table),
                  $$CardReviewsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$CardReviewsTableReferences._cardIdTable(db),
                        referencedColumn: $$CardReviewsTableReferences._cardIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CardReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardReviewsTable,
      CardReviewRow,
      $$CardReviewsTableFilterComposer,
      $$CardReviewsTableOrderingComposer,
      $$CardReviewsTableAnnotationComposer,
      $$CardReviewsTableCreateCompanionBuilder,
      $$CardReviewsTableUpdateCompanionBuilder,
      (CardReviewRow, $$CardReviewsTableReferences),
      CardReviewRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String entity,
  required String entityId,
  Value<int> version,
  required DateTime changedAt,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> entity,
  Value<String> entityId,
  Value<int> version,
  Value<DateTime> changedAt,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableOrderingComposer extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableAnnotationComposer extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxRow,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (SyncOutboxRow, BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                entity: entity,
                entityId: entityId,
                version: version,
                changedAt: changedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String entityId,
                Value<int> version = const Value.absent(),
                required DateTime changedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                entity: entity,
                entityId: entityId,
                version: version,
                changedAt: changedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxRow>(table),
                  BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxRow,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (SyncOutboxRow, BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$OfflineQuestionsTableCreateCompanionBuilder = OfflineQuestionsCompanion Function({
  required String id,
  required String examCode,
  Value<String?> subject,
  Value<String?> topicId,
  Value<String?> patternId,
  required String data,
  required DateTime savedAt,
  Value<int> rowid,
});
typedef $$OfflineQuestionsTableUpdateCompanionBuilder = OfflineQuestionsCompanion Function({
  Value<String> id,
  Value<String> examCode,
  Value<String?> subject,
  Value<String?> topicId,
  Value<String?> patternId,
  Value<String> data,
  Value<DateTime> savedAt,
  Value<int> rowid,
});

class $$OfflineQuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineQuestionsTable> {
  $$OfflineQuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get patternId =>
      $composableBuilder(column: $table.patternId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => ColumnFilters(column));
}

class $$OfflineQuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineQuestionsTable> {
  $$OfflineQuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get patternId =>
      $composableBuilder(column: $table.patternId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => ColumnOrderings(column));
}

class $$OfflineQuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineQuestionsTable> {
  $$OfflineQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<String> get patternId =>
      $composableBuilder(column: $table.patternId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$OfflineQuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineQuestionsTable,
          OfflineQuestionRow,
          $$OfflineQuestionsTableFilterComposer,
          $$OfflineQuestionsTableOrderingComposer,
          $$OfflineQuestionsTableAnnotationComposer,
          $$OfflineQuestionsTableCreateCompanionBuilder,
          $$OfflineQuestionsTableUpdateCompanionBuilder,
          (
            OfflineQuestionRow,
            BaseReferences<_$AppDatabase, $OfflineQuestionsTable, OfflineQuestionRow>,
          ),
          OfflineQuestionRow,
          PrefetchHooks Function()
        > {
  $$OfflineQuestionsTableTableManager(_$AppDatabase db, $OfflineQuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> examCode = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> topicId = const Value.absent(),
                Value<String?> patternId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineQuestionsCompanion(
                id: id,
                examCode: examCode,
                subject: subject,
                topicId: topicId,
                patternId: patternId,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String examCode,
                Value<String?> subject = const Value.absent(),
                Value<String?> topicId = const Value.absent(),
                Value<String?> patternId = const Value.absent(),
                required String data,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => OfflineQuestionsCompanion.insert(
                id: id,
                examCode: examCode,
                subject: subject,
                topicId: topicId,
                patternId: patternId,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfflineQuestionsTable, OfflineQuestionRow>(table),
                  BaseReferences<_$AppDatabase, $OfflineQuestionsTable, OfflineQuestionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineQuestionsTable,
      OfflineQuestionRow,
      $$OfflineQuestionsTableFilterComposer,
      $$OfflineQuestionsTableOrderingComposer,
      $$OfflineQuestionsTableAnnotationComposer,
      $$OfflineQuestionsTableCreateCompanionBuilder,
      $$OfflineQuestionsTableUpdateCompanionBuilder,
      (
        OfflineQuestionRow,
        BaseReferences<_$AppDatabase, $OfflineQuestionsTable, OfflineQuestionRow>,
      ),
      OfflineQuestionRow,
      PrefetchHooks Function()
    >;
typedef $$OfflineSessionsTableCreateCompanionBuilder = OfflineSessionsCompanion Function({
  required String id,
  required String data,
  Value<bool> finished,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$OfflineSessionsTableUpdateCompanionBuilder = OfflineSessionsCompanion Function({
  Value<String> id,
  Value<String> data,
  Value<bool> finished,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$OfflineSessionsTableFilterComposer extends Composer<_$AppDatabase, $OfflineSessionsTable> {
  $$OfflineSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$OfflineSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineSessionsTable> {
  $$OfflineSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OfflineSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineSessionsTable> {
  $$OfflineSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OfflineSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineSessionsTable,
          OfflineSessionRow,
          $$OfflineSessionsTableFilterComposer,
          $$OfflineSessionsTableOrderingComposer,
          $$OfflineSessionsTableAnnotationComposer,
          $$OfflineSessionsTableCreateCompanionBuilder,
          $$OfflineSessionsTableUpdateCompanionBuilder,
          (
            OfflineSessionRow,
            BaseReferences<_$AppDatabase, $OfflineSessionsTable, OfflineSessionRow>,
          ),
          OfflineSessionRow,
          PrefetchHooks Function()
        > {
  $$OfflineSessionsTableTableManager(_$AppDatabase db, $OfflineSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineSessionsCompanion(
                id: id,
                data: data,
                finished: finished,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String data,
                Value<bool> finished = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OfflineSessionsCompanion.insert(
                id: id,
                data: data,
                finished: finished,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfflineSessionsTable, OfflineSessionRow>(table),
                  BaseReferences<_$AppDatabase, $OfflineSessionsTable, OfflineSessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineSessionsTable,
      OfflineSessionRow,
      $$OfflineSessionsTableFilterComposer,
      $$OfflineSessionsTableOrderingComposer,
      $$OfflineSessionsTableAnnotationComposer,
      $$OfflineSessionsTableCreateCompanionBuilder,
      $$OfflineSessionsTableUpdateCompanionBuilder,
      (OfflineSessionRow, BaseReferences<_$AppDatabase, $OfflineSessionsTable, OfflineSessionRow>),
      OfflineSessionRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConceptsTableTableManager get concepts => $$ConceptsTableTableManager(_db, _db.concepts);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$StudyProfilesTableTableManager get studyProfiles =>
      $$StudyProfilesTableTableManager(_db, _db.studyProfiles);
  $$PendingAnswersTableTableManager get pendingAnswers =>
      $$PendingAnswersTableTableManager(_db, _db.pendingAnswers);
  $$RevisionCardsTableTableManager get revisionCards =>
      $$RevisionCardsTableTableManager(_db, _db.revisionCards);
  $$CardReviewsTableTableManager get cardReviews =>
      $$CardReviewsTableTableManager(_db, _db.cardReviews);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$OfflineQuestionsTableTableManager get offlineQuestions =>
      $$OfflineQuestionsTableTableManager(_db, _db.offlineQuestions);
  $$OfflineSessionsTableTableManager get offlineSessions =>
      $$OfflineSessionsTableTableManager(_db, _db.offlineSessions);
}
