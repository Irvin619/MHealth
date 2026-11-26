import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/message_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.service, required this.role});

  final MessageService service;
  final String role;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _userCode = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _assignedPatients = [];
  String? _activeUserCode;
  String? _selectedPatientCode;
  String? _error;
  bool _busy = false;
  bool _loadingAssignedPatients = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'therapist') _loadAssignedPatients();
  }

  @override
  void dispose() {
    _userCode.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedPatients() async {
    setState(() => _loadingAssignedPatients = true);
    try {
      final response = await widget.service.fetchAssignedPatients();
      if (mounted) {
        setState(() => _assignedPatients = responseItems(response));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load assigned patients.');
      }
    } finally {
      if (mounted) setState(() => _loadingAssignedPatients = false);
    }
  }

  Future<void> _loadThread() async {
    final code = _userCode.text.trim();
    if (!RegExp(r'^[0-9]{5}$').hasMatch(code)) {
      setState(() => _error = 'Enter the other person’s 5-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.service.fetchThread(code);
      if (mounted) {
        setState(() {
          _activeUserCode = code;
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
    final code = _activeUserCode ?? _userCode.text.trim();
    if (!RegExp(r'^[0-9]{5}$').hasMatch(code) || _body.text.trim().isEmpty) {
      setState(() => _error = 'Enter a 5-digit code and a message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.sendMessage(
        receiverCode: code,
        body: _body.text.trim(),
      );
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
            if (widget.role == 'therapist') ...[
              if (_loadingAssignedPatients)
                const LinearProgressIndicator()
              else if (_assignedPatients.isEmpty)
                const Text('No patients are assigned to you yet.')
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedPatientCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned patient',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    for (final patient in _assignedPatients)
                      DropdownMenuItem(
                        value: patient['user_code']?.toString(),
                        child: Text(
                          patient['name']?.toString() ?? 'Assigned patient',
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (code) {
                          if (code == null) return;
                          setState(() {
                            _selectedPatientCode = code;
                            _userCode.text = code;
                          });
                          _loadThread();
                        },
                ),
              const SizedBox(height: 12),
            ],
            if (widget.role != 'therapist')
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userCode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Other person’s 5-digit code',
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
                  final sender = message['is_mine'] == true
                      ? 'you'
                      : message['sender_code']?.toString() ??
                            'your care-team contact';
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(message['body']?.toString() ?? ''),
                    subtitle: Text(
                      'From $sender · ${message['sent_at'] ?? ''}',
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
