import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class WhisperService {
  // ignore: constant_identifier_names
  static const String _apiKey = 'YOUR_OPENAI_API_KEY';
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> startRecording() async {
    if (kIsWeb) return false;
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
      path: path,
    );
    _isRecording = true;
    return true;
  }

  Future<String?> stopAndTranscribe() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    if (path == null) return null;
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      req.headers['Authorization'] = 'Bearer $_apiKey';
      req.fields['model'] = 'whisper-1';
      req.fields['language'] = 'ja';
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          filename: 'audio.m4a',
        ),
      );
      final res = await req.send();
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        return (jsonDecode(body) as Map<String, dynamic>)['text'] as String?;
      }
    } catch (_) {}
    return null;
  }

  void dispose() => _recorder.dispose();
}
