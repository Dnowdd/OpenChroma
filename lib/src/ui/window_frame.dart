import 'dart:ffi' hide Size;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;

import 'logo.dart';
import 'theme.dart';
import 'widgets.dart';

/// The window's own controls, through windows/runner/win32_window.cpp (the
/// native caption is removed).
class AppWindow {
  static final void Function(int)? _request = () {
    try {
      return DynamicLibrary.executable()
          .lookupFunction<Void Function(Int32), void Function(int)>(
            'OcWindowRequest',
          );
    } catch (_) {
      return null;
    }
  }();
  static final int Function()? _isMaximized = () {
    try {
      return DynamicLibrary.executable()
          .lookupFunction<Int32 Function(), int Function()>(
            'OcWindowIsMaximized',
          );
    } catch (_) {
      return null;
    }
  }();

  static bool get available => _request != null;
  static bool get isMaximized => (_isMaximized?.call() ?? 0) == 1;
  static void minimize() => _request?.call(0);
  static void toggleMaximize() => _request?.call(1);
  static void close() => _request?.call(2);
  static void startMove() => _request?.call(3);

  // Win32 hit-test codes of the top edges.
  static void startResizeTop() => _request?.call(10 + 12);
  static void startResizeTopLeft() => _request?.call(10 + 13);
  static void startResizeTopRight() => _request?.call(10 + 14);
}

/// Title bar: drag to move, double-click to maximize, and the window
/// buttons. Its top edge resizes the window (the other edges are native).
class TitleBar extends StatefulWidget {
  const TitleBar({super.key});

  static const height = 46.0;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  DateTime _lastDown = DateTime(0);

  void _onDown(PointerDownEvent e) {
    if (e.buttons != kPrimaryButton) return;
    final now = DateTime.now();
    if (now.difference(_lastDown) < const Duration(milliseconds: 400)) {
      _lastDown = DateTime(0);
      AppWindow.toggleMaximize();
      return;
    }
    _lastDown = now;
    AppWindow.startMove();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppWindow.available) return const SizedBox.shrink();
    // Rebuilds on resize, which is when maximized state can change.
    MediaQuery.sizeOf(context);
    final maximized = AppWindow.isMaximized;
    return SizedBox(
      height: TitleBar.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: _onDown,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Row(
                  children: [const OcLogo(height: 20), const Spacer()],
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                _WindowButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Minimizar',
                  onTap: AppWindow.minimize,
                ),
                const SizedBox(width: 4),
                _WindowButton(
                  icon: maximized
                      ? Icons.filter_none_rounded
                      : Icons.crop_square_rounded,
                  iconSize: maximized ? 13 : 15,
                  tooltip: maximized ? 'Restaurar' : 'Maximizar',
                  onTap: AppWindow.toggleMaximize,
                ),
                const SizedBox(width: 4),
                _WindowButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Fechar',
                  danger: true,
                  onTap: AppWindow.close,
                ),
              ],
            ),
          ),
          if (!maximized) ...[
            Positioned(
              left: 8,
              right: 8,
              top: 0,
              height: 5,
              child: _ResizeEdge(
                cursor: SystemMouseCursors.resizeUp,
                onDown: AppWindow.startResizeTop,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 8,
              height: 8,
              child: _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpLeft,
                onDown: AppWindow.startResizeTopLeft,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              width: 8,
              height: 8,
              child: _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpRight,
                onDown: AppWindow.startResizeTopRight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResizeEdge extends StatelessWidget {
  const _ResizeEdge({required this.cursor, required this.onDown});
  final MouseCursor cursor;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: cursor,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (e.buttons == kPrimaryButton) onDown();
      },
    ),
  );
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconSize = 16,
    this.danger = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double iconSize;
  final bool danger;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Hover(
      onTap: onTap,
      builder: (context, h) => AnimatedContainer(
        duration: Oc.fast,
        width: 40,
        height: 30,
        decoration: BoxDecoration(
          color: h ? (danger ? Oc.danger : Oc.hover) : Colors.transparent,
          borderRadius: Oc.pill,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: h ? (danger ? Colors.white : Oc.text) : Oc.textSecondary,
        ),
      ),
    ),
  );
}
