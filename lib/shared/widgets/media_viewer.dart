import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/utils/url_utils.dart';
import 'robust_image_widget.dart';
import 'built_in_attachment_viewer.dart';
import '../../core/constants/api_constants.dart';

class MediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> attachments;
  final int initialIndex;
  final String? title;

  const MediaViewer({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
    this.title,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAttachment = widget.attachments[_currentIndex];
    final fileName = currentAttachment['fileName'] ??
        currentAttachment['filename'] ??
        'Unknown File';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? fileName,
              style: const TextStyle(fontSize: 16),
            ),
            if (widget.attachments.length > 1)
              Text(
                '${_currentIndex + 1} of ${widget.attachments.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showMoreOptions(context, currentAttachment),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.attachments.length,
              itemBuilder: (context, index) {
                return _buildMediaContent(widget.attachments[index]);
              },
            ),
          ),

          // Bottom navigation for multiple attachments
          if (widget.attachments.length > 1) _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildMediaContent(Map<String, dynamic> attachment) {
    final mimeType = attachment['mimeType'] ??
        attachment['fileType'] ??
        'application/octet-stream';

    if (mimeType.startsWith('image/')) {
      return _buildImageViewer(attachment);
    } else if (mimeType.startsWith('video/')) {
      return _buildVideoViewer(attachment);
    } else if (mimeType.startsWith('audio/')) {
      return _buildAudioViewer(attachment);
    } else {
      return _buildFileViewer(attachment);
    }
  }

  Widget _buildImageViewer(Map<String, dynamic> attachment) {
    final url = _getAttachmentUrl(attachment);

    return Center(
      child: InteractiveViewer(
        child: RobustImageWidget(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          errorWidget: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViewer(Map<String, dynamic> attachment) {
    final url = _getAttachmentUrl(attachment);

    return VideoPlayerWidget(
      videoUrl: url,
      fileName: attachment['fileName'] ?? attachment['filename'] ?? 'Video',
    );
  }

  Widget _buildAudioViewer(Map<String, dynamic> attachment) {
    final url = _getAttachmentUrl(attachment);

    return AudioPlayerWidget(
      audioUrl: url,
      fileName: attachment['fileName'] ?? attachment['filename'] ?? 'Audio',
    );
  }

  Widget _buildFileViewer(Map<String, dynamic> attachment) {
    return Center(
      child: BuiltInAttachmentViewer(attachment: attachment),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: _currentIndex > 0 ? _previousAttachment : null,
            icon: Icon(
              Icons.arrow_back_ios,
              color: _currentIndex > 0 ? Colors.white : Colors.grey,
            ),
          ),
          Text(
            '${_currentIndex + 1} / ${widget.attachments.length}',
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            onPressed: _currentIndex < widget.attachments.length - 1
                ? _nextAttachment
                : null,
            icon: Icon(
              Icons.arrow_forward_ios,
              color: _currentIndex < widget.attachments.length - 1
                  ? Colors.white
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _previousAttachment() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextAttachment() {
    if (_currentIndex < widget.attachments.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showMoreOptions(BuildContext context, Map<String, dynamic> attachment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                _downloadAttachment(attachment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareAttachment(attachment);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getAttachmentUrl(Map<String, dynamic> attachment) {
    final fileUrl = attachment['url'] ?? attachment['fileUrl'] ?? '';
    String downloadUrl = fileUrl;

    if (downloadUrl.isNotEmpty) {
      if (downloadUrl.startsWith('/')) {
        // Use the current backend base URL without /api suffix
        final backendUrl = ApiConstants.baseUrl.replaceAll('/api', '');
        downloadUrl = '$backendUrl$downloadUrl';
      } else if (!downloadUrl.startsWith('http')) {
        downloadUrl = '${ApiConstants.baseUrl}/uploads/serve/$downloadUrl';
      }
      downloadUrl = UrlUtils.rewriteAttachmentUrl(downloadUrl);
    }

    return downloadUrl;
  }

  void _downloadAttachment(Map<String, dynamic> attachment) {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality coming soon')),
    );
  }

  void _shareAttachment(Map<String, dynamic> attachment) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }
}

// Video Player Widget
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String fileName;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.fileName,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_hasError || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_controller!),
            VideoPlayerControls(controller: _controller!),
          ],
        ),
      ),
    );
  }
}

// Custom Video Player Controls
class VideoPlayerControls extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoPlayerControls({super.key, required this.controller});

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black26,
          child: Center(
            child: IconButton(
              iconSize: 64,
              onPressed: () {
                setState(() {
                  widget.controller.value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                });
              },
              icon: Icon(
                widget.controller.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Audio Player Widget
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String fileName;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.fileName,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading =
              state == PlayerState.playing && _position == Duration.zero;
        });
      }
    });
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.audiotrack,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              widget.fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  onPressed: _playPause,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Slider(
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) async {
                    final position = Duration(seconds: value.toInt());
                    await _audioPlayer.seek(position);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
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
}
