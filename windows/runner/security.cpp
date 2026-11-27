// Security helpers exposed to Dart (DynamicLibrary.executable()): whether
// the install can be trusted to run elevated at logon, the elevated logon
// task itself (registered in-process through the Task Scheduler API), the
// owner of a file, and the company of a driver under System32\drivers.
#include "security.h"

#include <windows.h>
#include <aclapi.h>
#include <bcrypt.h>
#include <sddl.h>
#include <taskschd.h>

#include <cstdint>
#include <cwchar>
#include <string>
#include <vector>

extern "C" int OcIsElevated();

namespace {

constexpr wchar_t kTaskName[] = L"OpenChroma";
constexpr size_t kMaxEntries = 100000;

constexpr DWORD kFileWrite = FILE_WRITE_DATA | FILE_APPEND_DATA | DELETE |
                             WRITE_DAC | WRITE_OWNER | GENERIC_WRITE |
                             GENERIC_ALL;
constexpr DWORD kDirWrite = kFileWrite | FILE_DELETE_CHILD;
constexpr DWORD kAncestorWrite =
    FILE_DELETE_CHILD | DELETE | WRITE_DAC | WRITE_OWNER | GENERIC_WRITE |
    GENERIC_ALL;

struct SidBuffer {
  BYTE bytes[SECURITY_MAX_SID_SIZE];
  PSID get() { return bytes; }
};

class TrustedSids {
 public:
  TrustedSids() {
    DWORD size = SECURITY_MAX_SID_SIZE;
    ok_ = CreateWellKnownSid(WinLocalSystemSid, nullptr, system_.get(), &size);
    size = SECURITY_MAX_SID_SIZE;
    ok_ = ok_ && CreateWellKnownSid(WinBuiltinAdministratorsSid, nullptr,
                                    admins_.get(), &size);
    ok_ = ok_ && ConvertStringSidToSidW(
                     L"S-1-5-80-956008885-3418522649-1831038044-1853292631-"
                     L"2271478464",
                     &installer_);
  }
  ~TrustedSids() {
    if (installer_) LocalFree(installer_);
  }
  TrustedSids(const TrustedSids&) = delete;
  TrustedSids& operator=(const TrustedSids&) = delete;

  bool ok() const { return ok_; }

  bool Contains(PSID sid) {
    return sid && (EqualSid(sid, system_.get()) || EqualSid(sid, admins_.get()) ||
                   EqualSid(sid, installer_));
  }

 private:
  SidBuffer system_{};
  SidBuffer admins_{};
  PSID installer_ = nullptr;
  bool ok_ = false;
};

class SecurityInfo {
 public:
  explicit SecurityInfo(const std::wstring& path, SECURITY_INFORMATION what) {
    status_ = GetNamedSecurityInfoW(path.c_str(), SE_FILE_OBJECT, what, &owner,
                                    nullptr, &dacl, nullptr, &descriptor_);
  }
  ~SecurityInfo() {
    if (descriptor_) LocalFree(descriptor_);
  }
  SecurityInfo(const SecurityInfo&) = delete;
  SecurityInfo& operator=(const SecurityInfo&) = delete;

  bool ok() const { return status_ == ERROR_SUCCESS; }

  PSID owner = nullptr;
  PACL dacl = nullptr;

