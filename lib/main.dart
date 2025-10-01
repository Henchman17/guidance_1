import 'package:flutter/material.dart';
import 'login_page.dart';
import 'navigation_rail_example.dart';
import 'shared_enums.dart';
import 'admin/admin_dashboard.dart';
import 'admin/admin_users_page.dart';
import 'admin/admin_appointments_page.dart';
import 'admin/admin_analytics_page.dart';
import 'counselor/counselor_dashboard.dart';
import 'counselor/counselor_students_page.dart';
import 'counselor/counselor_appointments_page.dart';
import 'counselor/counselor_sessions_page.dart';
import 'student/guidance_scheduling_page.dart';
import 'student/answerable_forms.dart';
import 'student/good_moral_request.dart';
import 'student/student_panel.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PLSP Guidance',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const NavigationRailExample(),
        '/admin-dashboard': (context) => const AdminDashboardPage(),
        '/admin-users': (context) => const AdminUsersPage(),
        '/admin-appointments': (context) => const AdminAppointmentsPage(),
        '/admin-analytics': (context) => const AdminAnalyticsPage(),
        '/counselor-dashboard': (context) => const CounselorDashboardPage(),
        '/counselor-students': (context) => const CounselorStudentsPage(),
        '/counselor-appointments': (context) => const CounselorAppointmentsPage(),
        '/counselor-sessions': (context) => const CounselorSessionsPage(),
        '/guidance-scheduling': (context) => const GuidanceSchedulingPage(status: SchedulingStatus.none),
        '/answerable-forms': (context) => const AnswerableForms(),
        '/good-moral-request': (context) => const GoodMoralRequest(),
      },
      home: const LoginPage(),
    );
  }
}