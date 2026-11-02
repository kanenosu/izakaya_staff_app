import 'dart:math';

/// Whisper 音声認識サービス（デモ実装）
///
/// 本来は OpenAI Whisper API に録音データを送信して文字起こしするが、
/// このデモでは実際の通信・録音は行わず、擬似的に認識結果を返す。
/// 音声認識ボタンの UX（録音 → 認識 → メニュー反映）を体験するための実装。
class WhisperService {
  bool _isRecording = false;
  final Random _rng = Random();

  bool get isRecording => _isRecording;

  /// 録音開始（デモのため常に成功）
  Future<bool> startRecording() async {
    _isRecording = true;
    return true;
  }

  /// 録音停止＆文字起こし（デモ）
  ///
  /// [candidates] に渡されたメニュー名からランダムに1件返す。
  /// 実際の API 通信の代わりに、少し待ってから結果を返すことで
  /// 「認識中」の体験を再現する。
  Future<String?> stopAndTranscribe(List<String> candidates) async {
    _isRecording = false;
    await Future.delayed(const Duration(milliseconds: 900));
    if (candidates.isEmpty) return null;
    return candidates[_rng.nextInt(candidates.length)];
  }

  void dispose() {}
}
