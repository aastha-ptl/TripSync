import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/services/auth_service.dart';

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initDeepLinks() async {
    // Process initial deep link if app was cold started
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for incoming deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Error listening to links: $err');
    });
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
      final token = uri.pathSegments.first;
      await processInviteToken(token);
    }
  }

  Future<void> processInviteToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (isLoggedIn) {
      // If already logged in, go straight to Join Trip screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(
          AppRoutes.joinTrip,
          arguments: {'inviteToken': token},
        );
      }
    } else {
      // Store pending token and let the normal flow take them to login
      await prefs.setString('pendingInviteToken', token);
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  Future<String?> getPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pendingInviteToken');
  }

  Future<void> clearPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pendingInviteToken');
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
