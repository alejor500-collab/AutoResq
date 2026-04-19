import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthInstanceProvider = Provider<firebase_auth.FirebaseAuth>((ref) {
  return firebase_auth.FirebaseAuth.instance;
});

final firebaseUserProvider = StreamProvider<firebase_auth.User?>((ref) {
  return ref.watch(firebaseAuthInstanceProvider).authStateChanges();
});
