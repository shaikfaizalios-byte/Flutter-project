import 'package:preploop/features/insights/data/insights_repository.dart';
import 'package:preploop/features/insights/domain/radar.dart';
import 'package:preploop/features/insights/domain/repeats.dart';

/// Repetition reports for app tests: empty by default, sharing off.
class FakeInsightsRepository implements InsightsRepository {
  FakeInsightsRepository({
    this.report = const RepeatsReport(papers: PapersBasis(total: 0, dated: 0, undated: 0)),
    this.radarReport = const RadarReport(basis: RadarBasis(shifts: 0, minAccounts: 2)),
    this.share = false,
    this.eligiblePapers = 0,
    this.sharedReport = const RepeatsReport(papers: PapersBasis(total: 0, dated: 0, undated: 0)),
  });

  /// Returned for scope "shared" (the shared bank).
  RepeatsReport sharedReport;
  final scopes = <String>[];

  RepeatsReport report;
  RadarReport radarReport;
  bool share;
  int eligiblePapers;
  final requests = <String?>[];
  final shareChanges = <bool>[];

  @override
  Future<RepeatsReport> repeats({String? examCode, String scope = 'mine'}) async {
    requests.add(examCode);
    scopes.add(scope);
    return scope == 'shared' ? sharedReport : report;
  }

  @override
  Future<RadarReport> radar({String? examCode}) async => radarReport;

  @override
  Future<RadarSettings> radarSettings() async =>
      RadarSettings(share: share, eligiblePapers: eligiblePapers, minAccounts: 2);

  @override
  Future<RadarSettings> setRadarShare({required bool share}) async {
    shareChanges.add(share);
    this.share = share;
    return radarSettings();
  }
}
