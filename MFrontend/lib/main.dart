import 'package:material_ui/material_ui.dart';

import 'screens/auth_screen.dart';
import 'screens/emotion_map_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/therapist_summaries_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/emotion_map_service.dart';
import 'services/message_service.dart';
import 'services/summary_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MHealthApp());
}

class MHealthApp extends StatefulWidget {
  const MHealthApp({super.key});

  @override
  State<MHealthApp> createState() => _MHealthAppState();
}

class _MHealthAppState extends State<MHealthApp> {
  late final ApiClient _api;
  late final AuthService _auth;
  late final EmotionMapService _emotionMaps;
  late final MessageService _messages;
  late final SummaryService _summaries;
  bool _checkingSession = true;
  bool _authenticated = false;
  String _role = 'client';

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _auth = AuthService(_api);
    _emotionMaps = EmotionMapService(_api);
    _messages = MessageService(_api);
    _summaries = SummaryService(_api);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _auth.token();
    final role = await _auth.role();
    if (!mounted) return;
    setState(() {
      _authenticated = token != null && token.isNotEmpty;
      _role = role ?? 'client';
      _checkingSession = false;
    });
  }

  Future<void> _onAuthenticated() async {
    final role = await _auth.role();
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _role = role ?? 'client';
    });
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MHealth',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF287C70),
        surface: const Color(0xFFF8FAF8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAF8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAF8),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8E0DC)),
        ),
      ),
    ),
    home: _checkingSession
        ? const _StartupScreen()
        : _authenticated
        ? _Workspace(
            role: _role,
            authService: _auth,
            emotionMaps: _emotionMaps,
            messages: _messages,
            summaries: _summaries,
            onLogout: _logout,
          )
        : AuthScreen(authService: _auth, onAuthenticated: _onAuthenticated),
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Workspace extends StatefulWidget {
  const _Workspace({
    required this.role,
    required this.authService,
    required this.emotionMaps,
    required this.messages,
    required this.summaries,
    required this.onLogout,
  });

  final String role;
  final AuthService authService;
  final EmotionMapService emotionMaps;
  final MessageService messages;
  final SummaryService summaries;
  final Future<void> Function() onLogout;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  int _index = 0;

  List<_TabItem> get _tabs => [
    _TabItem(
      'Check-in',
      Icons.spa_outlined,
      EmotionMapScreen(service: widget.emotionMaps),
    ),
    _TabItem(
      'Messages',
      Icons.chat_bubble_outline,
      MessagesScreen(service: widget.messages),
    ),
    if (widget.role == 'therapist')
      _TabItem(
        'Summaries',
        Icons.assignment_outlined,
        TherapistSummariesScreen(service: widget.summaries),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (_index >= tabs.length) _index = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              tabs[_index].label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                onPressed: widget.onLogout,
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: wide
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: (index) =>
                              setState(() => _index = index),
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            for (final tab in tabs)
                              NavigationRailDestination(
                                icon: Icon(tab.icon),
                                label: Text(tab.label),
                              ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: IndexedStack(
                            index: _index,
                            children: [for (final tab in tabs) tab.page],
                          ),
                        ),
                      ],
                    )
                  : IndexedStack(
                      index: _index,
                      children: [for (final tab in tabs) tab.page],
                    ),
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (index) =>
                      setState(() => _index = index),
                  destinations: [
                    for (final tab in tabs)
                      NavigationDestination(
                        icon: Icon(tab.icon),
                        label: tab.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon, this.page);

  final String label;
  final IconData icon;
  final Widget page;
}
