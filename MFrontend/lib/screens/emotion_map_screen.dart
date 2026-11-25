import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../services/emotion_map_service.dart';

class EmotionMapScreen extends StatefulWidget {
  const EmotionMapScreen({super.key, required this.service});

  final EmotionMapService service;

  @override
  State<EmotionMapScreen> createState() => _EmotionMapScreenState();
}

class _EmotionMapScreenState extends State<EmotionMapScreen> {
  static const _colors = <Color>[
    Color(0xFF287C70),
    Color(0xFFE2A644),
    Color(0xFFDF7665),
    Color(0xFF5279A5),
    Color(0xFF9A6B83),
    Color(0xFF8A9B61),
  ];
  static const _emotions = <String>[
    'calm',
    'hopeful',
    'connected',
    'focused',
    'grateful',
    'anxious',
    'sad',
    'angry',
    'overwhelmed',
    'numb',
  ];

  final _disclosure = TextEditingController();
  final Set<String> _selected = {};
  Color _color = _colors.first;
  double _valence = 6;
  double _intensity = 4;
  String _category = 'daily check-in';
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _disclosure.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await widget.service.fetchHistory();
      if (mounted) setState(() => _history = responseItems(response));
    } catch (_) {
      // History is supplementary; allow check-ins even if it is unavailable.
    }
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      setState(() {
        _error = 'Choose at least one emotion to continue.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.service.submitEmotionMap(
        colorHex:
            '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        valenceScore: _valence.round(),
        intensityLevel: _intensity.round(),
        emotionNodes: _selected.toList(),
        promptCategory: _category,
        disclosureText: _disclosure.text,
      );
      if (!mounted) return;
      setState(() => _result = result);
      await _loadHistory();
      if (result['crisis_override'] == true ||
          result['risk_status'] == 'high') {
        _showCrisisDialog(result);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to submit your check-in. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCrisisDialog(Map<String, dynamic> result) {
    final helplines = result['helplines'] is List
        ? result['helplines'] as List
        : const [];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.support_outlined,
          color: Color(0xFFB63D32),
          size: 32,
        ),
        title: const Text('You deserve support right now'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you may be in immediate danger, contact local emergency services or someone you trust.',
            ),
            const SizedBox(height: 12),
            for (final item in helplines.whereType<Map>())
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${item['name'] ?? 'Crisis support'}: ${item['call'] ?? item['instruction'] ?? ''}',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Check in',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Take a moment to notice what is here.'),
        if (_result?['crisis_override'] == true ||
            _result?['risk_status'] == 'high')
          Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7E1),
              border: Border.all(color: const Color(0xFFB63D32)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'High-risk response detected. Support resources were shown; please reach out to a trusted person or local crisis service.',
            ),
          ),
        const SizedBox(height: 22),
        _sectionTitle('Choose a color'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: [
            for (final color in _colors)
              _ColorSwatch(
                color: color,
                selected: color == _color,
                onTap: () => setState(() => _color = color),
              ),
          ],
        ),
        const SizedBox(height: 22),
        _slider(
          'Valence',
          _valence,
          (value) => setState(() => _valence = value),
          lowLabel: 'Difficult',
          highLabel: 'Pleasant',
        ),
        _slider(
          'Intensity',
          _intensity,
          (value) => setState(() => _intensity = value),
          lowLabel: 'Subtle',
          highLabel: 'Strong',
        ),
        const SizedBox(height: 10),
        _sectionTitle('What emotions are present?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final emotion in _emotions)
              FilterChip(
                label: Text(emotion),
                selected: _selected.contains(emotion),
                onSelected: (selected) => setState(
                  () => selected
                      ? _selected.add(emotion)
                      : _selected.remove(emotion),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('Add context (optional)'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Prompt category'),
          onChanged: (value) => _category = value,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _disclosure,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Anything you want to share?',
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Save check-in'),
        ),
        if (_result != null && _result!['crisis_override'] != true) ...[
          const SizedBox(height: 14),
          Text(
            'Saved · ${_result!['risk_status'] ?? 'reviewed'} risk',
            style: theme.textTheme.titleSmall,
          ),
        ],
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 28),
          _sectionTitle('Recent check-ins'),
          for (final item in _history.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _parseColor(item['color_hex']?.toString()),
                radius: 15,
              ),
              title: Text(
                'Valence ${item['valence_score'] ?? '-'} · Intensity ${item['intensity_level'] ?? '-'}',
              ),
              subtitle: Text(item['created_at']?.toString() ?? ''),
            ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
  );

  Widget _slider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    required String lowLabel,
    required String highLabel,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _sectionTitle(label)),
          Text(
            value.round().toString(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      Slider(
        value: value,
        min: 1,
        max: 10,
        divisions: 9,
        label: value.round().toString(),
        onChanged: onChanged,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(lowLabel), Text(highLabel)],
      ),
      const SizedBox(height: 12),
    ],
  );

  Color? _parseColor(String? value) {
    if (value == null || !value.startsWith('#')) return null;
    final parsed = int.tryParse(value.substring(1), radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Color ${color.toARGB32().toRadixString(16)}',
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    ),
  );
}
