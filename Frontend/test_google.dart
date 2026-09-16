import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  final googleSignIn = GoogleSignIn.instance;
  debugPrint(googleSignIn.toString());
}
