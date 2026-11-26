import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../specializations.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  final AuthService authService;
  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  final _alias = TextEditingController();
  final _license = TextEditingController();
  final _specialization = TextEditingController();
  bool _isRegistering = false;
  bool _busy = false;
  String _role = 'patient';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    _alias.dispose();
    _license.dispose();
    _specialization.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegistering) {
        final response = await widget.authService.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          passwordConfirmation: _passwordConfirmation.text,
          role: _role,
          anonymousAlias: _alias.text,
          licenseNumber: _license.text.trim(),
          specialization: _specialization.text,
        );
        if (_role == 'therapist') {
          final user = response['user'];
          final userCode = user is Map ? user['user_code']?.toString() : null;
          if (userCode == null || !RegExp(r'^[0-9]{5}$').hasMatch(userCode)) {
            throw const ApiException(
              'The server did not return a valid five-digit account code.',
              200,
            );
          }
          if (!mounted) return;
          await _showAccountCode(userCode);
          if (!mounted) return;
        }
      } else {
        await widget.authService.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      widget.onAuthenticated();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Unable to reach the service. Check the API connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showAccountCode(String code) async {
    final accountType = _role == 'patient' ? 'Patient' : 'Therapist';
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your $accountType code is:'),
            const SizedBox(height: 12),
            Center(
              child: SelectableText(
                code,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Save this code and share it with your care-team contact. '
              'Enter their code on the Messages page to open the conversation.',
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required.' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      size: 42,
                      color: Color(0xFF287C70),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'MHealth',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A quieter space to check in and connect.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in')),
                        ButtonSegment(
                          value: true,
                          label: Text('Create account'),
                        ),
                      ],
                      selected: {_isRegistering},
                      onSelectionChanged: (value) => setState(() {
                        _isRegistering = value.first;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (_isRegistering) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (value) => _required(value, 'Name'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Enter a valid email address.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => value == null || value.length < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    if (_isRegistering) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordConfirmation,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'Account type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'patient',
                            child: Text('Patient'),
                          ),
                          DropdownMenuItem(
                            value: 'therapist',
                            child: Text('Therapist'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _role = value ?? 'patient'),
                      ),
                      const SizedBox(height: 12),
                      if (_role == 'patient')
                        TextFormField(
                          controller: _alias,
                          decoration: const InputDecoration(
                            labelText: 'Anonymous alias (optional)',
                          ),
                        )
                      else ...[
                        TextFormField(
                          controller: _license,
                          decoration: const InputDecoration(
                            labelText: 'License number',
                          ),
                          validator: (value) =>
                              _required(value, 'License number'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _specialization.text.isEmpty
                              ? null
                              : _specialization.text,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Specialization',
                          ),
                          items: [
                            for (final specialization
                                in mentalHealthSpecializations)
                              DropdownMenuItem(
                                value: specialization,
                                child: Text(
                                  specialization,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          validator: (value) =>
                              value == null ? 'Select a specialization.' : null,
                          onChanged: (value) =>
                              _specialization.text = value ?? '',
                        ),
                      ],
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(
                        _isRegistering ? 'Create account' : 'Sign in',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
