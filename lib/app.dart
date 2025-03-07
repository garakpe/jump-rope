import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/student/dashboard_screen.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'providers/auth_provider.dart';
import 'utils/theme.dart';

class JumpRopeApp extends StatelessWidget {
  const JumpRopeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '줄넘기 학습 관리',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (!authProvider.isLoggedIn) {
            return const LoginScreen();
          } else if (authProvider.isTeacher) {
            return const TeacherDashboard();
          } else {
            return const StudentDashboard();
          }
        },
      ),
    );
  }
}