import 'api_client.dart';

class EmotionMapService {
  EmotionMapService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> submitEmotionMap({
    required String colorHex,
    required int valenceScore,
    required int intensityLevel,
    required List<String> emotionNodes,
    String? promptCategory,
    String? disclosureText,
  }) {
    final hasPrompt =
        promptCategory?.trim().isNotEmpty == true ||
        disclosureText?.trim().isNotEmpty == true;
    return _api.post(
      '/emotion-maps',
      body: {
        'color_hex': colorHex,
        'valence_score': valenceScore,
        'intensity_level': intensityLevel,
        'emotion_nodes': emotionNodes,
        if (hasPrompt)
          'prompt': {
            'prompt_category': promptCategory?.trim().isNotEmpty == true
                ? promptCategory!.trim()
                : 'reflection',
            'disclosure_text': disclosureText?.trim(),
          },
      },
    );
  }

  Future<Map<String, dynamic>> fetchHistory() => _api.get('/emotion-maps');
}
