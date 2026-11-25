import 'api_client.dart';

class SummaryService {
  SummaryService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> fetchSummaries() => _api.get('/summaries');
}
