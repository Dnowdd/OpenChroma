#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <dbghelp.h>
#include <shlobj.h>

#include <csignal>
#include <cstdio>
#include <string>

#include "flutter_window.h"
#include "tray.h"
#include "utils.h"

namespace {

// Appends a crash report (exception, module+offset stack) to
// %APPDATA%\OpenChroma\crash.log so native crashes leave a trace.
std::wstring CrashLogPath() {
  PWSTR appdata = nullptr;
  std::wstring path;
  if (SUCCEEDED(::SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr,
                                       &appdata))) {
    path = std::wstring(appdata) + L"\\OpenChroma";
    ::CreateDirectoryW(path.c_str(), nullptr);
    path += L"\\crash.log";
  }
  ::CoTaskMemFree(appdata);
  return path;
}

void WriteFrame(FILE* f, DWORD64 address) {
  HMODULE module = nullptr;
  wchar_t name[MAX_PATH] = L"?";
  if (::GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                               GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCWSTR>(address), &module)) {
    ::GetModuleFileNameW(module, name, MAX_PATH);
  }
  const wchar_t* base = wcsrchr(name, L'\\');
  fwprintf(f, L"  %ls+0x%llx\n", base ? base + 1 : name,
           address - reinterpret_cast<DWORD64>(module));
}

LONG WINAPI OnUnhandledException(EXCEPTION_POINTERS* info) {
  const std::wstring path = CrashLogPath();
  FILE* f = nullptr;
  if (path.empty() || _wfopen_s(&f, path.c_str(), L"a") != 0 || !f) {
    return EXCEPTION_CONTINUE_SEARCH;
  }
  SYSTEMTIME t;
  ::GetLocalTime(&t);
  fwprintf(f, L"--- %04d-%02d-%02d %02d:%02d:%02d thread %lu\n", t.wYear,
           t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond,
           ::GetCurrentThreadId());
  const EXCEPTION_RECORD* rec = info->ExceptionRecord;
  fwprintf(f, L"exception 0x%08lx at\n", rec->ExceptionCode);
  WriteFrame(f, reinterpret_cast<DWORD64>(rec->ExceptionAddress));
  if (rec->ExceptionCode == EXCEPTION_ACCESS_VIOLATION &&
      rec->NumberParameters >= 2) {
    fwprintf(f, L"%ls address 0x%llx\n",
             rec->ExceptionInformation[0] ? L"write" : L"read",
             static_cast<unsigned long long>(rec->ExceptionInformation[1]));
  }
  fwprintf(f, L"stack:\n");
  CONTEXT ctx = *info->ContextRecord;
  STACKFRAME64 frame = {};
  frame.AddrPC.Offset = ctx.Rip;
  frame.AddrPC.Mode = AddrModeFlat;
  frame.AddrFrame.Offset = ctx.Rbp;
  frame.AddrFrame.Mode = AddrModeFlat;
  frame.AddrStack.Offset = ctx.Rsp;
  frame.AddrStack.Mode = AddrModeFlat;
  HANDLE process = ::GetCurrentProcess();
  ::SymInitialize(process, nullptr, TRUE);
  for (int i = 0; i < 48; i++) {
    if (!::StackWalk64(IMAGE_FILE_MACHINE_AMD64, process, ::GetCurrentThread(),
                       &frame, &ctx, nullptr, ::SymFunctionTableAccess64,
                       ::SymGetModuleBase64, nullptr) ||
        frame.AddrPC.Offset == 0) {
      break;
    }
    WriteFrame(f, frame.AddrPC.Offset);
  }
  fclose(f);
  return EXCEPTION_CONTINUE_SEARCH;
}

void OnAbort(int) {
  const std::wstring path = CrashLogPath();
  FILE* f = nullptr;
  if (!path.empty() && _wfopen_s(&f, path.c_str(), L"a") == 0 && f) {
    fwprintf(f, L"--- abort() on thread %lu\n", ::GetCurrentThreadId());
    fclose(f);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::SetUnhandledExceptionFilter(OnUnhandledException);
  std::signal(SIGABRT, OnAbort);

  // One instance drives the devices; a second launch shows the first.
  if (tray::SignalRunningInstance()) {
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"openchroma", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
