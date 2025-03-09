// lib/utils/constants.dart
import 'package:flutter/material.dart';

/// 앱 전체에서 사용하는 색상 상수
class AppColors {
  // 기본 테마 색상
  static const Color primary = Color(0xFF3E7BFA);
  static const Color secondary = Color(0xFF00BFA5);
  static const Color background = Color(0xFFF5F5F5);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // 텍스트 색상
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);

  // 개인/단체 줄넘기 구분 색상
  static const Color individualPrimary = Color(0xFF3E7BFA); // 파란색
  static const Color individualLight = Color(0xFFE3F2FD);
  static const Color groupPrimary = Color(0xFF4CAF50); // 녹색
  static const Color groupLight = Color(0xFFE8F5E9);
  static const Color reflectionPrimary = Color(0xFFFF9800); // 주황색
  static const Color reflectionLight = Color(0xFFFFF3E0);

  // 상태 색상
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
}

/// 앱 전체에서 사용하는 크기 상수
class AppSizes {
  // 폰트 크기
  static const double fontSizeXS = 12.0;
  static const double fontSizeSM = 14.0;
  static const double fontSizeMD = 16.0;
  static const double fontSizeLG = 18.0;
  static const double fontSizeXL = 20.0;
  static const double fontSizeXXL = 24.0;

  // 간격 관련
  static const double borderRadius = 16.0;
  static const double cardElevation = 2.0;
  static const double iconSizeSM = 16.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 32.0;

  // 버튼 크기
  static const double buttonHeight = 48.0;
  static const double buttonWidthSmall = 120.0;
  static const double buttonWidthMedium = 200.0;
  static const double buttonWidthLarge = double.infinity;
}

/// 앱 전체에서 사용하는 간격 상수
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 앱 전체에서 사용하는 그림자 상수
class AppShadows {
  static const List<BoxShadow> none = [];

  static final List<BoxShadow> small = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> large = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

/// 앱에서 사용하는 텍스트 상수
class AppStrings {
  // 앱 타이틀
  static const String appTitle = '줄넘기 학습 관리';
  static const String teacherAppTitle = '줄넘기 학습 관리 (교사용)';

  // 탭 제목
  static const String home = '홈';
  static const String task = '과제'; // 추가된 과제 탭 제목

  // 줄넘기 유형
  static const String individualJumpRope = '개인줄넘기';
  static const String groupJumpRope = '단체줄넘기';

  // 교사 대시보드 메뉴
  static const String groupManagement = '모둠 관리';
  static const String learningStatus = '학습 현황';
  static const String reflectionManagement = '성찰 관리';

  // 알림 메시지
  static const String syncInProgress = '데이터를 동기화하고 있습니다...';
  static const String syncComplete = '데이터 동기화가 완료되었습니다.';
  static const String offlineMode = '오프라인 모드입니다. 인터넷 연결 시 자동으로 동기화됩니다.';
  static const String groupSaved = '모둠 정보가 저장되었습니다.';
  static const String reflectionComplete = '성찰 작성이 완료되었습니다.';

  // 기타 메시지
  static const String selectClass = '학급 선택';
  static const String noClassSelected = '학급을 선택해주세요';

  // 로그인 관련
  static const String login = '로그인';
  static const String logout = '로그아웃';
  static const String studentLogin = '학생 로그인';
  static const String teacherLogin = '교사 로그인';

  // 버튼 및 액션
  static const String save = '저장';
  static const String cancel = '취소';
  static const String confirm = '확인';
  static const String delete = '삭제';
  static const String edit = '편집';
  static const String add = '추가';
  static const String view = '보기';
  static const String submit = '제출';

  // 오류 메시지
  static const String errorOccurred = '오류가 발생했습니다';
  static const String networkError = '네트워크 연결 오류가 발생했습니다';
  static const String dataLoadingError = '데이터를 불러오는 중 오류가 발생했습니다';
  static const String loginError = '로그인 중 오류가 발생했습니다';

  // 확인 메시지
  static const String deleteConfirm = '정말 삭제하시겠습니까?';
  static const String exitConfirm = '정말 나가시겠습니까?';
}

/// 저장소 키 상수
class StorageKeys {
  static const String currentUser = 'current_user';
  static const String currentLevel = 'current_level';
  static const String currentWeek = 'current_week';
  static const String selectedClass = 'selected_class';
  static const String pendingTaskUpdates = 'pending_task_updates';
  static const String lastSyncTime = 'last_sync_time';
  static const String offlineData = 'offline_data';
}

/// 기타 상수 모음
class AppConstants {
  // 앱 버전 정보
  static const String appVersion = '1.0.0';

  // API 관련
  static const int apiTimeout = 30000; // ms
  static const int retryCount = 3;

  // 이미지 크기
  static const double maxImageWidth = 800;
  static const double maxImageHeight = 600;

  // 과제 관련
  static const int defaultTaskLevel = 1;
  static const int maxTaskLevel = 6;
  static const int requiredSuccessPerStudent = 5; // 단체줄넘기 시작을 위한 개인 성공 수

  // 주차 정보
  static const int totalWeeks = 3;
}
