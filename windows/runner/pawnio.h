// PawnIO driver access, shared by the hardware monitor and fan control.
// PawnIOLib.dll comes with the PawnIO installer; the modules it runs are
// the .bin files shipped in assets/pawnio. Opening the driver needs an
// elevated process.
#ifndef RUNNER_PAWNIO_H_
#define RUNNER_PAWNIO_H_

#include <windows.h>

#include "security.h"

#include <string>
#include <vector>

namespace oc {

inline std::wstring ExeDir() {
  wchar_t path[MAX_PATH];
  const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring s(path, n);
  return s.substr(0, s.find_last_of(L"\\/"));
}

class PawnIo {
 public:
  PawnIo() = default;
  PawnIo(const PawnIo&) = delete;
  PawnIo& operator=(const PawnIo&) = delete;
  ~PawnIo() { Close(); }

  // True when PawnIOLib.dll is present (the driver is installed).
  static bool Installed() {
    const std::wstring pf = ProgramFilesDir();
    if (pf.empty()) return false;
    return GetFileAttributesW((pf + L"\\PawnIO\\PawnIOLib.dll").c_str()) !=
           INVALID_FILE_ATTRIBUTES;
  }

  // Loads [module] (a file in assets/pawnio). Needs an elevated process.
  bool Open(const wchar_t* module) {
    if (handle_) return true;
    if (!lib_) {
      const std::wstring pf = ProgramFilesDir();
      if (pf.empty()) return false;
      lib_ = LoadLibraryExW((pf + L"\\PawnIO\\PawnIOLib.dll").c_str(), nullptr,
                            LOAD_LIBRARY_SEARCH_DEFAULT_DIRS |
                                LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR);
      if (!lib_) return false;
      open_ = reinterpret_cast<OpenFn>(GetProcAddress(lib_, "pawnio_open"));
      load_ = reinterpret_cast<LoadFn>(GetProcAddress(lib_, "pawnio_load"));
      exec_ = reinterpret_cast<ExecFn>(GetProcAddress(lib_, "pawnio_execute"));
      close_ = reinterpret_cast<CloseFn>(GetProcAddress(lib_, "pawnio_close"));
    }
    if (!open_ || !load_ || !exec_ || !close_) return false;

    const std::wstring path =
        ExeDir() + L"\\data\\flutter_assets\\assets\\pawnio\\" + module;
    HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                           OPEN_EXISTING, 0, nullptr);
    if (f == INVALID_HANDLE_VALUE) return false;
    std::vector<UCHAR> blob(GetFileSize(f, nullptr));
    DWORD read = 0;
    const bool ok = ReadFile(f, blob.data(), static_cast<DWORD>(blob.size()),
                             &read, nullptr) &&
                    read == blob.size();
    CloseHandle(f);
    if (!ok) return false;

    HANDLE h = nullptr;
    if (FAILED(open_(&h)) || !h) return false;
    if (FAILED(load_(h, blob.data(), blob.size()))) {
      close_(h);
      return false;
    }
    handle_ = h;
    return true;
  }

  bool Execute(const char* fn, const ULONG64* in, SIZE_T in_count, ULONG64* out,
               SIZE_T out_count) {
    if (!handle_) return false;
    SIZE_T ret = 0;
    return SUCCEEDED(exec_(handle_, fn, in, in_count, out, out_count, &ret));
  }

  bool IsOpen() const { return handle_ != nullptr; }

  void Close() {
    if (handle_ && close_) close_(handle_);
    handle_ = nullptr;
  }

 private:
  using OpenFn = HRESULT(WINAPI*)(PHANDLE);
  using LoadFn = HRESULT(WINAPI*)(HANDLE, const UCHAR*, SIZE_T);
  using ExecFn = HRESULT(WINAPI*)(HANDLE, PCSTR, const ULONG64*, SIZE_T,
                                  PULONG64, SIZE_T, PSIZE_T);
  using CloseFn = HRESULT(WINAPI*)(HANDLE);

  HMODULE lib_ = nullptr;
  HANDLE handle_ = nullptr;
  OpenFn open_ = nullptr;
  LoadFn load_ = nullptr;
  ExecFn exec_ = nullptr;
  CloseFn close_ = nullptr;
};

inline bool QueryElevated() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
  TOKEN_ELEVATION e{};
  DWORD len = 0;
  const bool ok =
      GetTokenInformation(token, TokenElevation, &e, sizeof(e), &len) &&
      e.TokenIsElevated;
  CloseHandle(token);
  return ok;
}

inline bool IsElevated() {
  static const bool elevated = QueryElevated();
  return elevated;
}

}  // namespace oc

#endif  // RUNNER_PAWNIO_H_
