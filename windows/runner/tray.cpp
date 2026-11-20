#include "tray.h"

#include <dwmapi.h>
#include <shellapi.h>

#include <cstdint>
#include <cwchar>

#include "resource.h"

namespace tray {
namespace {

constexpr UINT kCallback = WM_APP + 0x0C2;
constexpr UINT kIconId = 1;
constexpr UINT kMenuOpen = 1;
constexpr UINT kMenuQuit = 2;

// HKCU values, also written by lib/src/system/launch_settings.dart.
constexpr wchar_t kKey[] = L"Software\\OpenChroma";

const UINT g_show_message = RegisterWindowMessageW(L"OpenChroma.ShowWindow");
const UINT g_taskbar_created = RegisterWindowMessageW(L"TaskbarCreated");
HWND g_window = nullptr;
HANDLE g_instance = nullptr;
HICON g_icon = nullptr;
bool g_icon_added = false;
bool g_quitting = false;

bool HasArg(const wchar_t* arg) {
  return wcsstr(GetCommandLineW(), arg) != nullptr;
}

DWORD ReadValue(const wchar_t* name, DWORD fallback) {
  DWORD value = 0, size = sizeof(value);
  return RegGetValueW(HKEY_CURRENT_USER, kKey, name, RRF_RT_REG_DWORD, nullptr,
                      &value, &size) == ERROR_SUCCESS
             ? value
             : fallback;
}

void WriteValue(const wchar_t* name, DWORD value) {
  RegSetKeyValueW(HKEY_CURRENT_USER, kKey, name, REG_DWORD, &value,
                  sizeof(value));
}

// Closing the window keeps the app running unless the user turned it off.
bool RunInBackground() { return ReadValue(L"RunInBackground", 1) != 0; }

void AddIcon() {
  if (g_icon_added || !g_window) return;
  if (!g_icon) {
    g_icon = static_cast<HICON>(LoadImageW(
        GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
        GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
        LR_DEFAULTCOLOR));
  }
  NOTIFYICONDATAW n{};
  n.cbSize = sizeof(n);
  n.hWnd = g_window;
  n.uID = kIconId;
  n.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  n.uCallbackMessage = kCallback;
  n.hIcon = g_icon;
  wcscpy_s(n.szTip, L"OpenChroma");
  g_icon_added = Shell_NotifyIconW(NIM_ADD, &n) != FALSE;
}

// Tells, once, where the window went.
void ShowHint() {
  if (!g_icon_added || ReadValue(L"TrayHintShown", 0)) return;
  WriteValue(L"TrayHintShown", 1);
  NOTIFYICONDATAW n{};
  n.cbSize = sizeof(n);
  n.hWnd = g_window;
  n.uID = kIconId;
  n.uFlags = NIF_INFO;
  wcscpy_s(n.szInfoTitle, L"O OpenChroma continua ligado");
  wcscpy_s(n.szInfo,
           L"Luzes e ventoinhas seguem funcionando. Clique no ícone "
           L"para abrir.");
  n.dwInfoFlags = NIIF_INFO;
  Shell_NotifyIconW(NIM_MODIFY, &n);
}

void ShowWindowFromTray(HWND window) {
  ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window);
}

void ShowMenu(HWND window) {
  HMENU menu = CreatePopupMenu();
  AppendMenuW(menu, MF_STRING, kMenuOpen, L"Abrir o OpenChroma");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuQuit, L"Sair");
  SetMenuDefaultItem(menu, kMenuOpen, FALSE);
  POINT p;
  GetCursorPos(&p);
  // Without it the menu would not close when clicking elsewhere.
  SetForegroundWindow(window);
  const UINT cmd = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
      p.x, p.y, 0, window, nullptr);
  PostMessage(window, WM_NULL, 0, 0);
  DestroyMenu(menu);
  if (cmd == kMenuOpen) {
    ShowWindowFromTray(window);
  } else if (cmd == kMenuQuit) {
    // A real close: Flutter asks Dart, which hands fans back and lets
    // plugins apply their shutdown colors before exiting.
    g_quitting = true;
    PostMessage(window, WM_CLOSE, 0, 0);
  }
}

}  // namespace

