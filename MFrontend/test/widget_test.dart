// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mfrontend/main.dart';
import 'package:mfrontend/screens/auth_screen.dart';
import 'package:mfrontend/screens/emotion_map_screen.dart';
import 'package:mfrontend/screens/messages_screen.dart';
import 'package:mfrontend/screens/patient_specialization_screen.dart';
import 'package:mfrontend/screens/profile_screen.dart';
import 'package:mfrontend/screens/therapist_summaries_screen.dart';
import 'package:mfrontend/services/api_client.dart';
import 'package:mfrontend/services/auth_service.dart';
import 'package:mfrontend/services/emotion_map_service.dart';
import 'package:mfrontend/services/message_service.dart';
import 'package:mfrontend/services/summary_service.dart';

void main() {
  testWidgets('logged-out startup shows authentication screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MHealthApp());
    await tester.pumpAndSettle();

    expect(find.text('MHealth'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('legacy patient session is sent to specialization selection', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'patient-token',
      'user_role': 'client',
    });

    await tester.pumpWidget(const MHealthApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose your specialization'), findsOneWidget);
    expect(find.text('Find my therapist'), findsOneWidget);
    expect(find.text('12345'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('user_role'),
      'patient',
    );
  });

  testWidgets('therapist workspace does not show patient check-in', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'therapist-token',
      'user_role': 'therapist',
    });

    await tester.pumpWidget(const MHealthApp());
    await tester.pumpAndSettle();

    expect(find.text('Check-in'), findsNothing);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Summaries'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
  });

  testWidgets(
    'patient registration goes to specialization without showing own code',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        expect(jsonDecode(request.body)['role'], 'patient');
        return http.Response(
          jsonEncode({
            'user': {
              'id': 12,
              'role': 'patient',
              'client': {'specialization': null, 'therapist_id': null},
            },
            'token': 'patient-token',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final authService = AuthService(
        ApiClient(client: client, baseUrl: 'http://localhost/api'),
      );
      var authenticated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(
            authService: authService,
            onAuthenticated: () => authenticated = true,
          ),
        ),
      );
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test Patient');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'patient@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');
      final createAccountButton = find.widgetWithText(
        FilledButton,
        'Create account',
      );
      await tester.ensureVisible(createAccountButton);
      await tester.pumpAndSettle();
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(authenticated, isTrue);
      expect(find.text('Account created'), findsNothing);
      expect(find.text('Your Patient code is:'), findsNothing);

      await tester.pumpWidget(const MHealthApp());
      await tester.pumpAndSettle();
      expect(find.text('Choose your specialization'), findsOneWidget);
      expect(find.text('12345'), findsNothing);
    },
  );

  testWidgets('therapist registration shows a copyable five-digit code', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final clipboard = <String, dynamic>{};
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.addAll(Map<String, dynamic>.from(call.arguments as Map));
        }
        return null;
      },
    );
    final client = MockClient((request) async {
      expect(request.url.path, '/api/register');
      return http.Response(
        jsonEncode({
          'user': {'id': 1, 'role': 'therapist', 'user_code': '12345'},
          'token': 'test-token',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final authService = AuthService(
      ApiClient(client: client, baseUrl: 'http://localhost/api'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(authService: authService, onAuthenticated: () {}),
      ),
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final accountTypeDropdown = find
        .byType(DropdownButtonFormField<String>)
        .first;
    await tester.ensureVisible(accountTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(accountTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Therapist').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Test Patient');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'patient@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(4), 'LIC-12345');
    final specializationDropdown = find
        .byType(DropdownButtonFormField<String>)
        .last;
    await tester.ensureVisible(specializationDropdown);
    await tester.pumpAndSettle();
    await tester.tap(specializationDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trauma & PTSD').last);
    await tester.pumpAndSettle();

    final createAccountButton = find.widgetWithText(
      FilledButton,
      'Create account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.pumpAndSettle();
    await tester.tap(createAccountButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Account created'), findsOneWidget);
    expect(find.text('Your Therapist code is:'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);

    await tester.tap(find.text('Copy code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(clipboard['text'], '12345');
    expect(find.text('Code copied to clipboard.'), findsOneWidget);
  });

  testWidgets('patient receives therapist details and can copy therapist ID', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'patient-token',
      'user_role': 'patient',
      'needs_specialization': true,
    });
    final clipboard = <String, dynamic>{};
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.addAll(Map<String, dynamic>.from(call.arguments as Map));
        }
        return null;
      },
    );
    final client = MockClient((request) async {
      expect(request.url.path, '/api/patient/specialization');
      expect(jsonDecode(request.body)['specialization'], 'Trauma & PTSD');
      return http.Response(
        jsonEncode({
          'specialization': 'Trauma & PTSD',
          'therapist': {
            'name': 'Taylor Therapist',
            'specialization': 'Trauma & PTSD',
            'license_number': 'LIC-54321',
            'user_code': '54321',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final authService = AuthService(
      ApiClient(client: client, baseUrl: 'http://localhost/api'),
    );
    var assigned = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PatientSpecializationScreen(
          authService: authService,
          onAssigned: () => assigned = true,
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trauma & PTSD').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find my therapist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your therapist match'), findsOneWidget);
    expect(find.text('Name: Taylor Therapist'), findsOneWidget);
    expect(find.text('Specialization: Trauma & PTSD'), findsOneWidget);
    expect(find.text('License number: LIC-54321'), findsOneWidget);
    expect(find.text('54321'), findsOneWidget);

    await tester.tap(find.text('Copy ID'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(clipboard['text'], '54321');

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(assigned, isTrue);
  });

  testWidgets('therapist can open an assigned patient conversation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'therapist-token'});
    var threadRequested = false;
    final client = MockClient((request) async {
      if (request.url.path == '/api/therapist/patients') {
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'patient-alias', 'user_code': '54321'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/messages/54321') {
        threadRequested = true;
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected API request: ${request.url.path}');
    });
    final service = MessageService(
      ApiClient(client: client, baseUrl: 'http://localhost/api'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesScreen(service: service, role: 'therapist'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assigned patient'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('patient-alias'), findsOneWidget);
    await tester.tap(find.text('patient-alias').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(threadRequested, isTrue);
    expect(find.text('patient-alias'), findsWidgets);
    expect(find.text('Other person’s 5-digit code'), findsNothing);
  });

  testWidgets('patient profile shows account details and can sign out', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'patient-token'});
    var signedOut = false;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/profile');
      return http.Response(
        jsonEncode({
          'profile': {
            'name': 'Taylor Patient',
            'email': 'taylor@example.com',
            'role': 'patient',
            'user_code': '12345',
            'anonymous_alias': 'Quiet Willow',
            'specialization': 'Trauma & PTSD',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          authService: AuthService(
            ApiClient(client: client, baseUrl: 'http://localhost/api'),
          ),
          onBack: () {},
          onLogout: () async {
            signedOut = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Taylor Patient'), findsWidgets);
    expect(find.text('taylor@example.com'), findsOneWidget);
    expect(find.text('Quiet Willow'), findsOneWidget);
    expect(find.text('Trauma & PTSD'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final signOutButton = find.text('Sign out');
    expect(signOutButton, findsOneWidget);
    await tester.tap(signOutButton);
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  testWidgets('therapist profile shows license and specialization', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'therapist-token'});
    final client = MockClient((request) async {
      expect(request.url.path, '/api/profile');
      return http.Response(
        jsonEncode({
          'profile': {
            'name': 'Jordan Therapist',
            'email': 'jordan@example.com',
            'role': 'therapist',
            'user_code': '54321',
            'license_number': 'LIC-54321',
            'specialization': 'Clinical Counselling',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          authService: AuthService(
            ApiClient(client: client, baseUrl: 'http://localhost/api'),
          ),
          onBack: () {},
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jordan Therapist'), findsWidgets);
    expect(find.text('jordan@example.com'), findsOneWidget);
    expect(find.text('LIC-54321'), findsOneWidget);
    expect(find.text('Clinical Counselling'), findsOneWidget);
    expect(find.text('54321'), findsOneWidget);
  });

  testWidgets(
    'clinical summary names the emotional color and shows its swatch',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'therapist-token'});
      final client = MockClient((request) async {
        expect(request.url.path, '/api/summaries');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'summary_id': 3,
                'summary_text': jsonEncode({
                  'Color': '#B9736B',
                  'Valence score': 2,
                  'Emotion nodes': ['numb', 'anxious'],
                }),
                'risk_status': 'moderate',
                'generated_at': '2026-11-26T07:52:05.000000Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TherapistSummariesScreen(
              service: SummaryService(
                ApiClient(client: client, baseUrl: 'http://localhost/api'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emotional color: muted rose'), findsOneWidget);
      expect(find.text('Color: #B9736B'), findsNothing);
      expect(find.text('Valence score: 2'), findsOneWidget);
      expect(find.text('Emotion nodes: numb, anxious'), findsOneWidget);
    },
  );

  testWidgets('check-in uses emotion colors and requires context', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'patient-token'});
    var submitted = false;
    Map<String, dynamic>? submittedBody;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      submitted = true;
      submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'crisis_override': false, 'risk_status': 'low'}),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = EmotionMapService(
      ApiClient(client: client, baseUrl: 'http://localhost/api'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EmotionMapScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a color'), findsNothing);
    expect(find.text('What emotions are present?'), findsOneWidget);
    final sadChip = find.ancestor(
      of: find.text('sad'),
      matching: find.byType(FilterChip),
    );
    await tester.ensureVisible(sadChip);
    await tester.tap(sadChip);
    await tester.pumpAndSettle();

    final selectedSadChip = tester.widget<FilterChip>(sadChip);
    expect(selectedSadChip.selected, isTrue);
    expect(selectedSadChip.selectedColor, const Color(0xFF5279A5));

    final saveButton = find.widgetWithText(FilledButton, 'Save check-in');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Add context before saving your check-in.'),
      findsOneWidget,
    );
    expect(submitted, isFalse);

    final contextField = find.byType(TextField).last;
    await tester.ensureVisible(contextField);
    await tester.enterText(contextField, 'A difficult day at work.');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(submittedBody?['color_hex'], '#5279A5');
    expect(submittedBody?['emotion_nodes'], ['sad']);
    expect(
      (submittedBody?['prompt'] as Map<String, dynamic>)['disclosure_text'],
      'A difficult day at work.',
    );
  });
}
