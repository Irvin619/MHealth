import 'package:material_ui/material_ui.dart';

import 'screens/auth_screen.dart';
import 'screens/emotion_map_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/patient_specialization_screen.dart';
import 'screens/profile_screen.dart';
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
  bool _needsSpecialization = false;
  String _role = 'patient';

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
    final needsSpecialization = token != null && token.isNotEmpty
        ? await _auth.needsSpecialization()
        : false;
    if (!mounted) return;
    setState(() {
      _authenticated = token != null && token.isNotEmpty;
      _needsSpecialization = needsSpecialization;
      _role = role ?? 'patient';
      _checkingSession = false;
    });
  }

  Future<void> _onAuthenticated() async {
    final role = await _auth.role();
    final needsSpecialization = await _auth.needsSpecialization();
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _needsSpecialization = needsSpecialization;
      _role = role ?? 'patient';
    });
  }

  void _onSpecializationAssigned() {
    setState(() => _needsSpecialization = false);
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() {
      _authenticated = false;
      _needsSpecialization = false;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MHealth',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF287C70),
            surface: const Color(0xFFF5F8F6),
          ).copyWith(
            secondary: const Color(0xFFC17A52),
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFF6E5DA),
            onSecondaryContainer: const Color(0xFF51301F),
            tertiary: const Color(0xFF846C91),
            onTertiary: Colors.white,
            tertiaryContainer: const Color(0xFFEDE3F1),
            onTertiaryContainer: const Color(0xFF392A42),
          ),
      scaffoldBackgroundColor: const Color(0xFFF5F8F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F8F6),
        foregroundColor: Color(0xFF20332F),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x1A20332F),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2EBE7)),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFF5F8F6),
        indicatorColor: Color(0xFFD7EEE8),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFD7EEE8),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8E0DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8E0DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF287C70), width: 1.5),
        ),
      ),
    ),
    home: _checkingSession
        ? const _StartupScreen()
        : _authenticated
        ? _needsSpecialization
              ? PatientSpecializationScreen(
                  authService: _auth,
                  onAssigned: _onSpecializationAssigned,
                )
              : _Workspace(
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
  bool _showProfile = false;

  List<_TabItem> get _tabs => [
    if (widget.role == 'patient')
      _TabItem(
        'Check-in',
        Icons.spa_outlined,
        EmotionMapScreen(service: widget.emotionMaps),
      ),
    _TabItem(
      'Messages',
      Icons.chat_bubble_outline,
      MessagesScreen(service: widget.messages, role: widget.role),
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
    if (_showProfile) {
      return ProfileScreen(
        authService: widget.authService,
        onBack: () => setState(() => _showProfile = false),
        onLogout: widget.onLogout,
      );
    }

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
                onPressed: () => setState(() => _showProfile = true),
                tooltip: 'Profile',
                icon: const Icon(Icons.account_circle_outlined),
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