bool SignalRunningInstance() {
  g_instance = CreateMutexW(nullptr, FALSE, L"Local\\OpenChroma.Instance");
  const DWORD error = GetLastError();
  // Restarting as administrator: the old instance exits once this one runs.
  if (HasArg(L"--replace")) return false;
  const bool running = g_instance ? error == ERROR_ALREADY_EXISTS
                                  : error == ERROR_ACCESS_DENIED;
  if (!running) return false;
  // The other instance may still be creating its window.
  for (int i = 0; i < 20; i++) {
    if (HWND other = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"OpenChroma")) {
      AllowSetForegroundWindow(ASFW_ANY);
      PostMessage(other, g_show_message, 0, 0);
      return true;
    }
    Sleep(100);
  }
  return false;
}

void Attach(HWND window) {
  g_window = window;
  // Let a non-elevated second launch (and Explorer) reach an elevated one.
  ChangeWindowMessageFilterEx(window, g_show_message, MSGFLT_ALLOW, nullptr);
  ChangeWindowMessageFilterEx(window, g_taskbar_created, MSGFLT_ALLOW, nullptr);
}

bool StartHidden() { return HasArg(L"--hidden"); }

void Hide(HWND window) {
  // Flutter only stops rendering (lifecycle "hidden") for a minimized
  // window; a merely hidden one counts as visible and keeps drawing. So
  // minimize first, without the animation, then hide.
  BOOL disable = TRUE;
  DwmSetWindowAttribute(window, DWMWA_TRANSITIONS_FORCEDISABLED, &disable,
                        sizeof(disable));
  ShowWindow(window, SW_MINIMIZE);
  ShowWindow(window, SW_HIDE);
  disable = FALSE;
  DwmSetWindowAttribute(window, DWMWA_TRANSITIONS_FORCEDISABLED, &disable,
                        sizeof(disable));
  AddIcon();
  ShowHint();
}

bool HandleMessage(HWND window, UINT message, WPARAM, LPARAM lparam,
                   LRESULT* result) {
  *result = 0;
  if (message == WM_CLOSE) {
    if (g_quitting || !RunInBackground()) return false;
    Hide(window);
    return true;
  }
  if (message == kCallback) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
      case WM_LBUTTONDBLCLK:
        ShowWindowFromTray(window);
        break;
      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        ShowMenu(window);
        break;
    }
    return true;
  }
  if (message == g_show_message) {
    ShowWindowFromTray(window);
    return true;
  }
  if (message == g_taskbar_created) {
    // Explorer restarted and lost the icon.
    if (g_icon_added) {
      g_icon_added = false;
      AddIcon();
    }
    return true;
  }
  return false;
}

void Notify(const wchar_t* title, const wchar_t* body) {
  AddIcon();
  if (!g_icon_added) return;
  NOTIFYICONDATAW n{};
  n.cbSize = sizeof(n);
  n.hWnd = g_window;
  n.uID = kIconId;
  n.uFlags = NIF_INFO;
  wcsncpy_s(n.szInfoTitle, title, _TRUNCATE);
  wcsncpy_s(n.szInfo, body, _TRUNCATE);
  n.dwInfoFlags = NIIF_WARNING;
  Shell_NotifyIconW(NIM_MODIFY, &n);
}

