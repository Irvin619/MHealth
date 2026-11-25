import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/summary_service.dart';

class TherapistSummariesScreen extends StatefulWidget {
  const TherapistSummariesScreen({super.key, required this.service});

  final SummaryService service;

  @override
  State<TherapistSummariesScreen> createState() =>
      _TherapistSummariesScreenState();
}

class _TherapistSummariesScreenState extends State<TherapistSummariesScreen> {
  List<Map<String, dynamic>> _summaries = [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.service.fetchSummaries();
      if (mounted) setState(() => _summaries = responseItems(response));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load summaries.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatSummary(String? text) {
    if (text == null || text.isEmpty) return 'No summary details.';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n');
      }
    } on FormatException {
      return text;
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Clinical summaries',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _load,
              tooltip: 'Refresh summaries',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text('Recent check-ins shared for therapist review.'),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_busy && _error == null && _summaries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('No summaries are available yet.')),
          ),
        for (final summary in _summaries)
          Card(
            margin: const EdgeInsets.only(top: 14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Summary ${summary['summary_id'] ?? ''}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _RiskLabel(
                        status: summary['risk_status']?.toString() ?? 'unknown',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatSummary(summary['summary_text']?.toString())),
                  const SizedBox(height: 8),
                  Text(
                    'Generated ${summary['generated_at'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _RiskLabel extends StatelessWidget {
  const _RiskLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final high = status.toLowerCase() == 'high';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: high ? const Color(0xFFFFE7E1) : const Color(0xFFE1F1EC),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: high ? const Color(0xFF9B3028) : const Color(0xFF28695D),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
