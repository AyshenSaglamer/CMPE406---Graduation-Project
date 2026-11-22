import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// A finished recording, ready for POST /ai/voice.
class RecordedAudio {
  final Uint8List bytes;
  final String filename;
  final Duration duration;

  const RecordedAudio({
    required this.bytes,
    required this.filename,
    required this.duration,
  });
}

/// Records the microphone for voice logging. The screen talks to this
/// interface, so tests can use a fake without a microphone.
abstract class VoiceRecorder {
  /// Asks for the microphone if needed and starts recording. False when the
  /// permission is refused.
  Future<bool> start();

  /// Stops and returns the recording, or null when nothing was recorded.
  Future<RecordedAudio?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  void dispose();
}

/// Records 16 kHz mono 16-bit PCM from the microphone and wraps it in a WAV
/// file. WAV is read by the backend and by the speech-to-text (Whisper)
/// without conversion, and recording to memory needs no file system, so it
/// also works in the browser. One minute is about 1.9 MB (limit: 10 MB).
class MicVoiceRecorder implements VoiceRecorder {
  MicVoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const int sampleRate = 16000;
  static const int channels = 1;

  final AudioRecorder _recorder;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  DateTime? _startedAt;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) {
      return false;
    }

    _pcm.clear();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
      ),
    );

    _subscription = stream.listen(_pcm.add);
    _startedAt = DateTime.now();

    return true;
  }

  @override
  Future<RecordedAudio?> stop() async {
    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;

    final pcm = _pcm.takeBytes();
    final started = _startedAt;
    _startedAt = null;

    if (pcm.isEmpty) {
      return null;
    }

    return RecordedAudio(
      bytes: wavFromPcm16(pcm, sampleRate: sampleRate, channels: channels),
      filename: 'recording.wav',
      duration: started == null
          ? Duration.zero
          : DateTime.now().difference(started),
    );
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _pcm.clear();
    _startedAt = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _recorder.dispose();
  }
}

/// A WAV file (44-byte RIFF header + data) around little-endian 16-bit PCM.
Uint8List wavFromPcm16(
  Uint8List pcm, {
  required int sampleRate,
  required int channels,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;

  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + pcm.length, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little) // fmt chunk size
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, pcm.length, Endian.little);

  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}
