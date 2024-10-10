import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Sound Recording',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: SoundRecorder());
  }
}

class SoundRecorder extends StatefulWidget {
  @override
  _SoundRecorderState createState() => _SoundRecorderState();
}

class _SoundRecorderState extends State<SoundRecorder> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _filePath;
  StreamSubscription? _recorderSubscription;
  String _recordDuration = "00:00";

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      // マイクのパーミッションをリクエスト
      await Permission.microphone.request();
      if (await Permission.microphone.isGranted) {
        // Recorder をオープン
        await _recorder!.openRecorder();

        // オーディオセッションを設定
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.defaultToSpeaker,
        ));

        // Recorder の更新頻度を設定
        await _recorder!.setSubscriptionDuration(Duration(milliseconds: 100));

        // Player をオープン
        await _player!.openPlayer();
      } else {
        throw RecordingPermissionException('マイクのアクセスが拒否されました');
      }
    } catch (e) {
      print("Recorder initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _recorder!.closeRecorder();
    _player!.closePlayer();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (!_isRecording) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        _filePath = '${appDocDir.path}/recording.wav';
        await _recorder!.startRecorder(
          toFile: _filePath,
          codec: Codec.pcm16WAV,
        );
        setState(() {
          _isRecording = true;
        });

        _recorderSubscription =
            _recorder!.onProgress!.listen((RecordingDisposition event) {
              if (event != null && event.duration != null) {
                final duration = event.duration;
                print("Recording duration: ${_formatDuration(duration)}");
                setState(() {
                  _recordDuration = _formatDuration(duration);
                });
              }
            });
      }
    } catch (e) {
      print("Failed to start recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder!.stopRecorder();
      _recorderSubscription?.cancel();
      setState(() {
        _isRecording = false;
        _recordDuration = "00:00";
      });
    } catch (e) {
      print("Failed to stop recording: $e");
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_filePath != null && !_isPlaying) {
        await _player!.startPlayer(
            fromURI: _filePath,
            whenFinished: () {
              setState(() {
                _isPlaying = false;
              });
            });
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print("Failed to play recording: $e");
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _player!.stopPlayer();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      print("Failed to stop playing: $e");
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sound Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Recording Duration: $_recordDuration',
                style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child:
              Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isPlaying ? _stopPlaying : _playRecording,
              child: Text(_isPlaying ? 'Stop Playing' : 'Play Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
