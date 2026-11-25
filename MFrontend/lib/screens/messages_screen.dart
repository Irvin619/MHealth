import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/message_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.service});

  final MessageService service;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _userId = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  String? _activeUserId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _userId.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    final id = _userId.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter the other user’s ID.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.service.fetchThread(id);
      if (mounted) {
        setState(() {
          _activeUserId = id;
          _messages = responseItems(response);
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load this conversation.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final id = _activeUserId ?? _userId.text.trim();
    if (id.isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = 'Enter a user ID and a message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.sendMessage(receiverId: id, body: _body.text.trim());
      _body.clear();
      await _loadThread();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to send this message.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Messages',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Private conversations with your care team.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Other user ID',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _loadThread(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _busy ? null : _loadThread,
                  tooltip: 'Load conversation',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      Expanded(
        child: _messages.isEmpty
            ? const Center(child: Text('Choose a user to open a conversation.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(message['body']?.toString() ?? ''),
                    subtitle: Text(
                      'From ${message['sender_id'] ?? 'unknown'} · ${message['sent_at'] ?? ''}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _body,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _busy ? null : _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _busy ? null : _send,
                tooltip: 'Send message',
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
