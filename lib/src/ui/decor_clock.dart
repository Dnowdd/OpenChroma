import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Drives decorative animations (spinning fans, the light strip) at a fixed
/// rate instead of every display refresh. A [Ticker] asks for a frame on
/// every vsync, which on 120-144 Hz monitors kept the raster thread and the
/// GPU driver busy for what are only ornaments.
abstract final class DecorClock {
  static const rate = 30;

  static final _listeners = <VoidCallback>{};
  static Timer? _timer;

  static void add(VoidCallback listener) {
    _listeners.add(listener);
    _timer ??= Timer.periodic(
      const Duration(microseconds: 1000000 ~/ rate),
      (_) => _tick(),
    );
  }

  static void remove(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static void _tick() {
    // Hidden or minimized window: nothing would be drawn.
    if (!SchedulerBinding.instance.framesEnabled) return;
    for (final l in [..._listeners]) {
      l();
    }
  }
}

/// Calls [onDecorTick] from [DecorClock] while the widget's tickers are
/// enabled, so animations on hidden pages stop like [Ticker]s do.
mixin DecorClockMixin<T extends StatefulWidget> on State<T> {
  ValueListenable<TickerModeData>? _mode;
  bool _subscribed = false;

  /// Advances the animation; called [DecorClock.rate] times per second.
  void onDecorTick();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = TickerMode.getValuesNotifier(context);
    if (mode != _mode) {
      _mode?.removeListener(_update);
      _mode = mode..addListener(_update);
    }
    _update();
  }

  void _update() {
    final on = _mode?.value.enabled ?? true;
    if (on == _subscribed) return;
    _subscribed = on;
    on ? DecorClock.add(onDecorTick) : DecorClock.remove(onDecorTick);
  }

  @override
  void dispose() {
    _mode?.removeListener(_update);
    if (_subscribed) DecorClock.remove(onDecorTick);
    super.dispose();
  }
}
