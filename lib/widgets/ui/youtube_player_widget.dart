// lib/widgets/ui/youtube_player_widget.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerWidget extends StatefulWidget {
  final String? videoId;
  final double height;
  final double width;
  final BorderRadius? borderRadius;
  final bool autoPlay;
  final Widget Function()? placeholderBuilder;
  final bool isShorts; // 추가: 쇼츠 여부를 직접 받도록 수정

  const YoutubePlayerWidget({
    Key? key,
    required this.videoId,
    this.height = 200,
    this.width = double.infinity,
    this.borderRadius,
    this.autoPlay = false,
    this.placeholderBuilder,
    this.isShorts = false, // 기본값은 일반 비디오
  }) : super(key: key);

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _hasError = false;
  String? _extractedVideoId;

  @override
  void initState() {
    super.initState();
    _extractedVideoId = _extractYoutubeVideoId(widget.videoId);
    _initializePlayer();
  }

  // URL에서 YouTube 비디오 ID 추출 메서드
  String? _extractYoutubeVideoId(String? url) {
    if (url == null || url.isEmpty) return null;

    // 이미 ID만 있는 경우 (11자리 영숫자)
    RegExp regExpId = RegExp(
      r"^[a-zA-Z0-9_-]{11}$",
      caseSensitive: false,
      multiLine: false,
    );

    if (regExpId.hasMatch(url)) {
      // 이미 비디오 ID 형식이면 그대로 반환
      return url;
    }

    // YouTube 표준 URL (watch?v=VIDEO_ID)
    RegExp regExpStandard = RegExp(
      r"(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/|youtube\.com\/e\/|youtube\/watch\?v=|youtube\.com\/watch\?feature=player_embedded&v=)([^&?\n]+)",
      caseSensitive: false,
      multiLine: false,
    );

    // YouTube Shorts URL (shorts/VIDEO_ID)
    RegExp regExpShorts = RegExp(
      r"youtube\.com\/shorts\/([^&?\n]+)",
      caseSensitive: false,
      multiLine: false,
    );

    if (regExpStandard.hasMatch(url)) {
      // 표준 URL에서 ID 추출
      return regExpStandard.firstMatch(url)?.group(1);
    } else if (regExpShorts.hasMatch(url)) {
      // Shorts URL에서 ID 추출
      return regExpShorts.firstMatch(url)?.group(1);
    }

    // 일치하는 패턴이 없는 경우
    print('비디오 ID를 추출할 수 없습니다: $url');
    return null;
  }

  void _initializePlayer() {
    if (_extractedVideoId == null) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    try {
      print('초기화 중인 비디오 ID: $_extractedVideoId (쇼츠: ${widget.isShorts})');

      // 컨트롤러 초기화 - autoPlay 제거 (최신 API 변경 반영)
      _controller = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showControls: true,
          mute: false,
          showFullscreenButton: true,
          loop: false,
          strictRelatedVideos: true,
        ),
      );

      // 비디오 로드
      _controller.loadVideoById(videoId: _extractedVideoId!);

      // 자동 재생 처리 - isReady 체크 없이 직접 호출
      if (widget.autoPlay) {
        // 약간의 지연 후 재생 시작 (준비 상태 체크 없이)
        Future.delayed(const Duration(milliseconds: 1000), () {
          try {
            _controller.playVideo();
          } catch (e) {
            print('자동 재생 오류: $e');
          }
        });
      }

      setState(() {
        _isPlayerReady = true;
      });
    } catch (e) {
      print('유튜브 플레이어 초기화 오류: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void didUpdateWidget(YoutubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      setState(() {
        _isPlayerReady = false;
        _hasError = false;
      });

      _extractedVideoId = _extractYoutubeVideoId(widget.videoId);

      if (_extractedVideoId != null) {
        _controller.loadVideoById(videoId: _extractedVideoId!);

        // 비디오 변경 시에도 자동 재생 처리
        if (widget.autoPlay) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            try {
              _controller.playVideo();
            } catch (e) {
              print('비디오 변경 후 자동 재생 오류: $e');
            }
          });
        }

        setState(() {
          _isPlayerReady = true;
        });
      } else {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _extractedVideoId == null) {
      return _buildPlaceholder();
    }

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isPlayerReady
          ? YoutubePlayerScaffold(
              controller: _controller,
              // widget.isShorts 플래그를 사용하여 비율 결정
              aspectRatio: widget.isShorts ? 9 / 16 : 16 / 9,
              builder: (context, player) {
                return Column(
                  children: [
                    // 쇼츠인 경우 플레이어를 중앙 정렬하고 높이 제한
                    if (widget.isShorts)
                      SizedBox(
                        height: widget.height,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 9 / 16, // 쇼츠 비율
                            child: player,
                          ),
                        ),
                      )
                    else
                      Expanded(child: player),
                  ],
                );
              },
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholderBuilder != null) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        ),
        child: widget.placeholderBuilder!(),
      );
    }

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            '비디오를 불러올 수 없습니다',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
