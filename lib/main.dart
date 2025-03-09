// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/reflection_provider.dart';
import 'providers/student_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 전역 네비게이터 키 추가
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy()); // 웹 URL에서 해시 제거

  // Firebase 초기화 (웹에서 문제 해결을 위한 방법)
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyBfHiCftWbN4jTbQ_p_1-sMoH4XGQvaEss",
          authDomain: "jump-rope-app.firebaseapp.com",
          projectId: "jump-rope-app",
          storageBucket: "jump-rope-app.firebasestorage.app",
          messagingSenderId: "555175745259",
          appId: "1:555175745259:web:2c5cc3166b76efabf990ae"),
    );

    // 오프라인 캐싱 활성화
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, // 오프라인 데이터 유지
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // 캐시 크기 제한 없음
    );

    print("Firebase 초기화 성공");
  } catch (e) {
    print("Firebase 초기화 실패: $e");
  }

  // 앱 실행
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ReflectionProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
      ],
      child: const JumpRopeApp(),
    ),
  );
}
