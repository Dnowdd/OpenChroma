import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';

import 'accent.dart';
import 'logo.dart';

typedef _SetIconNative = Void Function(
  Pointer<Uint8>,
  Int32,
  Pointer<Uint8>,
  Int32,
);
typedef _SetIcon = void Function(Pointer<Uint8>, int, Pointer<Uint8>, int);
typedef _SizesNative = Void Function(Pointer<Int32>, Pointer<Int32>);
typedef _Sizes = void Function(Pointer<Int32>, Pointer<Int32>);

/// Keeps the tray and taskbar icons in the accent: redrawn once the accent
/// settles on a new color.
class AppIconSync {
  AppIconSync(this.accent) {
    try {
      final exe = DynamicLibrary.executable();
      _setIcon = exe.lookupFunction<_SetIconNative, _SetIcon>('OcSetAppIcon');
      _sizes = exe.lookupFunction<_SizesNative, _Sizes>('OcAppIconSizes');
    } catch (_) {
      return;
    }
    accent.addListener(_onAccent);
    _onAccent();
  }

  final AccentController accent;
  _SetIcon? _setIcon;
  _Sizes? _sizes;
  Color? _shown;
  bool _drawing = false;

  void _onAccent() {
    if (!accent.settled || accent.value == _shown || _drawing) return;
    _draw(accent.value);
  }

  Future<void> _draw(Color color) async {
    final setIcon = _setIcon, sizes = _sizes;
    if (setIcon == null || sizes == null) return;
    _drawing = true;
    try {
      final out = calloc<Int32>(2);
      int small, big;
      try {
        sizes(out, out + 1);
        small = out[0].clamp(16, 256);
        big = out[1].clamp(16, 256);
      } finally {
        calloc.free(out);
      }
      final a = await renderLogoMark(color, small);
      final b = await renderLogoMark(color, big);
      final pa = calloc<Uint8>(a.length), pb = calloc<Uint8>(b.length);
      try {
        pa.asTypedList(a.length).setAll(0, a);
        pb.asTypedList(b.length).setAll(0, b);
        setIcon(pa, small, pb, big);
        _shown = color;
      } finally {
        calloc.free(pa);
        calloc.free(pb);
      }
    } catch (_) {
    } finally {
      _drawing = false;
    }
    if (accent.settled && accent.value != _shown) _draw(accent.value);
  }

  void dispose() => accent.removeListener(_onAccent);
}
