// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart'; // 추가
import './app.dart';
import './providers/auth_provider.dart';
import './providers/student_provider.dart';
import './providers/task_provider.dart';
import './providers/reflection_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 전역 네비게이터 키
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 웹 URL 해시 제거
  setUrlStrategy(PathUrlStrategy());

  // Firebase 초기화
  await _initializeFirebase();

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

// Firebase 초기화 함수
Future<void> _initializeFirebase() async {
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
}
