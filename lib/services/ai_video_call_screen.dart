import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart' if (dart.library.html) 'package:aidx/services/web_webrtc_stub.dart';
import 'package:aidx/services/ai_webrtc_service.dart';

class AiVideoCallScreen extends StatefulWidget {
  const AiVideoCallScreen({super.key});

  @override
  State<AiVideoCallScreen> createState() => _AiVideoCallScreenState();
}

class _AiVideoCallScreenState extends State<AiVideoCallScreen> {
  final AiWebRtcService _rtc = AiWebRtcService();
  bool _inCall = false;
  bool _micOn = true;
  bool _camOn = true;

  StreamSubscription<String>? _analysisSub;
  final List<String> _analysisLines = [];

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _rtc.initialize();
    await _rtc.startLocalMedia(video: true, audio: true);
    await _rtc.initializePeerConnection();
    _analysisSub = _rtc.analysisTextStream.listen((text) {
      setState(() {
        _analysisLines.add(text);
        if (_analysisLines.length > 100) {
          _analysisLines.removeRange(0, _analysisLines.length - 100);
        }
      });
    });
    setState(() {});
  }

  @override
  void dispose() {
    _analysisSub?.cancel();
    _rtc.dispose();
    super.dispose();
  }

  Future<void> _startCall() async {
    final offer = await _rtc.createOffer();
    // TODO: send offer.sdp to your backend, get answer.sdp back, then:
    // await _rtc.setRemoteDescription(answerSdp, 'answer');
    setState(() => _inCall = true);
  }

  void _hangup() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen local camera (user view)
          Positioned.fill(
            child: RTCVideoView(
              _rtc.localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Small thumbnail of remote (AI avatar/video if available)
          Positioned(
            right: 16,
            top: 16,
            width: 120,
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black87,
                child: RTCVideoView(
                  _rtc.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // Live analysis overlay (scrolling text)
          Positioned(
            left: 16,
            right: 16,
            bottom: 120,
            height: 160,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _analysisLines.join('\n'),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),

          // Bottom call controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'mic',
                    backgroundColor: _micOn ? Colors.white10 : Colors.red,
                    onPressed: () async {
                      setState(() => _micOn = !_micOn);
                      final stream = _rtc.localRenderer.srcObject;
                      stream?.getAudioTracks().forEach((t) => t.enabled = _micOn);
                    },
                    child: Icon(_micOn ? Icons.mic : Icons.mic_off),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton(
                    heroTag: 'call',
                    backgroundColor: _inCall ? Colors.red : Colors.green,
                    onPressed: _inCall ? _hangup : _startCall,
                    child: Icon(_inCall ? Icons.call_end : Icons.call),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton(
                    heroTag: 'cam',
                    backgroundColor: _camOn ? Colors.white10 : Colors.red,
                    onPressed: () async {
                      setState(() => _camOn = !_camOn);
                      final stream = _rtc.localRenderer.srcObject;
                      stream?.getVideoTracks().forEach((t) => t.enabled = _camOn);
                    },
                    child: Icon(_camOn ? Icons.videocam : Icons.videocam_off),
                  ),
                ],
              ),
            ),
          ),

          // Back button (top-left)
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _hangup,
            ),
          ),
        ],
      ),
    );
  }
} 