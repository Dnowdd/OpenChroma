import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Frees what the app does not need while it sits in the tray: image caches
/// right away, and idle pages back to Windows once things settle.
class BackgroundTrim {
  BackgroundTrim() {
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  static const _settle = Duration(seconds: 5);
  static const _repeat = Duration(minutes: 5);

  void _onHide() {
    _timer?.cancel();
    final images = PaintingBinding.instance.imageCache;
    images.clear();
    images.clearLiveImages();
    _timer = Timer(_settle, () {
      _trimWorkingSet();
      _timer = Timer.periodic(_repeat, (_) => _trimWorkingSet());
    });
  }

  void _onShow() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _onShow();
    _lifecycle.dispose();
  }
}

final _setWorkingSet = Platform.isWindows ? _lookupSetWorkingSet() : null;

int Function(int, int, int)? _lookupSetWorkingSet() {
  try {
    return DynamicLibrary.open('kernel32.dll').lookupFunction<
      Int32 Function(IntPtr, IntPtr, IntPtr),
      int Function(int, int, int)
    >('SetProcessWorkingSetSize');
  } catch (_) {
    return null;
  }
}

void _trimWorkingSet() => _setWorkingSet?.call(-1, -1, -1);
