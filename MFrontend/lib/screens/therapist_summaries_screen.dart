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

  Widget _summaryDetails(String? text) {
    if (text == null || text.isEmpty) {
      return const Text('No summary details.');
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in decoded.entries)
              if (entry.key.toLowerCase() == 'color')
                _EmotionalColor(value: entry.value?.toString())
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${entry.key}: ${_formatValue(entry.value)}'),
                ),
          ],
        );
      }
    } on FormatException {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in text.split('\n'))
            if (RegExp(r'^\s*Color:', caseSensitive: false).hasMatch(line))
              _EmotionalColor(
                value: RegExp(
                  r'^\s*Color:\s*(.*)$',
                  caseSensitive: false,
                ).firstMatch(line)?.group(1),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line),
              ),
        ],
      );
    }
    return Text(text);
  }

  String _formatValue(Object? value) {
    if (value == null) return 'Not provided';
    if (value is List) return value.join(', ');
    return value.toString();
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
                  _summaryDetails(summary['summary_text']?.toString()),
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
    final normalizedStatus = status.toLowerCase();
    final high = normalizedStatus == 'high';
    final moderate = normalizedStatus == 'moderate';
    final background = high
        ? const Color(0xFFFFE7E1)
        : moderate
        ? const Color(0xFFFFF1D8)
        : const Color(0xFFE1F1EC);
    final foreground = high
        ? const Color(0xFF9B3028)
        : moderate
        ? const Color(0xFF8A5A13)
        : const Color(0xFF28695D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmotionalColor extends StatelessWidget {
  const _EmotionalColor({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(value);
    final label = color == null ? 'Not available' : _colorName(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33000000)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text('Emotional color: $label'),
        ],
      ),
    );
  }

  Color? _parseColor(String? value) {
    if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    final parsed = int.tryParse(value.substring(1), radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }

  String _colorName(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.12) {
      if (hsl.lightness > 0.75) return 'light gray';
      if (hsl.lightness < 0.3) return 'charcoal';
      return 'soft gray';
    }

    final hue = hsl.hue;
    final hueName = hue < 15 || hue >= 345
        ? 'rose'
        : hue < 45
        ? 'amber'
        : hue < 70
        ? 'gold'
        : hue < 155
        ? 'green'
        : hue < 195
        ? 'teal'
        : hue < 250
        ? 'blue'
        : hue < 290
        ? 'violet'
        : 'plum';
    final tone = hsl.lightness < 0.28
        ? 'deep'
        : hsl.lightness > 0.76
        ? 'pale'
        : hsl.saturation < 0.45
        ? 'muted'
        : 'vivid';
    return '$tone $hueName';
  }
}
