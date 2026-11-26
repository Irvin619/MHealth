import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../specializations.dart';

class PatientSpecializationScreen extends StatefulWidget {
  const PatientSpecializationScreen({
    super.key,
    required this.authService,
    required this.onAssigned,
  });

  final AuthService authService;
  final VoidCallback onAssigned;

  @override
  State<PatientSpecializationScreen> createState() =>
      _PatientSpecializationScreenState();
}

class _PatientSpecializationScreenState
    extends State<PatientSpecializationScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _specialization;
  String? _error;
  bool _busy = false;

  Future<void> _findTherapist() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await widget.authService.assignSpecialization(
        _specialization!,
      );
      final therapist = response['therapist'];
      if (therapist is! Map<String, dynamic>) {
        throw const ApiException(
          'The server did not return therapist details.',
          200,
        );
      }

      final details = _TherapistDetails(
        name: therapist['name']?.toString() ?? '',
        specialization: therapist['specialization']?.toString() ?? '',
        licenseNumber: therapist['license_number']?.toString() ?? '',
        userCode: therapist['user_code']?.toString() ?? '',
      );
      if (details.name.isEmpty ||
          details.specialization.isEmpty ||
          details.licenseNumber.isEmpty ||
          !RegExp(r'^[0-9]{5}$').hasMatch(details.userCode)) {
        throw const ApiException(
          'The server returned incomplete therapist details.',
          200,
        );
      }

      if (!mounted) return;
      await _showTherapistDetails(details);
      if (mounted) {
        await widget.authService.completeSpecialization();
        widget.onAssigned();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Unable to find a therapist. Check the API connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showTherapistDetails(_TherapistDetails details) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your therapist match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${details.name}'),
            const SizedBox(height: 8),
            Text('Specialization: ${details.specialization}'),
            const SizedBox(height: 8),
            Text('License number: ${details.licenseNumber}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Therapist ID: '),
                SelectableText(
                  details.userCode,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: details.userCode));
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Therapist ID copied.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy ID'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

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
                      'Choose your specialization',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We’ll match you with a therapist in this area. '
                      'You can use their five-digit ID to start a conversation.',
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _specialization,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Mental health specialization',
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
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _specialization = value;
                              _error = null;
                            }),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _busy ? null : _findTherapist,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Find my therapist'),
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

class _TherapistDetails {
  const _TherapistDetails({
    required this.name,
    required this.specialization,
    required this.licenseNumber,
    required this.userCode,
  });

  final String name;
  final String specialization;
  final String licenseNumber;
  final String userCode;
}
