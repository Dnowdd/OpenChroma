// Background mode: closing the window can leave the app running in the
// notification area, so fans and lights keep being driven; and a second
// launch brings the running instance back instead of starting another one.
#ifndef RUNNER_TRAY_H_
#define RUNNER_TRAY_H_

#include <windows.h>

#include <cstdint>

namespace tray {

// True when another instance already runs; it has been asked to show its
// window. Call once at startup, before creating the window.
bool SignalRunningInstance();

// Sets up [window] for tray messages. Call after it is created.
void Attach(HWND window);

// Launched with --hidden (e.g. at Windows logon): stay in the tray.
bool StartHidden();

// Hides [window] to the tray.
void Hide(HWND window);

// Handles tray-related messages, including the close request when the app
// should keep running. Returns true when [message] was handled.
bool HandleMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam,
                   LRESULT* result);

// Shows a notification from the tray icon, adding the icon if needed.
void Notify(const wchar_t* title, const wchar_t* body);

// Replaces the tray and window icons with [tiny_size] and [big_size]
// square straight-alpha RGBA images.
void SetIcon(const std::uint8_t* tiny_rgba, int tiny_size,
             const std::uint8_t* big_rgba, int big_size);

// The tiny and big icon sizes for the window's monitor.
void IconSizes(int* tiny_size, int* big_size);

void RemoveIcon();

}  // namespace tray

#endif  // RUNNER_TRAY_H_