namespace {

// A 32-bit icon from [size] x [size] straight-alpha RGBA pixels.
HICON IconFromRgba(const std::uint8_t* rgba, int size) {
  BITMAPV5HEADER h{};
  h.bV5Size = sizeof(h);
  h.bV5Width = size;
  h.bV5Height = -size;
  h.bV5Planes = 1;
  h.bV5BitCount = 32;
  h.bV5Compression = BI_BITFIELDS;
  h.bV5RedMask = 0x00FF0000;
  h.bV5GreenMask = 0x0000FF00;
  h.bV5BlueMask = 0x000000FF;
  h.bV5AlphaMask = 0xFF000000;
  void* bits = nullptr;
  HDC dc = GetDC(nullptr);
  HBITMAP color = CreateDIBSection(dc, reinterpret_cast<BITMAPINFO*>(&h),
                                   DIB_RGB_COLORS, &bits, nullptr, 0);
  ReleaseDC(nullptr, dc);
  if (!color) return nullptr;
  auto* out = static_cast<std::uint8_t*>(bits);
  for (int i = 0; i < size * size; i++) {
    out[i * 4] = rgba[i * 4 + 2];
    out[i * 4 + 1] = rgba[i * 4 + 1];
    out[i * 4 + 2] = rgba[i * 4];
    out[i * 4 + 3] = rgba[i * 4 + 3];
  }
  HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
  ICONINFO info{};
  info.fIcon = TRUE;
  info.hbmColor = color;
  info.hbmMask = mask;
  HICON icon = CreateIconIndirect(&info);
  DeleteObject(color);
  DeleteObject(mask);
  return icon;
}

HICON g_window_small = nullptr;
HICON g_window_big = nullptr;

}  // namespace

void SetIcon(const std::uint8_t* tiny_rgba, int tiny_size,
             const std::uint8_t* big_rgba, int big_size) {
  HICON tiny = IconFromRgba(tiny_rgba, tiny_size);
  HICON tiny_window = IconFromRgba(tiny_rgba, tiny_size);
  HICON big = IconFromRgba(big_rgba, big_size);
  if (!tiny || !tiny_window || !big) {
    if (tiny) DestroyIcon(tiny);
    if (tiny_window) DestroyIcon(tiny_window);
    if (big) DestroyIcon(big);
    return;
  }
  HICON old_tray = g_icon;
  g_icon = tiny;
  if (g_icon_added) {
    NOTIFYICONDATAW n{};
    n.cbSize = sizeof(n);
    n.hWnd = g_window;
    n.uID = kIconId;
    n.uFlags = NIF_ICON;
    n.hIcon = g_icon;
    Shell_NotifyIconW(NIM_MODIFY, &n);
  }
  if (g_window) {
    SendMessageW(g_window, WM_SETICON, ICON_SMALL,
                 reinterpret_cast<LPARAM>(tiny_window));
    SendMessageW(g_window, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big));
  }
  if (old_tray) DestroyIcon(old_tray);
  if (g_window_small) DestroyIcon(g_window_small);
  if (g_window_big) DestroyIcon(g_window_big);
  g_window_small = tiny_window;
  g_window_big = big;
}

void IconSizes(int* tiny_size, int* big_size) {
  const UINT dpi = g_window ? GetDpiForWindow(g_window) : 96;
  *tiny_size = GetSystemMetricsForDpi(SM_CXSMICON, dpi);
  *big_size = GetSystemMetricsForDpi(SM_CXICON, dpi);
}

void RemoveIcon() {
  if (!g_icon_added) return;
  NOTIFYICONDATAW n{};
  n.cbSize = sizeof(n);
  n.hWnd = g_window;
  n.uID = kIconId;
  Shell_NotifyIconW(NIM_DELETE, &n);
  g_icon_added = false;
}

}  // namespace tray

extern "C" {

// For exits that skip the window's destruction (exit() from Dart).
__declspec(dllexport) void OcTrayRemoveIcon() { tray::RemoveIcon(); }

// A Windows notification from the tray icon (smart alerts). Windows shows
// balloons as toasts; the icon is added first if the window is open.
__declspec(dllexport) void OcTrayNotify(const wchar_t* title,
                                        const wchar_t* body) {
  tray::Notify(title, body);
}

// Sizes, in pixels, of the tiny (tray, title) and big (taskbar) icons.
__declspec(dllexport) void OcAppIconSizes(int* tiny_size, int* big_size) {
  tray::IconSizes(tiny_size, big_size);
}

// Replaces the tray and window icons with straight-alpha RGBA pixels, so
// they follow the app's accent.
__declspec(dllexport) void OcSetAppIcon(const std::uint8_t* tiny_rgba,
                                        int tiny_size,
                                        const std::uint8_t* big_rgba,
                                        int big_size) {
  tray::SetIcon(tiny_rgba, tiny_size, big_rgba, big_size);
}

}  // extern "C"
