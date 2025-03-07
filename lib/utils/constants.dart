import 'package:flutter/material.dart';

/// 색상 상수
class AppColors {
  // 기본 색상
  static const Color primary = Color(0xFF3E7BFA);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF5F5F5);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  
  // 텍스트 색상
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textDisabled = Color(0xFF999999);
  
  // 기능적 색상
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF2196F3);
  
  // 개인/단체 줄넘기 색상
  static const Color individualPrimary = Color(0xFF3E7BFA);
  static const Color individualLight = Color(0xFFE3F2FD);
  static const Color groupPrimary = Color(0xFF4CAF50);
  static const Color groupLight = Color(0xFFE8F5E9);
  
  // 성찰 색상
  static const Color reflectionPrimary = Color(0xFFFF9800);
  static const Color reflectionLight = Color(0xFFFFF3E0);
}

/// 간격 상수
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 크기 상수
class AppSizes {
  static const double borderRadius = 16.0;
  static const double buttonHeight = 48.0;
  static const double iconSize = 24.0;
  static const double avatarSize = 40.0;
  
  static const double fontSizeXS = 12.0;
  static const double fontSizeSM = 14.0;
  static const double fontSizeMD = 16.0;
  static const double fontSizeLG = 18.0;
  static const double fontSizeXL = 20.0;
  static const double fontSizeXXL = 24.0;
}

/// 애니메이션 지속 시간
class AppDurations {
  static const Duration shortest = Duration(milliseconds: 150);
  static const Duration short = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration long = Duration(milliseconds: 500);
}

/// 그림자 스타일
class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.1),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.1),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];
}

/// API 엔드포인트 (실제 연동 시 사용)
class ApiEndpoints {
  static const String baseUrl = 'https://api.example.com';
  static const String login = '/auth/login';
  static const String students = '/students';
  static const String teachers = '/teachers';
  static const String tasks = '/tasks';
  static const String reflections = '/reflections';
}

/// 로컬 스토리지 키 (실제 데이터 저장 시 사용)
class StorageKeys {
  static const String authToken = 'auth_token';
  static const String userData = 'user_data';
  static const String currentLevel = 'current_level';
  static const String currentWeek = 'current_week';
  static const String stampCount = 'stamp_count';
}

/// 앱 전역 문자열
class AppStrings {
  // 탭 레이블
  static const String homeTab = '홈';
  static const String progressTab = '진도';
  static const String reflectionTab = '성찰';
  
  // 버튼 레이블
  static const String login = '로그인';
  static const String logout = '로그아웃';
  static const String save = '저장하기';
  static const String back = '돌아가기';
  static const String edit = '편집하기';
  
  // 제목
  static const String appTitle = '줄넘기 학습 관리';
  static const String teacherAppTitle = '줄넘기 학습 관리 (교사용)';
  static const String groupManagement = '모둠 관리';
  static const String learningStatus = '학습 현황';
  static const String reflectionManagement = '성찰 관리';
  
  // 관리자 화면 레이블
  static const String selectClass = '학급 선택';
  static const String individualJumpRope = '개인줄넘기';
  static const String groupJumpRope = '단체줄넘기';
  static const String byGroup = '모둠별로 보기';
  static const String byRoster = '명렬표로 보기';
  
  // 안내 메시지
  static const String noClassSelected = '왼쪽 상단에서 학급을 선택해주세요';
  static const String reflectionComplete = '성찰 작성이 저장되었습니다.';
  static const String groupSaved = '모둠 구성이 저장되었습니다.';
}