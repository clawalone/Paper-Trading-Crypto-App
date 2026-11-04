import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(null); // Fallback if not configured
  }
  final auth = FirebaseAuth.instance;
  return Stream<User?>.multi((controller) {
    if (auth.currentUser != null) {
      controller.add(auth.currentUser);
    }
    final sub = auth.authStateChanges().listen(
      (user) {
        if (!controller.isClosed) controller.add(user);
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );
    controller.onCancel = () => sub.cancel();
  });
});

class AuthController {
  static Future<void> signIn(String email, String password) async {
    if (Firebase.apps.isEmpty) throw Exception('Firebase is not configured. Please run `flutterfire configure`.');
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signUp(String email, String password) async {
    if (Firebase.apps.isEmpty) throw Exception('Firebase is not configured. Please run `flutterfire configure`.');
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) throw Exception('Firebase is not configured. Please run `flutterfire configure`.');
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // User canceled sign-in

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseAuth.instance.signOut();
  }
}
