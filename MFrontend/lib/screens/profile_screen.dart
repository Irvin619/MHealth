import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.onBack,
    required this.onLogout,
  });

  final AuthService authService;
  final VoidCallback onBack;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.authService.fetchProfile();
      if (mounted) setState(() => _profile = profile);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back to workspace',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Profile'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ProfileError(message: _error!, onRetry: _loadProfile)
              : _buildProfile(theme, _profile ?? const {}),
        ),
      ),
    );
  }

  Widget _buildProfile(ThemeData theme, Map<String, dynamic> profile) {
    final isPatient = profile['role'] == 'patient';
    final displayName = profile['name']?.toString() ?? 'MHealth member';
    final roleLabel = isPatient ? 'Patient' : 'Therapist';
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.tertiaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.primary,
                child: Text(
                  _initials(displayName),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _ProfileDetail(
                  icon: Icons.badge_outlined,
                  label: 'Full name',
                  value: displayName,
                ),
                _ProfileDetail(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile['email']?.toString() ?? 'Not available',
                ),
                _ProfileDetail(
                  icon: Icons.person_outline,
                  label: 'Account type',
                  value: roleLabel,
                ),
                if (isPatient)
                  _ProfileDetail(
                    icon: Icons.visibility_off_outlined,
                    label: 'Anonymous alias',
                    value: profile['anonymous_alias']?.toString() ?? 'Not set',
                  ),
                if (!isPatient)
                  _ProfileDetail(
                    icon: Icons.verified_user_outlined,
                    label: 'License number',
                    value:
                        profile['license_number']?.toString() ??
                        'Not available',
                  ),
                _ProfileDetail(
                  icon: Icons.spa_outlined,
                  label: 'Specialization',
                  value:
                      profile['specialization']?.toString() ??
                      (isPatient ? 'Not selected yet' : 'Not available'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.key_outlined, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your 5-digit ID',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        profile['user_code']?.toString() ?? 'Not available',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 12, 4, 18),
          child: Text('Your password stays private and is never displayed.'),
        ),
        FilledButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
