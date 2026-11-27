// Administrator rights: whether this process has them, and running programs
// (this app or a helper like schtasks) through the UAC prompt. Exposed to
// Dart through the C functions below, looked up with
// DynamicLibrary.executable().
#include <windows.h>
#include <shellapi.h>

extern "C" {

__declspec(dllexport) int OcIsElevated() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return 0;
  TOKEN_ELEVATION e{};
  DWORD len = 0;
  const bool ok =
      GetTokenInformation(token, TokenElevation, &e, sizeof(e), &len) &&
      e.TokenIsElevated;
  CloseHandle(token);
  return ok ? 1 : 0;
}

// Runs this executable with [params] elevated, showing the UAC prompt. With
// [wait], blocks until it exits and returns its exit code; otherwise returns
// 0 once it started. Returns -1 when the prompt was declined or the launch
// failed or [file] is not null: only this executable is ever elevated.
__declspec(dllexport) int OcRunElevated(const wchar_t* file,
                                        const wchar_t* params, int wait) {
  if (file) return -1;
  wchar_t self[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, self, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return -1;
  file = self;
  SHELLEXECUTEINFOW info{sizeof(info)};
  info.fMask = wait ? SEE_MASK_NOCLOSEPROCESS : 0;
  info.lpVerb = L"runas";
  info.lpFile = file;
  info.lpParameters = params;
  info.nShow = wait ? SW_HIDE : SW_SHOWNORMAL;
  if (!ShellExecuteExW(&info)) return -1;
  if (!wait) return 0;
  if (!info.hProcess) return -1;
  WaitForSingleObject(info.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(info.hProcess, &code);
  CloseHandle(info.hProcess);
  return static_cast<int>(code);
}

}  // extern "C"
