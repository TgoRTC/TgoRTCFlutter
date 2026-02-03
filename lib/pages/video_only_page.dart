import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

/// A pure video rendering page designed to be embedded in HarmonyOS native UI.
/// 
/// This page contains no controls (buttons, sliders, etc.) and only focuses on
/// rendering the video tracks of participants in a grid.
class VideoOnlyPage extends StatefulWidget {
  const VideoOnlyPage({super.key});

  @override
  State<VideoOnlyPage> createState() => _VideoOnlyPageState();
}

class _VideoOnlyPageState extends State<VideoOnlyPage> {
  List<TgoParticipant> _participants = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _updateParticipants();
  }

  void _setupListeners() {
    // Listen for new participants
    TgoRTC.instance.participantManager.addNewParticipantListener((participant) {
      if (mounted) {
        _updateParticipants();
      }
    });

    // We also need to listen for room connection events to clear or refresh
    TgoRTC.instance.roomManager.addConnectListener((roomName, status, reason) {
      if (mounted) {
        if (status == ConnectStatus.connected || status == ConnectStatus.disconnected) {
          _updateParticipants();
        }
      }
    });
  }

  void _updateParticipants() {
    setState(() {
      try {
        _participants = TgoRTC.instance.participantManager.getAllParticipants();
      } catch (e) {
        // Handle cases where local participant might not be available yet
        _participants = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_participants.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Waiting for connection...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _participants.length <= 1 ? 1 : 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          return _buildVideoTile(_participants[index]);
        },
      ),
    );
  }

  Widget _buildVideoTile(TgoParticipant participant) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(51), width: 0.5),
        color: const Color(0xFF1A1A1A),
      ),
      child: Stack(
        children: [
          // Video Renderer
          (TgoTrackRenderer(
            source: TrackSource.camera,
            fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )..setParticipant(participant)).build(),
          
          // Participant Name / UID Overlay
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!participant.getMicrophoneEnabled())
                    const Icon(Icons.mic_off, color: Colors.red, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${participant.uid}${participant.isLocal ? " (Me)" : ""}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper App wrapper for VideoOnlyPage.
class VideoOnlyApp extends StatelessWidget {
  const VideoOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const VideoOnlyPage(),
    );
  }
}
