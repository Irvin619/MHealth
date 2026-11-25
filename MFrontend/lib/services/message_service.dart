import 'api_client.dart';

class MessageService {
  MessageService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String body,
  }) => _api.post(
    '/messages',
    body: {'receiver_id': int.tryParse(receiverId) ?? receiverId, 'body': body},
  );

  Future<Map<String, dynamic>> fetchThread(String userId) =>
      _api.get('/messages/${Uri.encodeComponent(userId)}');
}
