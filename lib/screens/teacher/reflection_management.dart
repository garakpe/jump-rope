// lib/screens/teacher/reflection_management.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_model.dart';
import '../../models/firebase_models.dart';
import '../../providers/reflection_provider.dart';
import '../../providers/student_provider.dart' as studentprovider;
import '../student/reflection_detail_screen.dart';
import 'package:intl/intl.dart';

class ReflectionManagement extends StatefulWidget {
  final int selectedClassId;

  const ReflectionManagement({
    Key? key,
    required this.selectedClassId,
  }) : super(key: key);

  @override
  _ReflectionManagementState createState() => _ReflectionManagementState();
}

class _ReflectionManagementState extends State<ReflectionManagement>
    with SingleTickerProviderStateMixin {
  ReflectionSubmission? _selectedSubmission;
  String _statusMessage = '';
  bool _isLoading = false;
  int _selectedReflectionType = 1; // 초기 성찰(1), 중기 성찰(2), 최종 성찰(3)
  Map<int, DateTime?> _deadlines = {}; // 성찰 유형별 마감일
  late TabController _tabController;
  final Map<int, Map<String, int>> _statsCache = {}; // 성찰 유형별 통계 캐시
  final ScrollController _scrollController = ScrollController(); // 스크롤 컨트롤러 추가

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    // 화면이 처음 로드될 때 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedClassId > 0) {
        // 선택된 학급에 대한 성찰 데이터 로드
        final reflectionProvider =
            Provider.of<ReflectionProvider>(context, listen: false);
        reflectionProvider.selectClassAndReflectionType(
            widget.selectedClassId.toString(), 1); // 초기 성찰부터 시작

        // 마감일 정보 로드
        _loadDeadlines();

        // 첫 번째 탭의 통계 로드
        _loadReflectionStats(1);

        print('성찰 관리 - 선택된 학급: ${widget.selectedClassId}');
      }
    });
  }

  @override
  void didUpdateWidget(ReflectionManagement oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 학급이 변경되었을 때 데이터 새로고침
    if (oldWidget.selectedClassId != widget.selectedClassId &&
        widget.selectedClassId > 0) {
      print('ReflectionManagement - 학급 변경 감지: ${widget.selectedClassId}');

      // 선택된 학급에 대한 성찰 데이터 로드
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      reflectionProvider.selectClassAndReflectionType(
          widget.selectedClassId.toString(), _selectedReflectionType);

      // 마감일 정보 다시 로드
      _loadDeadlines();

      // 현재 선택된 탭의 통계 로드
      _loadReflectionStats(_selectedReflectionType);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose(); // 스크롤 컨트롤러 해제
    super.dispose();
  }

  // 탭 변경 처리
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    final newReflectionType = _tabController.index + 1; // 탭 인덱스 + 1 = 성찰 유형

    if (_selectedReflectionType != newReflectionType) {
      setState(() {
        _selectedReflectionType = newReflectionType;
      });

      // 리스트 업데이트를 위해 ReflectionProvider 업데이트
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);
      reflectionProvider.selectClassAndReflectionType(
          widget.selectedClassId.toString(), newReflectionType);

      // 해당 탭의 통계 로드
      _loadReflectionStats(newReflectionType);
    }
  }

  // 마감일 정보 로드
  Future<void> _loadDeadlines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // deadlines getter 사용
      final deadlines = reflectionProvider.deadlines;

      setState(() {
        _deadlines = deadlines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '마감일 정보를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 성찰 유형별 통계 로드
  Future<void> _loadReflectionStats(int reflectionType) async {
    if (_statsCache.containsKey(reflectionType)) {
      // 이미 캐시된 통계가 있으면 재사용
      return;
    }

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      final stats = await reflectionProvider.getSubmissionStatsByClass(
          widget.selectedClassId.toString(), reflectionType);

      // 캐시에 저장
      setState(() {
        _statsCache[reflectionType] = stats;
      });
    } catch (e) {
      print('통계 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSubmission != null) {
      return _buildSubmissionDetail();
    }

    return Column(
      children: [
        // 헤더 영역
        _buildHeaderCard(),
        const SizedBox(height: 16),

        // 상태 메시지
        if (_statusMessage.isNotEmpty) _buildStatusMessage(),

        // 탭 내용 - Expanded와 SingleChildScrollView로 감싸서 스크롤 가능하도록 수정
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: _buildReflectionGrid(),
          ),
        ),
      ],
    );
  }

  // 헤더 카드
  Widget _buildHeaderCard() {
    final reflectionProvider = Provider.of<ReflectionProvider>(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 제목 및 요약 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.orange.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 제목 부분
                Row(
                  children: [
                    const Icon(Icons.book, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      '성찰 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // 성찰 보고서 활성화 설정 버튼 추가
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('성찰 활성화 설정'),
                      onPressed: () => _showActivationSettingsDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.amber.shade800,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildReflectionStatsWidget(),
              ],
            ),
          ),

          // 탭바
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.amber.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.amber.shade500,
              indicatorWeight: 3,
              tabs: [
                _buildTabItem(Icons.flag, '초기 성찰', 1),
                _buildTabItem(Icons.timeline, '중기 성찰', 2),
                _buildTabItem(Icons.emoji_events, '최종 성찰', 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 성찰 활성화 설정 다이얼로그 표시
  void _showActivationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 600, // 다이얼로그 최대 너비 설정
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 다이얼로그 헤더
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '성찰 보고서 활성화 설정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 설정 내용 표시
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildReflectionActivationSettings(),
                ),

                // 하단 버튼
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('설정 완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 탭 아이템 위젯
  Widget _buildTabItem(IconData icon, String label, int reflectionType) {
    // 활성화 여부 확인
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final isActive = reflectionProvider.isReflectionTypeActive(reflectionType);

    // 통계 데이터 가져오기
    final stats = _statsCache[reflectionType];
    final submittedCount = stats?['submitted'] ?? 0;

    return Tab(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
          if (stats != null && submittedCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.amber.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$submittedCount명',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color:
                      isActive ? Colors.amber.shade800 : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 성찰 통계 위젯 - 개선된 버전
  Widget _buildReflectionStatsWidget() {
    // 현재 선택된 성찰 유형의 통계
    final stats = _statsCache[_selectedReflectionType];

    if (stats == null || stats.isEmpty) {
      return Container(); // 통계가 없으면 빈 컨테이너 반환
    }

    final total = stats['total'] ?? 0;
    final submitted = stats['submitted'] ?? 0;
    final accepted = stats['accepted'] ?? 0;
    final rejected = stats['rejected'] ?? 0;

    return Row(
      children: [
        _buildStatBadge(Icons.people, '$total명', Colors.white),
        const SizedBox(width: 8),
        _buildStatBadge(
            Icons.check_circle, '$submitted제출', Colors.blue.shade100),
        const SizedBox(width: 8),
        _buildStatBadge(Icons.cancel, '$rejected반려', Colors.orange.shade100),
        const SizedBox(width: 8),
        _buildStatBadge(Icons.verified, '$accepted승인', Colors.green.shade100),
      ],
    );
  }

  // 통계 배지 위젯
  Widget _buildStatBadge(IconData icon, String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 성찰 보고서 활성화 설정 영역 (다이얼로그용으로 수정)
  Widget _buildReflectionActivationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '학생들이 접근할 수 있는 성찰 보고서를 선택하세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 16),

        // 성찰 유형 활성화 토글
        _buildReflectionTypeToggleList(),

        // 안내 메시지
        const SizedBox(height: 8),
        Text(
          '* 비활성화된 성찰은 학생들에게 표시되지 않으며 접근할 수 없습니다.',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // 성찰 유형 토글 리스트
  Widget _buildReflectionTypeToggleList() {
    // 개선된 토글 위젯 3개
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildReflectionTypeToggle(1, '초기 성찰', '시작 단계의 학습 목표 설정', Icons.flag),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _buildReflectionTypeToggle(
              2, '중기 성찰', '학습 과정에서의 도전과 극복', Icons.timeline),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _buildReflectionTypeToggle(
              3, '최종 성찰', '전체 학습 과정 평가와 성과', Icons.emoji_events),
        ],
      ),
    );
  }

  // 성찰 유형 활성화/비활성화 토글 위젯 추가
  Widget _buildReflectionTypeToggle(
      int type, String label, String description, IconData icon) {
    final reflectionProvider = Provider.of<ReflectionProvider>(context);
    final isActive = reflectionProvider.isReflectionTypeActive(type);

    // 마감일 정보
    final deadline = _deadlines[type];
    final isDeadlinePassed =
        deadline != null && deadline.isBefore(DateTime.now());
    final stats = _statsCache[type];
    final submittedCount = stats?['submitted'] ?? 0;
    final totalCount = stats?['total'] ?? 0;

    return InkWell(
      onTap: () {}, // 전체 영역 터치 허용 (UI 피드백용)
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // 아이콘 영역
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? Colors.amber.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.amber.shade700 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 16),

            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.amber.shade800
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (submittedCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.blue.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$submittedCount/$totalCount명',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (deadline != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            isDeadlinePassed
                                ? Icons.lock_clock
                                : Icons.schedule,
                            size: 14,
                            color: isDeadlinePassed
                                ? Colors.red.shade400
                                : Colors.blue.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDeadlinePassed
                                ? '마감됨: ${DateFormat('MM/dd HH:mm').format(deadline)}'
                                : '마감일: ${DateFormat('MM/dd HH:mm').format(deadline)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDeadlinePassed
                                  ? Colors.red.shade400
                                  : Colors.blue.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 스위치 토글
            SizedBox(
              width: 60,
              child: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isActive,
                  activeColor: Colors.amber.shade600,
                  activeTrackColor: Colors.amber.shade200,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade300,
                  onChanged: _isLoading
                      ? null
                      : (newValue) async {
                          setState(() {
                            _isLoading = true;
                            _statusMessage = '성찰 유형 상태 변경 중...';
                          });

                          try {
                            await reflectionProvider.toggleReflectionType(
                                type, newValue);

                            setState(() {
                              _isLoading = false;
                              _statusMessage = newValue
                                  ? '$label 보고서가 활성화되었습니다. 학생들이 이제 접근할 수 있습니다.'
                                  : '$label 보고서가 비활성화되었습니다. 학생들이 더 이상 접근할 수 없습니다.';
                            });

                            // 다이얼로그 닫기
                            Navigator.of(context).pop();
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              _statusMessage = '상태 변경 중 오류가 발생했습니다: $e';
                            });
                          }
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상태 메시지 위젯
  Widget _buildStatusMessage() {
    final isSuccess = _statusMessage.contains('성공') ||
        _statusMessage.contains('활성화') ||
        _statusMessage.contains('비활성화');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isSuccess ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.info_outline,
            color: isSuccess ? Colors.green.shade600 : Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color:
                    isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: isSuccess ? Colors.green.shade600 : Colors.orange.shade600,
            onPressed: () {
              setState(() {
                _statusMessage = '';
              });
            },
          ),
        ],
      ),
    );
  }

  // 성찰 그리드 - 질문 미리보기 부분 삭제
  Widget _buildReflectionGrid() {
    // 현재 선택된 성찰 유형에 대한 정보 가져오기
    final reflectionCard = reflectionCards.firstWhere(
      (card) => card.id == _selectedReflectionType,
      orElse: () => reflectionCards.first,
    );

    final reflectionTitle = reflectionCard.title;
    final DateTime? deadline = _deadlines[_selectedReflectionType];
    final bool isDeadlinePassed =
        deadline != null && deadline.isBefore(DateTime.now());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 카드 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade200, Colors.amber.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getReflectionIcon(_selectedReflectionType),
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          reflectionTitle,
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    // 마감일 영역 (더 눈에 띄는 디자인)
                    if (deadline != null)
                      _buildDeadlineBadge(deadline, isDeadlinePassed),
                  ],
                ),

                // 질문 미리보기 부분 삭제됨
              ],
            ),
          ),

          // 마감/재개 버튼
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDeadlinePassed ? Icons.lock : Icons.access_time,
                      size: 20,
                      color: isDeadlinePassed
                          ? Colors.grey.shade700
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDeadlinePassed ? '현재 접수가 마감되었습니다' : '접수 진행 중',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDeadlinePassed
                            ? Colors.grey.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(
                    isDeadlinePassed ? Icons.lock_open : Icons.lock_clock,
                    size: 16,
                  ),
                  label: Text(
                    isDeadlinePassed ? '접수 재개' : '접수 마감',
                    style: const TextStyle(fontSize: 14),
                  ),
                  onPressed: isDeadlinePassed
                      ? () => _reopenDeadline(_selectedReflectionType)
                      : () => _setDeadline(_selectedReflectionType),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeadlinePassed
                        ? Colors.blue.shade500
                        : Colors.red.shade500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 학생 목록 - 스크롤 가능하도록 영역 크기 조정
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5, // 화면 높이의 50%로 제한
            child: SingleChildScrollView(
              child: _buildStudentList(_selectedReflectionType),
            ),
          ),

          // 엑셀 다운로드 버튼
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('엑셀로 내보내기'),
              onPressed: () => generateExcelDownload(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade500,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 마감일 배지 위젯
  Widget _buildDeadlineBadge(DateTime deadline, bool isDeadlinePassed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDeadlinePassed ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDeadlinePassed ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDeadlinePassed ? Icons.event_busy : Icons.event_available,
            size: 16,
            color:
                isDeadlinePassed ? Colors.red.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            isDeadlinePassed
                ? '마감: ${DateFormat('MM/dd HH:mm').format(deadline)}'
                : '마감일: ${DateFormat('MM/dd HH:mm').format(deadline)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color:
                  isDeadlinePassed ? Colors.red.shade700 : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // 성찰 유형별 아이콘 가져오기
  IconData _getReflectionIcon(int reflectionType) {
    switch (reflectionType) {
      case 1:
        return Icons.flag;
      case 2:
        return Icons.timeline;
      case 3:
        return Icons.emoji_events;
      default:
        return Icons.book;
    }
  }

  // 접수마감 설정 함수
  void _setDeadline(int reflectionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('성찰 보고서 접수마감'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getReflectionTypeName(reflectionType)} 보고서 접수를 마감하시겠습니까?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '마감 시 학생들은 더 이상 ${_getReflectionTypeName(reflectionType)} 보고서를 제출할 수 없습니다.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                '참고: 마감 처리된 성찰은 관리자가 다시 열 수 있습니다.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.timer_off, size: 16),
            label: const Text('마감하기'),
            onPressed: () {
              Navigator.pop(context);
              _processDeadline(reflectionType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // 성찰 유형 이름 가져오기
  String _getReflectionTypeName(int reflectionType) {
    switch (reflectionType) {
      case 1:
        return '초기 성찰';
      case 2:
        return '중기 성찰';
      case 3:
        return '최종 성찰';
      default:
        return '성찰';
    }
  }

  // 마감 처리 함수
  Future<void> _processDeadline(int reflectionType) async {
    setState(() {
      _isLoading = true;
      _statusMessage =
          '${_getReflectionTypeName(reflectionType)} 보고서 마감 처리 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 현재 시간으로 마감일 설정
      await reflectionProvider.setDeadline(reflectionType, DateTime.now());

      // 마감일 정보 다시 로드
      await _loadDeadlines();

      setState(() {
        _statusMessage =
            '${_getReflectionTypeName(reflectionType)} 보고서가 마감되었습니다.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '마감 처리 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 마감 재오픈 함수
  void _reopenDeadline(int reflectionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_open, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('성찰 보고서 마감 해제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getReflectionTypeName(reflectionType)} 보고서 마감을 해제하시겠습니까?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '마감 해제 시 학생들은 다시 ${_getReflectionTypeName(reflectionType)} 보고서를 제출할 수 있습니다.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text('마감 해제'),
            onPressed: () {
              Navigator.pop(context);
              processReopenDeadline(reflectionType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // 학생 목록 구현 (grade, classNum으로 필터링하도록 수정됨)
  Widget _buildStudentList(int reflectionType) {
    final studentProvider =
        Provider.of<studentprovider.StudentProvider>(context);
    final reflectionProvider = Provider.of<ReflectionProvider>(context);

    final students = studentProvider.students;
    final reflectionId = reflectionType; // 성찰 유형 ID 직접 사용

    // 학생 로딩 중인 경우 로딩 표시
    if (studentProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 학생이 없는 경우 메시지 표시
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined,
                size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              '이 학급에 학생이 없습니다',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('학생 일괄 등록하기'),
              onPressed: () {
                // 학생 등록 화면으로 이동하는 로직
                Navigator.pushNamed(context, '/student_upload');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 모둠별로 학생 그룹화
    final Map<int, List<FirebaseStudentModel>> groupedStudents = {};
    for (var student in students) {
      if (!groupedStudents.containsKey(student.group)) {
        groupedStudents[student.group] = [];
      }
      groupedStudents[student.group]!.add(student);
    }

    // 모둠 번호 정렬
    final sortedGroups = groupedStudents.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: sortedGroups.map((groupNum) {
          final groupStudents = groupedStudents[groupNum]!;

          // 각 모둠 내에서 학생 이름 기준으로 정렬
          groupStudents.sort((a, b) => a.name.compareTo(b.name));

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 모둠 헤더
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$groupNum',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '모둠 ($groupNum) - ${groupStudents.length}명',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // 모둠원 목록
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupStudents.length,
                  itemBuilder: (context, index) {
                    final student = groupStudents[index];

                    return FutureBuilder<ReflectionStatus>(
                      future: reflectionProvider.getSubmissionStatus(
                          student.studentId, reflectionId),
                      builder: (context, snapshot) {
                        // 로딩 중이거나 오류 시 기본값으로 미제출 상태 표시
                        ReflectionStatus status =
                            snapshot.data ?? ReflectionStatus.notSubmitted;

                        return buildStudentListItem(
                            student, status, reflectionId);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 학생 목록 아이템은 기존 코드 활용
  Widget buildStudentListItem(
      FirebaseStudentModel student, ReflectionStatus status, int reflectionId) {
    // 상태에 따른 디자인 설정
    final (color, statusText, statusIcon) = getStatusDesign(status);

    return InkWell(
      onTap: () {
        // 학생 성찰 보고서 상세 보기 (제출된 경우에만)
        if (status != ReflectionStatus.notSubmitted) {
          _viewStudentReflection(student, reflectionId);
        } else {
          // 미제출 상태 메시지
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${student.name} 학생은 아직 성찰 보고서를 제출하지 않았습니다.'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            // 학생 정보 부분
            Expanded(
              child: Row(
                children: [
                  // 상태 아이콘
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      size: 18,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 학생 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '학번: ${student.studentId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (student.classNum.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '반: ${student.classNum}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 상태 표시 및 액션 버튼
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (status != ReflectionStatus.notSubmitted)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == ReflectionStatus.submitted)
                          buildQuickActionButton(
                            Icons.check_circle,
                            '승인',
                            Colors.green,
                            () => approveReflection(student, reflectionId),
                          ),
                        if (status == ReflectionStatus.submitted)
                          const SizedBox(width: 8),
                        if (status == ReflectionStatus.submitted)
                          buildQuickActionButton(
                            Icons.cancel,
                            '반려',
                            Colors.orange,
                            () => showRejectDialog(student, reflectionId),
                          ),
                        if (status != ReflectionStatus.submitted)
                          buildQuickActionButton(
                            Icons.visibility,
                            '보기',
                            Colors.blue,
                            () => _viewStudentReflection(student, reflectionId),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 빠른 액션 버튼 위젯, 상태 디자인과 나머지 함수들은 기존 코드 활용
  Widget buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상태에 따른 디자인 변수 반환 함수
  (Color, String, IconData) getStatusDesign(ReflectionStatus status) {
    switch (status) {
      case ReflectionStatus.notSubmitted:
        return (Colors.grey, '미제출', Icons.cancel_outlined);
      case ReflectionStatus.submitted:
        return (Colors.blue, '제출완료', Icons.check_circle_outline);
      case ReflectionStatus.rejected:
        return (Colors.orange, '반려됨', Icons.warning_amber_outlined);
      case ReflectionStatus.accepted:
        return (Colors.green, '승인됨', Icons.verified_outlined);
    }
  }

// 마감 해제 처리 함수
  Future<void> processReopenDeadline(int reflectionType) async {
    setState(() {
      _isLoading = true;
      _statusMessage =
          '${_getReflectionTypeName(reflectionType)} 보고서 마감 해제 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 마감일을 한 달 후로 설정 (사실상 마감 해제)
      await reflectionProvider.setDeadline(
          reflectionType, DateTime.now().add(const Duration(days: 30)));

      // 마감일 정보 다시 로드
      await _loadDeadlines();

      setState(() {
        _statusMessage =
            '${_getReflectionTypeName(reflectionType)} 보고서 마감이 해제되었습니다.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '마감 해제 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 엑셀 다운로드 생성
  Future<void> generateExcelDownload() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '엑셀 파일 생성 중...';
    });

    try {
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      final url = await reflectionProvider.generateExcelDownloadUrl();

      setState(() {
        _isLoading = false;
        _statusMessage = '엑셀 파일이 생성되었습니다. 다운로드 URL: $url';
      });

      // 다운로드 성공 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('엑셀 파일 생성 완료'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '성찰 보고서 데이터가 엑셀 파일로 생성되었습니다.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '다운로드 URL:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      url,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('URL 복사'),
              onPressed: () {
                // URL 복사 기능 (실제 구현 시)
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '엑셀 파일 생성 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 성찰 보고서 승인 처리
  Future<void> approveReflection(
      FirebaseStudentModel student, int reflectionId) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = '성찰 보고서 승인 중...';
      });

      // 보고서 정보 가져오기
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      final submission = await reflectionProvider.getSubmission(
          student.studentId, reflectionId);

      if (submission == null || submission.id.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '승인할 보고서 정보를 찾을 수 없습니다.';
        });
        return;
      }

      // 승인 처리
      await reflectionProvider.approveReflection(submission.id);

      setState(() {
        _isLoading = false;
        _statusMessage = '${student.name}의 성찰 보고서가 승인되었습니다.';
      });

      // 목록 새로고침
      reflectionProvider.selectClassAndReflectionType(
          widget.selectedClassId.toString(), reflectionId);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '승인 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 반려 다이얼로그 표시
  void showRejectDialog(FirebaseStudentModel student, int reflectionId) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('성찰 보고서 반려'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student.name}의 성찰 보고서를 반려하시겠습니까?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('반려 사유:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '학생에게 표시될 반려 사유를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text('반려하기'),
            onPressed: () {
              // 반려 사유 검증
              if (reasonController.text.trim().length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('반려 사유는 5자 이상 입력해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    // 반려 사유가 입력되면 처리
    if (result != null && result.isNotEmpty) {
      rejectReflection(student, reflectionId, result);
    }
  }

  // 성찰 보고서 반려 처리
  Future<void> rejectReflection(
      FirebaseStudentModel student, int reflectionId, String reason) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = '성찰 보고서 반려 중...';
      });

      // 보고서 정보 가져오기
      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      final submission = await reflectionProvider.getSubmission(
          student.studentId, reflectionId);

      if (submission == null || submission.id.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '반려할 보고서 정보를 찾을 수 없습니다.';
        });
        return;
      }

      // 반려 처리
      await reflectionProvider.rejectReflection(submission.id, reason);

      setState(() {
        _isLoading = false;
        _statusMessage = '${student.name}의 성찰 보고서가 반려되었습니다.';
      });

      // 목록 새로고침
      reflectionProvider.selectClassAndReflectionType(
          widget.selectedClassId.toString(), _selectedReflectionType);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '반려 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 학생 성찰 보고서 보기 메서드
  Future<void> _viewStudentReflection(
      FirebaseStudentModel student, int reflectionId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 학생 성찰 데이터 가져오기 (로컬이나 서버에서)
      final submission = await reflectionProvider.getSubmission(
          student.studentId, reflectionId);

      setState(() {
        _isLoading = false;
      });

      if (submission != null) {
        // ReflectionDetailScreen으로 이동하여 성찰 보고서 보기
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReflectionDetailScreen(
              reflectionId: reflectionId,
              submission: submission,
              isTeacher: true, // 교사 모드로 설정
            ),
          ),
        );

        // 결과가 true이면 상태 업데이트
        if (result == true) {
          reflectionProvider.selectClassAndReflectionType(
              widget.selectedClassId.toString(), _selectedReflectionType);
          setState(() {
            _statusMessage = '${student.name}의 성찰 보고서를 확인했습니다.';
          });
        }
      } else {
        setState(() {
          _statusMessage = '${student.name}의 성찰 보고서를 불러올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '오류 발생: $e';
      });
    }
  }

  Widget _buildSubmissionDetail() {
    if (_selectedSubmission == null) return const SizedBox.shrink();

    final reflectionId = _selectedSubmission!.reflectionId;
    final reflection = reflectionCards.firstWhere(
      (r) => r.id == reflectionId,
      orElse: () => reflectionCards.first,
    );

    return Column(
      children: [
        // 헤더 영역
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getReflectionIcon(reflectionId),
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedSubmission!.studentName}의 ${reflection.title}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('돌아가기'),
                  onPressed: () {
                    setState(() {
                      _selectedSubmission = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 질문 및 답변 목록 - 스크롤 추가
        Expanded(
          child: SingleChildScrollView(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reflection.questions.length,
              itemBuilder: (context, index) {
                final question = reflection.questions[index];
                final answer = _selectedSubmission!.answers[question] ?? '';

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 질문 헤더
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          '${index + 1}. $question',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),

                      // 답변 영역
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: TextEditingController(text: answer),
                          maxLines: 4,
                          readOnly: true, // 읽기 전용
                          decoration: InputDecoration(
                            hintText: '학생 답변...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.amber.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.amber.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.amber.shade400),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // 승인/반려 버튼 영역
        if (_selectedSubmission!.status == ReflectionStatus.submitted)
          Card(
            elevation: 1,
            margin: const EdgeInsets.only(top: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('승인하기'),
                      onPressed: () {
                        // 선택된 보고서 승인 처리
                        _approveSelectedSubmission();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('반려하기'),
                      onPressed: () {
                        // 반려 다이얼로그 표시
                        _showRejectDialogForSelected();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 선택된 보고서 승인 처리
  Future<void> _approveSelectedSubmission() async {
    if (_selectedSubmission == null || _selectedSubmission!.id.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = '성찰 보고서 승인 중...';
      });

      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 승인 처리
      await reflectionProvider.approveReflection(_selectedSubmission!.id);

      setState(() {
        _isLoading = false;
        _statusMessage =
            '${_selectedSubmission!.studentName}의 성찰 보고서가 승인되었습니다.';
        _selectedSubmission = null; // 상세 화면 닫기
      });

      // 목록 새로고침
      reflectionProvider.selectClassAndReflectionType(
          widget.selectedClassId.toString(), _selectedReflectionType);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '승인 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 선택된 보고서 반려 다이얼로그
  void _showRejectDialogForSelected() async {
    if (_selectedSubmission == null) return;

    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('성찰 보고서 반려'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedSubmission!.studentName}의 성찰 보고서를 반려하시겠습니까?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('반려 사유:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '학생에게 표시될 반려 사유를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text('반려하기'),
            onPressed: () {
              // 반려 사유 검증
              if (reasonController.text.trim().length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('반려 사유는 5자 이상 입력해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    // 반려 사유가 입력되면 처리
    if (result != null && result.isNotEmpty) {
      _rejectSelectedSubmission(result);
    }
  }

  // 선택된 보고서 반려 처리
  Future<void> _rejectSelectedSubmission(String reason) async {
    if (_selectedSubmission == null || _selectedSubmission!.id.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = '성찰 보고서 반려 중...';
      });

      final reflectionProvider =
          Provider.of<ReflectionProvider>(context, listen: false);

      // 반려 처리
      await reflectionProvider.rejectReflection(
          _selectedSubmission!.id, reason);

      setState(() {
        _isLoading = false;
        _statusMessage =
            '${_selectedSubmission!.studentName}의 성찰 보고서가 반려되었습니다.';
        _selectedSubmission = null; // 상세 화면 닫기
      });

      // 목록 새로고침
      reflectionProvider.selectClassAndReflectionType(
          widget.selectedClassId.toString(), _selectedReflectionType);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '반려 중 오류가 발생했습니다: $e';
      });
    }
  }
}
