#ifndef RUNNER_SECURITY_H_
#define RUNNER_SECURITY_H_

#include <windows.h>
#include <shlobj.h>

#include <string>

namespace oc {

inline std::wstring ProgramFilesDir() {
  PWSTR path = nullptr;
  std::wstring s;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_ProgramFiles, 0, nullptr, &path))) {
    s = path;
  }
  CoTaskMemFree(path);
  return s;
}

std::wstring RandomHex(size_t bytes);

}  // namespace oc

#endif  // RUNNER_SECURITY_H_
