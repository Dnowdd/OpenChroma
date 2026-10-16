import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Where audio-reactive effects listen.
enum AudioSource {
  off(0, 'Desligado'),
  system(1, 'Som do PC'),
  microphone(2, 'Microfone'),
  both(3, 'Som do PC e microfone');

  const AudioSource(this.code, this.label);
  final int code;
  final String label;

  static AudioSource byName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? AudioSource.system;
}

/// One analysis frame. Everything is normalized to 0..1.
class AudioFrame {
  const AudioFrame(
    this.bands,
    this.level,
    this.bass,
    this.mid,
    this.treble,
    this.beat, [
    this.beats = 0,
  ]);
  static const silent = AudioFrame([], 0, 0, 0, 0, 0);

  final List<double> bands;
  final double level;
  final double bass;
  final double mid;
  final double treble;
  final double beat;

  /// Increments on every detected beat; lets consumers that may miss frames
  /// still react to each beat exactly once.
  final int beats;

  Map<String, Object> toJson() => {
    'bands': [for (final b in bands) (b * 1000).round() / 1000],
    'level': level,
    'bass': bass,
    'mid': mid,
    'treble': treble,
    'beat': beat,
    'beats': beats,
  };
}

/// Native WASAPI capture (system loopback and/or microphone) implemented in
/// the Windows runner (windows/runner/audio_capture.cpp).
class AudioService {
  AudioService() {
    try {
      final exe = DynamicLibrary.executable();
      _setSource = exe.lookupFunction<Void Function(Int32), void Function(int)>(
        'OcAudioSetSource',
      );
      _read = exe
          .lookupFunction<
            Void Function(Pointer<Float>, Int32, Pointer<Float>),
            void Function(Pointer<Float>, int, Pointer<Float>)
          >('OcAudioRead');
    } catch (_) {
      // Not available (tests, other platforms): stays silent.
    }
  }

  static const bandCount = 64;

  void Function(int)? _setSource;
  void Function(Pointer<Float>, int, Pointer<Float>)? _read;
  final Pointer<Float> _bands = calloc<Float>(bandCount);
  final Pointer<Float> _stats = calloc<Float>(6);
  AudioSource _active = AudioSource.off;

  bool get available => _read != null;

  /// Starts or stops capture. Pass [AudioSource.off] when no running effect
  /// listens, so the microphone is not held open needlessly.
  void setSource(AudioSource source) {
    if (source == _active) return;
    _active = source;
    _setSource?.call(source.code);
  }

  AudioFrame read() {
    final read = _read;
    if (read == null || _active == AudioSource.off) return AudioFrame.silent;
    read(_bands, bandCount, _stats);
    return AudioFrame(
      List<double>.generate(bandCount, (i) => _bands[i]),
      _stats[0],
      _stats[1],
      _stats[2],
      _stats[3],
      _stats[4],
      _stats[5].round(),
    );
  }
}
