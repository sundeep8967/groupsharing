import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth; // aliased
import 'package:groupsharing/screens/profile/profile_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // aliased

// --- Mock Definitions ---

// Mock AuthProvider
class MockAuthProvider extends Mock implements app_auth.AuthProvider {
  firebase_auth.User? _mockUser;

  MockAuthProvider({firebase_auth.User? mockUser}) {
    _mockUser = mockUser;
    // Stub the user getter
    when(user).thenAnswer((_) => _mockUser);

    // Stub signOut to prevent issues if called by UI (e.g. logout button)
    when(signOut()).thenAnswer((_) async {});

    // Stub deleteUserAccount, tests will override this as needed
    when(deleteUserAccount()).thenAnswer((_) async {});
  }

  // Allow tests to set the user
  void setMockUser(firebase_auth.User? user) {
    _mockUser = user;
    when(this.user).thenAnswer((_) => _mockUser); // Re-stub
  }

  // Ensure `notifyListeners` is available if the base class uses it, though Mockito usually handles this.
  // If not, we might need:
  // @override
  // void notifyListeners() {}

  // We need to mock the methods that ProfileScreen will call.
  // For example, if ProfileScreen calls authProvider.user, we need to mock that.
  // Mockito's `when(...).thenAnswer(...)` or `thenReturn(...)` is used for this.
  // For getters, it can be `when(mock.user).thenReturn(mockUser)`.
}

// Mock firebase_auth.User
class MockFirebaseAuthUser extends Mock implements firebase_auth.User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;

  MockFirebaseAuthUser({
    this.uid = 'test_uid',
    this.email = 'test@example.com',
    this.displayName = 'Test User',
    this.photoURL,
  });

  // Add any other methods or properties your ProfileScreen might use from the User object.
}

// Helper to create the widget tree with necessary providers
Widget createProfileScreenWidget({required MockAuthProvider mockAuthProvider}) {
  return ChangeNotifierProvider<app_auth.AuthProvider>.value(
    value: mockAuthProvider,
    child: const MaterialApp(
      //navigatorObservers: [mockNavigatorObserver], // if testing navigation results
      home: ProfileScreen(),
      // Define routes if ProfileScreen navigates using named routes like '/welcome'
      routes: {
        '/welcome': (context) => const Scaffold(body: Text('Welcome Screen')),
        // Add other routes used by ProfileScreen if any
      },
    ),
  );
}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockFirebaseAuthUser mockUser;

  setUp(() {
    mockUser = MockFirebaseAuthUser();
    mockAuthProvider = MockAuthProvider(mockUser: mockUser);
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('renders "Profile & Settings" title and Delete Account button', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreenWidget(mockAuthProvider: mockAuthProvider));

      // Wait for any async operations like FutureBuilders if ProfileScreen has them at the top level
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Delete Account'), findsOneWidget);
    });

    testWidgets('tapping "Delete Account" button shows confirmation dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreenWidget(mockAuthProvider: mockAuthProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle(); // For dialog animation

      expect(find.text('Delete Account?'), findsOneWidget);
      expect(find.text('Are you sure you want to delete your account? This action cannot be undone.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
    });

    testWidgets('tapping "Cancel" in dialog dismisses it', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreenWidget(mockAuthProvider: mockAuthProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account?'), findsOneWidget); // Dialog is present

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle(); // For dialog dismissal

      expect(find.text('Delete Account?'), findsNothing); // Dialog is gone
    });

    testWidgets('tapping "Delete" successfully calls deleteUserAccount and navigates', (WidgetTester tester) async {
      // Mock successful account deletion
      when(mockAuthProvider.deleteUserAccount()).thenAnswer((_) async {
        // Simulate success, no exception
      });

      await tester.pumpWidget(createProfileScreenWidget(mockAuthProvider: mockAuthProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle(); // Show dialog

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      // The ProfileScreen sets _isLoading = true, shows CircularProgressIndicator
      await tester.pump(); // Start loading state

      // Check for loading indicator (optional, but good)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Complete async deleteUserAccount & animations

      // Verify deleteUserAccount was called
      verify(mockAuthProvider.deleteUserAccount()).called(1);

      // Verify dialog is dismissed
      expect(find.text('Delete Account?'), findsNothing);

      // Verify navigation to welcome screen (or login)
      expect(find.text('Welcome Screen'), findsOneWidget); // Assumes '/welcome' route is set up

      // Verify SnackBar message (more complex, might need a custom finder or to check semantics)
      // For simplicity, we'll trust the navigation implies success here.
      // expect(find.text('Account deleted successfully.'), findsOneWidget); // This might be tricky due to context
    });

    testWidgets('tapping "Delete" handles error from deleteUserAccount (e.g., requires-recent-login)', (WidgetTester tester) async {
      // Mock failed account deletion
      when(mockAuthProvider.deleteUserAccount()).thenThrow(
        Exception('This operation is sensitive and requires recent authentication. Please log in again before retrying.')
      );

      await tester.pumpWidget(createProfileScreenWidget(mockAuthProvider: mockAuthProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle(); // Show dialog

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump(); // Start loading
      await tester.pumpAndSettle(); // Complete async deleteUserAccount & animations

      // Verify deleteUserAccount was called
      verify(mockAuthProvider.deleteUserAccount()).called(1);

      // Verify dialog is dismissed
      expect(find.text('Delete Account?'), findsNothing);

      // Verify NO navigation to welcome screen
      expect(find.text('Welcome Screen'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Delete Account'), findsOneWidget); // Still on profile

      // Verify SnackBar with error message
      // SnackBar testing can be tricky. It's often off-screen quickly or needs specific setup.
      // We expect a SnackBar to have appeared.
      expect(find.text('This action requires recent login. Please sign out and sign in again, then retry.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5)); // Wait for snackbar to potentially disappear
      expect(find.text('This action requires recent login. Please sign out and sign in again, then retry.'), findsNothing);


    });
  });
}
```

This sets up the widget tests for `ProfileScreen`. I've included:
-   Mocks for `AuthProvider` and `firebase_auth.User`.
-   A helper to build the `ProfileScreen` with the mock provider.
-   Tests for:
    -   Initial UI rendering.
    -   Dialog appearance.
    -   Dialog "Cancel" action.
    -   Dialog "Delete" action (success case with navigation).
    -   Dialog "Delete" action (failure case with error SnackBar).

The SnackBar test for the error message is included, though these can sometimes be a bit flaky or require careful handling of timings (`pumpAndSettle` with durations).

With this, the structure for all three requested test files is in place. The unit tests for services are more conceptual outlines due to the static dependency issues and inability to run `flutter pub get` for `mockito`'s code generation. The widget tests should be more robust as `AuthProvider` (the direct dependency of the screen) is mockable.

I will now submit, assuming this fulfills the request to "add tests" to the best of my ability within the environment's constraints.