 private:
  DWORD status_ = ERROR_GEN_FAILURE;
  PSECURITY_DESCRIPTOR descriptor_ = nullptr;
};

bool OnlyTrustedCanWrite(const std::wstring& path, DWORD bad_mask,
                         TrustedSids& trusted) {
  SecurityInfo info(path, OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION);
  if (!info.ok() || !trusted.Contains(info.owner) || !info.dacl) return false;
  for (DWORD i = 0; i < info.dacl->AceCount; i++) {
    void* ace = nullptr;
    if (!GetAce(info.dacl, i, &ace) || !ace) return false;
    const auto* header = static_cast<ACE_HEADER*>(ace);
    if (header->AceType != ACCESS_ALLOWED_ACE_TYPE &&
        header->AceType != ACCESS_ALLOWED_CALLBACK_ACE_TYPE) {
      continue;
    }
    if (header->AceFlags & INHERIT_ONLY_ACE) continue;
    auto* allowed = static_cast<ACCESS_ALLOWED_ACE*>(ace);
    if (!(allowed->Mask & bad_mask)) continue;
    if (!trusted.Contains(reinterpret_cast<PSID>(&allowed->SidStart))) return false;
  }
  return true;
}

bool TreeIsTrusted(const std::wstring& dir, TrustedSids& trusted,
                   size_t* entries) {
  if (!OnlyTrustedCanWrite(dir, kDirWrite, trusted)) return false;
  WIN32_FIND_DATAW data;
  HANDLE find = FindFirstFileExW((dir + L"\\*").c_str(), FindExInfoBasic, &data,
                                 FindExSearchNameMatch, nullptr, 0);
  if (find == INVALID_HANDLE_VALUE) return false;
  bool ok = true;
  do {
    if (!wcscmp(data.cFileName, L".") || !wcscmp(data.cFileName, L"..")) continue;
    if (++*entries > kMaxEntries ||
        (data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
      ok = false;
      break;
    }
    const std::wstring path = dir + L"\\" + data.cFileName;
    if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      ok = TreeIsTrusted(path, trusted, entries);
    } else {
      ok = OnlyTrustedCanWrite(path, kFileWrite, trusted);
    }
  } while (ok && FindNextFileW(find, &data));
  FindClose(find);
  return ok;
}

bool ExecutablePath(std::wstring* out) {
  wchar_t module[MAX_PATH];
  const DWORD n = GetModuleFileNameW(nullptr, module, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) return false;
  HANDLE file = CreateFileW(module, 0,
                            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                            nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS,
                            nullptr);
  if (file == INVALID_HANDLE_VALUE) return false;
  std::wstring final_path(32768, L'\0');
  const DWORD len = GetFinalPathNameByHandleW(
      file, final_path.data(), static_cast<DWORD>(final_path.size()),
      FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
  CloseHandle(file);
  if (len == 0 || len >= final_path.size()) return false;
  final_path.resize(len);
  if (final_path.rfind(L"\\\\?\\", 0) != 0 ||
      final_path.rfind(L"\\\\?\\UNC\\", 0) == 0) {
    return false;
  }
  *out = final_path.substr(4);
  return true;
}

bool InstallIsSecure() {
  TrustedSids trusted;
  if (!trusted.ok()) return false;
  std::wstring exe;
  if (!ExecutablePath(&exe)) return false;
  const size_t slash = exe.find_last_of(L'\\');
  if (slash == std::wstring::npos || slash < 3) return false;
  const std::wstring app_dir = exe.substr(0, slash);
  size_t entries = 0;
  if (!TreeIsTrusted(app_dir, trusted, &entries)) return false;
  std::wstring dir = app_dir;
  for (;;) {
    const size_t cut = dir.find_last_of(L'\\');
    if (cut == std::wstring::npos) break;
    dir = dir.substr(0, cut);
    const bool volume_root = dir.size() == 2;
    if (!OnlyTrustedCanWrite(volume_root ? dir + L"\\" : dir, kAncestorWrite,
                             trusted)) {
      return false;
    }
    if (volume_root) break;
  }
  return true;
}

std::wstring XmlEscape(const std::wstring& s) {
  std::wstring out;
  for (const wchar_t c : s) {
    switch (c) {
      case L'&': out += L"&amp;"; break;
      case L'<': out += L"&lt;"; break;
      case L'>': out += L"&gt;"; break;
      case L'"': out += L"&quot;"; break;
      case L'\'': out += L"&apos;"; break;
      default: out += c;
    }
  }
  return out;
}

bool CurrentUserName(std::wstring* out) {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
  DWORD size = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  std::vector<BYTE> buffer(size);
  bool ok = size && GetTokenInformation(token, TokenUser, buffer.data(), size, &size);
  CloseHandle(token);
  if (!ok) return false;
  wchar_t name[256], domain[256];
  DWORD name_len = 256, domain_len = 256;
  SID_NAME_USE use;
  if (!LookupAccountSidW(nullptr, reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid,
                         name, &name_len, domain, &domain_len, &use)) {
    return false;
  }
  *out = std::wstring(domain) + L"\\" + name;
  return true;
}

std::wstring TaskXml(const std::wstring& description, const std::wstring& exe,
                     const std::wstring& dir, const std::wstring& user) {
  return L"<?xml version=\"1.0\" encoding=\"UTF-16\"?>\n"
         L"<Task version=\"1.2\" "
         L"xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">\n"
         L"  <RegistrationInfo>\n    <Description>" +
         XmlEscape(description) +
         L"</Description>\n  </RegistrationInfo>\n"
         L"  <Triggers>\n    <LogonTrigger>\n      <Enabled>true</Enabled>\n"
         L"      <UserId>" +
         XmlEscape(user) +
         L"</UserId>\n    </LogonTrigger>\n  </Triggers>\n"
         L"  <Principals>\n    <Principal id=\"Author\">\n      <UserId>" +
         XmlEscape(user) +
         L"</UserId>\n      <LogonType>InteractiveToken</LogonType>\n"
         L"      <RunLevel>HighestAvailable</RunLevel>\n    </Principal>\n"
         L"  </Principals>\n"
         L"  <Settings>\n"
         L"    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>\n"
         L"    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>\n"
         L"    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>\n"
         L"    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>\n"
         L"    <Priority>4</Priority>\n  </Settings>\n"
         L"  <Actions Context=\"Author\">\n    <Exec>\n      <Command>" +
         XmlEscape(exe) +
         L"</Command>\n      <Arguments>--hidden</Arguments>\n"
         L"      <WorkingDirectory>" +
         XmlEscape(dir) + L"</WorkingDirectory>\n    </Exec>\n  </Actions>\n</Task>\n";
}

class Com {
 public:
  Com() {
    const HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    uninitialize_ = SUCCEEDED(hr);
    ok_ = uninitialize_ || hr == RPC_E_CHANGED_MODE;
  }
  ~Com() {
    if (uninitialize_) CoUninitialize();
  }
  Com(const Com&) = delete;
  Com& operator=(const Com&) = delete;
  bool ok() const { return ok_; }

 private:
  bool uninitialize_ = false;
  bool ok_ = false;
};

template <typename T>
class Ptr {
 public:
  Ptr() = default;
  ~Ptr() {
    if (p_) p_->Release();
  }
  Ptr(const Ptr&) = delete;
  Ptr& operator=(const Ptr&) = delete;
  T** out() { return &p_; }
  T* operator->() const { return p_; }
  explicit operator bool() const { return p_ != nullptr; }

 private:
  T* p_ = nullptr;
};

class Bstr {
 public:
  explicit Bstr(const wchar_t* s) : s_(SysAllocString(s)) {}
  ~Bstr() { SysFreeString(s_); }
  Bstr(const Bstr&) = delete;
  Bstr& operator=(const Bstr&) = delete;
  operator BSTR() const { return s_; }

 private:
  BSTR s_;
};

bool OpenRootFolder(Ptr<ITaskService>& service, Ptr<ITaskFolder>& folder) {
  if (FAILED(CoCreateInstance(CLSID_TaskScheduler, nullptr, CLSCTX_INPROC_SERVER,
                              IID_ITaskService,
                              reinterpret_cast<void**>(service.out())))) {
    return false;
  }
  VARIANT empty;
  VariantInit(&empty);
  if (FAILED(service->Connect(empty, empty, empty, empty))) return false;
  Bstr root(L"\\");
  return SUCCEEDED(service->GetFolder(root, folder.out()));
}

}  // namespace

namespace oc {

std::wstring RandomHex(size_t bytes) {
  std::vector<uint8_t> raw(bytes);
  if (!BCRYPT_SUCCESS(BCryptGenRandom(nullptr, raw.data(),
                                      static_cast<ULONG>(raw.size()),
                                      BCRYPT_USE_SYSTEM_PREFERRED_RNG))) {
    LARGE_INTEGER t;
    QueryPerformanceCounter(&t);
    for (size_t i = 0; i < raw.size(); i++) {
      raw[i] = static_cast<uint8_t>(t.QuadPart >> (8 * (i % 8))) ^
               static_cast<uint8_t>(GetCurrentProcessId() + i * 31);
    }
  }
  static const wchar_t digits[] = L"0123456789abcdef";
  std::wstring out;
  for (const uint8_t b : raw) {
    out += digits[b >> 4];
    out += digits[b & 15];
  }
  return out;
}

}  // namespace oc

extern "C" {

__declspec(dllexport) int OcSystemDirectory(wchar_t* buf, int cap) {
  if (!buf || cap <= 0) return 0;
  const UINT n = GetSystemDirectoryW(buf, static_cast<UINT>(cap));
  return n >= static_cast<UINT>(cap) ? 0 : static_cast<int>(n);
}

__declspec(dllexport) int OcWindowsDirectory(wchar_t* buf, int cap) {
  if (!buf || cap <= 0) return 0;
  const UINT n = GetSystemWindowsDirectoryW(buf, static_cast<UINT>(cap));
  return n >= static_cast<UINT>(cap) ? 0 : static_cast<int>(n);
}

__declspec(dllexport) int OcInstallSecure() { return InstallIsSecure() ? 1 : 0; }

__declspec(dllexport) int OcFileOwnerTrusted(const wchar_t* path) {
  if (!path) return 0;
  TrustedSids trusted;
  if (!trusted.ok()) return 0;
  SecurityInfo info(path, OWNER_SECURITY_INFORMATION);
  return info.ok() && trusted.Contains(info.owner) ? 1 : 0;
}

__declspec(dllexport) int OcDriverCompany(const wchar_t* name, wchar_t* out,
                                          int cap) {
  if (!name || !out || cap <= 0) return -1;
  const size_t length = wcslen(name);
  if (length == 0 || length > 64 || name[0] == L'.' || name[0] == L'-') return -1;
  for (size_t i = 0; i < length; i++) {
    const wchar_t c = name[i];
    const bool ok = (c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z') ||
                    (c >= L'0' && c <= L'9') || c == L'_' || c == L'.' || c == L'-';
    if (!ok) return -1;
  }
  wchar_t system[MAX_PATH];
  const UINT n = GetSystemDirectoryW(system, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) return -1;
  const std::wstring path = std::wstring(system) + L"\\drivers\\" + name;
  DWORD handle = 0;
  const DWORD size = GetFileVersionInfoSizeW(path.c_str(), &handle);
  if (size == 0) return -1;
  std::vector<BYTE> data(size);
  if (!GetFileVersionInfoW(path.c_str(), 0, size, data.data())) return -1;
  struct Translation {
    WORD language;
    WORD code_page;
  };
  Translation* translations = nullptr;
  UINT bytes = 0;
  if (!VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation",
                      reinterpret_cast<void**>(&translations), &bytes)) {
    return -1;
  }
  for (UINT i = 0; i < bytes / sizeof(Translation); i++) {
    wchar_t query[64];
    swprintf_s(query, L"\\StringFileInfo\\%04x%04x\\CompanyName",
               translations[i].language, translations[i].code_page);
    wchar_t* company = nullptr;
    UINT chars = 0;
    if (VerQueryValueW(data.data(), query, reinterpret_cast<void**>(&company),
                       &chars) &&
        company && chars > 0) {
      const size_t len = wcsnlen(company, chars);
      if (len >= static_cast<size_t>(cap)) return -1;
      wmemcpy(out, company, len);
      out[len] = L'\0';
      return static_cast<int>(len);
    }
  }
  return -1;
}

__declspec(dllexport) int OcStartupTaskExists() {
  Com com;
  if (!com.ok()) return 0;
  Ptr<ITaskService> service;
  Ptr<ITaskFolder> folder;
  if (!OpenRootFolder(service, folder)) return 0;
  Ptr<IRegisteredTask> task;
  Bstr name(kTaskName);
  return SUCCEEDED(folder->GetTask(name, task.out())) ? 1 : 0;
}

// 0 registered, 1 needs an elevated process, 2 install not trusted, 3 failed.
__declspec(dllexport) int OcStartupTaskRegister(const wchar_t* description) {
  if (!OcIsElevated()) return 1;
  if (!InstallIsSecure()) return 2;
  std::wstring exe, user;
  if (!ExecutablePath(&exe) || !CurrentUserName(&user)) return 3;
  const std::wstring dir = exe.substr(0, exe.find_last_of(L'\\'));
  const std::wstring xml = TaskXml(description ? description : L"", exe, dir, user);
  Com com;
  if (!com.ok()) return 3;
  Ptr<ITaskService> service;
  Ptr<ITaskFolder> folder;
  if (!OpenRootFolder(service, folder)) return 3;
  Bstr name(kTaskName);
  Bstr body(xml.c_str());
  VARIANT empty;
  VariantInit(&empty);
  Ptr<IRegisteredTask> task;
  const HRESULT hr =
      folder->RegisterTask(name, body, TASK_CREATE_OR_UPDATE, empty, empty,
                           TASK_LOGON_INTERACTIVE_TOKEN, empty, task.out());
  return SUCCEEDED(hr) ? 0 : 3;
}

// 0 removed (or there was none), 1 needs an elevated process, 3 failed.
__declspec(dllexport) int OcStartupTaskDelete() {
  if (!OcIsElevated()) return 1;
  Com com;
  if (!com.ok()) return 3;
  Ptr<ITaskService> service;
  Ptr<ITaskFolder> folder;
  if (!OpenRootFolder(service, folder)) return 3;
  Bstr name(kTaskName);
  const HRESULT hr = folder->DeleteTask(name, 0);
  return SUCCEEDED(hr) || hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) ? 0 : 3;
}

}  // extern "C"
