import 'concept.dart';

/// Concept storage contract. The Phase 2 implementation is local-only
/// (offline-first); a synchronising implementation can replace it later without
/// changing the presentation layer.
abstract interface class ConceptsRepository {
  /// Emits the matching concepts, most recently updated first, and re-emits on change.
  Stream<List<Concept>> watch({String query = '', bool includeArchived = false});

  /// Validates, normalises and stores a new concept. Throws [InvalidConceptException].
  Future<Concept> create(ConceptDraft draft);

  Future<void> setArchived(String id, {required bool archived});
}
