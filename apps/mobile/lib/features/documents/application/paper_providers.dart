import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../question_bank/data/questions_repository.dart';
import '../../question_bank/domain/question.dart';
import '../domain/paper_solve.dart';
import 'documents_providers.dart';

/// All questions of a paper to solve, in printed order (every page of the list is fetched).
final paperQuestionsProvider = FutureProvider.autoDispose.family<List<BankQuestion>, String>((
  ref,
  documentId,
) async {
  final repository = ref.watch(questionsRepositoryProvider);
  final all = <BankQuestion>[];
  var query = QuestionQuery(documentId: documentId);
  while (true) {
    final (items, total) = await repository.list(query);
    all.addAll(items);
    if (items.isEmpty || all.length >= total) break;
    query = query.from(all.length);
  }
  return solvableQuestions(all);
}, retry: (_, _) => null);

/// One page of a paper's original PDF as an image (document id, 1-based page).
/// Kept for [pageCacheTime] after it scrolls out of view, so scrolling back doesn't ask the
/// server to render the page again.
final paperPageProvider = FutureProvider.autoDispose.family<Uint8List, (String, int)>((ref, page) {
  final link = ref.keepAlive();
  final timer = Timer(pageCacheTime, link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(documentsRepositoryProvider).pageImage(page.$1, page.$2);
}, retry: (_, _) => null);

const pageCacheTime = Duration(minutes: 10);
