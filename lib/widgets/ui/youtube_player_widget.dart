// lib/widgets/ui/youtube_player_widget.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubePlayerWidget extends StatefulWidget {
  final String? videoId;
  final double height;
  final double width;
  final BorderRadius? borderRadius;
  final bool autoPlay;
  final Widget Function()? placeholderBuilder;

  const YoutubePlayerWidget({
    Key? key,
    required this.videoId,
    this.height = 200,
    this.width = double.infinity,
    this.borderRadius,
    this.autoPlay = false,
    this.placeholderBuilder,
  }) : super(key: key);

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  YoutubePlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    if (widget.videoId != null && widget.videoId!.isNotEmpty) {
      try {
        _controller = YoutubePlayerController(
          initialVideoId: widget.videoId!,
          flags: YoutubePlayerFlags(
            autoPlay: widget.autoPlay,
            mute: false,
            disableDragSeek: false,
            loop: false,
            enableCaption: true,
          ),
        );
      } catch (e) {
        print('유튜브 플레이어 초기화 오류: $e');
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(YoutubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller?.dispose();
      _hasError = false;
      _initPlayer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || widget.videoId == null || widget.videoId!.isEmpty) {
      // 에러가 있거나 videoId가 없는 경우
      return _buildPlaceholder();
    }

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        child: _controller != null
            ? YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
                onReady: () {
                  // 플레이어가 준비되었을 때 호출
                  print('유튜브 플레이어 준비됨');
                },
                onEnded: (data) {
                  // 비디오가 종료되었을 때 호출
                  print('비디오 종료됨');
                },
              )
            : _buildPlaceholder(),
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
