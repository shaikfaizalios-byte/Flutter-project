import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a list of strings as a JSON array in a TEXT column.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => (jsonDecode(fromDb) as List<Object?>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Locally stored concepts. IDs are client-generated UUIDs so rows can later be
/// synchronised without remapping (see docs/database.md, "Sync rules").
@DataClassName('ConceptRow')
class Concepts extends Table {
  TextColumn get id => text()();
  TextColumn get examCode => text().withLength(min: 1, max: 32)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get subject => text().withLength(min: 1, max: 100)();
  TextColumn get topic => text().withLength(min: 1, max: 100)();
  TextColumn get subtopic => text().nullable()();
  TextColumn get language => text().withLength(min: 2, max: 8)();
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get sourceReference => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value store for device-local settings (language, theme, ...).
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
