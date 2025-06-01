import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../services/exam_service.dart';
import '../services/auth_service.dart';
import '../services/user_exam_service.dart';
import '../services/notification_service.dart';
import '../services/detailed_exam_service.dart';
import '../services/question_service.dart';
import '../services/exam_session_service.dart';
import '../services/analytics_service.dart';
import 'auth_provider.dart';
import '../services/user_service.dart';
import '../services/payment_service.dart';
import '../services/admin_service.dart';
import '../services/chatbot_service.dart';

class AppProviders extends StatelessWidget {
  final Widget child;
  final LocalizationService localizationService;
  final AuthService authService;
  final NotificationService notificationService;

  const AppProviders({
    Key? key, 
    required this.child,
    required this.localizationService,
    required this.authService,
    required this.notificationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalizationService>.value(
          value: localizationService,
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<ExamService>(
          create: (_) => ExamService(),
        ),
        ChangeNotifierProvider<AuthService>.value(
          value: authService,
        ),
        ChangeNotifierProvider<UserExamService>(
          create: (_) => UserExamService(),
        ),
        ChangeNotifierProvider<NotificationService>.value(
          value: notificationService,
        ),
        ChangeNotifierProvider<DetailedExamService>(
          create: (_) => DetailedExamService(),
        ),
        ChangeNotifierProvider<ExamSessionService>(
          create: (_) => ExamSessionService(),
        ),
        ChangeNotifierProvider<AnalyticsService>(
          create: (_) => AnalyticsService(),
        ),
        ChangeNotifierProvider<UserService>(
          create: (_) => UserService(),
        ),
        ChangeNotifierProvider<PaymentService>(
          create: (_) => PaymentService(),
        ),
        ChangeNotifierProvider<QuestionService>(
          create: (context) => QuestionService(),
        ),
        ChangeNotifierProvider<ChatbotService>(
          create: (_) => ChatbotService(),
        ),
        ProxyProvider<AuthService, AdminService>(
          update: (context, authService, previous) => AdminService(
            accessToken: authService.accessToken,
          ),
        ),
      ],
      child: child,
    );
  }
}

// Extension to make it easier to access services
extension ContextExtension on BuildContext {
  LocalizationService get localization => Provider.of<LocalizationService>(this, listen: false);
  
  // Shorthand for translate
  String tr(String key, {Map<String, String>? params}) => localization.translate(key, params: params);
  
  // Services shorthands
  ExamService get examService => Provider.of<ExamService>(this, listen: false);
  AuthService get authService => Provider.of<AuthService>(this, listen: false);
  UserExamService get userExamService => Provider.of<UserExamService>(this, listen: false);
  NotificationService get notificationService => Provider.of<NotificationService>(this, listen: false);
  DetailedExamService get detailedExamService => Provider.of<DetailedExamService>(this, listen: false);
  QuestionService get questionService => Provider.of<QuestionService>(this, listen: false);
  ExamSessionService get examSessionService => Provider.of<ExamSessionService>(this, listen: false);
  AnalyticsService get analyticsService => Provider.of<AnalyticsService>(this, listen: false);
  UserService get userService => Provider.of<UserService>(this, listen: false);
  PaymentService get paymentService => Provider.of<PaymentService>(this, listen: false);
  AdminService get adminService => Provider.of<AdminService>(this, listen: false);
  ChatbotService get chatbotService => Provider.of<ChatbotService>(this, listen: false);
}

// Extension to access auth provider from context
extension AuthContextExtension on BuildContext {
  AuthProvider get authProvider {
    return Provider.of<AuthProvider>(this, listen: false);
  }
}

// Extension to access payment service from context
extension PaymentContextExtension on BuildContext {
  PaymentService get paymentService {
    return Provider.of<PaymentService>(this, listen: false);
  }
} 