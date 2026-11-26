import 'api_client.dart';

class MessageService {
  MessageService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> sendMessage({
    required String receiverCode,
    required String body,
  }) => _api.post(
    '/messages',
    body: {'receiver_code': receiverCode, 'body': body},
  );

  Future<Map<String, dynamic>> fetchThread(String userCode) =>
      _api.get('/messages/${Uri.encodeComponent(userCode)}');

  Future<Map<String, dynamic>> fetchAssignedPatients() =>
      _api.get('/therapist/patients');
}
