# mfrontend

Flutter frontend for the MHealth patient and therapist app.

## Patient and therapist codes

Therapists choose one of the four specializations while creating an account and receive a unique five-digit code after registration. Patients choose their specialization after creating an account and receive a matching therapist's name, specialization, license number, and code. Patients see and can copy the therapist's code; their own code is available in their private Profile page. On the Messages page, patients enter their therapist's code, while therapists select an assigned patient by the patient's custom alias when set, or their full name otherwise. Messaging is limited to the assigned patient-therapist pair.

Both account types can open Profile from the top bar to view their account details and five-digit ID, and sign out. Patient check-ins display emotion-based colors; therapist clinical summaries show a color swatch and descriptive color name.

Run the Laravel API from `MBackend` with `php artisan serve --host 127.0.0.1 --port 8000`, then run this Flutter app from `MFrontend` with `flutter run -d chrome`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
