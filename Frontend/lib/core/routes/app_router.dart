import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_step1_screen.dart';
import '../../features/auth/screens/register_step2_screen.dart';
import '../../features/auth/screens/register_otp_screen.dart';
import '../../features/auth/screens/register_success_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/trip/screens/add_trip_screen.dart';
import '../../features/trip/screens/trip_details_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/itinerary/screens/itinerary_screen.dart';
import '../../features/itinerary/screens/add_event_screen.dart';
import '../../features/photos/screens/gallery_screen.dart';
import '../../features/documents/screens/all_documents_screen.dart';
import '../../features/documents/screens/members_list_screen.dart';
import '../../features/trip/screens/destinations_screen.dart';
import '../../features/trip/screens/add_destination_screen.dart';
import '../../features/participants/screens/join_requests_screen.dart';
import '../../features/trip/screens/map_screen.dart';
import '../../features/trip/screens/trip_overview_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.login:
        return _fadeRoute(const LoginScreen());
      case AppRoutes.registerStep1:
        return _slideRoute(const RegisterStep1Screen());
      case AppRoutes.registerStep2:
        return _slideRoute(const RegisterStep2Screen());
      case AppRoutes.registerOtp:
        return _slideRoute(const RegisterOtpScreen());
      case AppRoutes.registerSuccess:
        return _fadeRoute(const RegisterSuccessScreen());
      case AppRoutes.dashboard:
        return _fadeRoute(const DashboardScreen());
      case AppRoutes.addTrip:
        return _slideRoute(const AddTripScreen());
      case AppRoutes.tripDetails:
        return _slideRoute(const TripDetailsScreen());
      case AppRoutes.chat:
        return _slideRoute(const ChatScreen());
      case AppRoutes.itinerary:
        return _slideRoute(const ItineraryScreen());
      case AppRoutes.addEvent:
        return _slideRoute(const AddEventScreen());
      case AppRoutes.gallery:
        return _slideRoute(const GalleryScreen());
      case AppRoutes.allDocuments:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slideRoute(AllDocumentsScreen(
          title: args?['title'],
          documents: args?['documents'],
        ));
      case AppRoutes.membersList:
        return _slideRoute(const MembersListScreen());
      case AppRoutes.destinations:
        return _slideRoute(const DestinationsScreen());
      case AppRoutes.addDestination:
        return _slideRoute(const AddDestinationScreen());
      case AppRoutes.joinRequests:
        return _slideRoute(const JoinRequestsScreen());
      case AppRoutes.map:
        return _slideRoute(const MapScreen());
      case AppRoutes.tripOverview:
        return _slideRoute(const TripOverviewScreen());
      case AppRoutes.tasks:
        return _slideRoute(const TasksScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  static Route<dynamic> _fadeRoute(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  static Route<dynamic> _slideRoute(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}
