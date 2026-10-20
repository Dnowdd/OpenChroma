"""Copies the parts of an OpenRGB source tree that OpenChroma builds into
third_party/openrgb, replacing what is there.

Usage: python scripts/update-openrgb.py <path to an OpenRGB checkout> <commit>

Only the device drivers and the framework they need are copied: no Qt user
interface, no packaging, no other operating systems' prebuilt libraries. Our
changes to the copied files are in PATCHES below and are applied after
copying; each is marked with an "OpenChroma:" comment in the code.
"""
import shutil
import sys
from pathlib import Path

src = Path(sys.argv[1]).resolve()
commit = sys.argv[2]
dst = Path(__file__).resolve().parent.parent / 'third_party' / 'openrgb'

ROOT_FILES = [
    'LICENSE', 'README.md', 'CONTRIBUTING.md',
    'Colors.h', 'fair_mutex.h', 'filesystem.h',
    'DetectionManager.cpp', 'DetectionManager.h',
    'JsonUtils.cpp', 'JsonUtils.h',
    'LogManager.cpp', 'LogManager.h',
    'MathUtils.cpp', 'MathUtils.h',
    'NetworkClient.cpp', 'NetworkClient.h',
    'NetworkProtocol.cpp', 'NetworkProtocol.h',
    'NetworkServer.cpp', 'NetworkServer.h',
    'OpenRGBPluginInterface.h', 'PluginManagerInterface.h',
    'ProfileManager.cpp', 'ProfileManager.h',
    'ResourceManager.cpp', 'ResourceManager.h', 'ResourceManagerCallback.h',
    'SettingsManager.cpp', 'SettingsManager.h',
    'StringUtils.cpp', 'StringUtils.h',
    'cli.cpp', 'cli.h',
    # Color helpers some drivers use; they live in the Qt folder but do not
    # use Qt.
    'qt/hsv.cpp', 'qt/hsv.h',
]
DIRS = [
    'AutoStart', 'Controllers', 'KeyboardLayoutManager', 'RGBController',
    'SPDAccessor', 'dmiinfo', 'hidapi_wrapper', 'i2c_smbus',
    'i2c_tools', 'interop', 'net_port', 'pci_ids', 'scsiapi', 'serial_port',
    'super_io', 'wmi',
    'dependencies/CRCpp', 'dependencies/NVFC', 'dependencies/PawnIO',
    'dependencies/display-library', 'dependencies/json',
    'dependencies/stb',
    'dependencies/hidapi-hotplug-win/include', 'dependencies/hidapi-hotplug-win/x64',
    'dependencies/libusb-1.0.27/include', 'dependencies/libusb-1.0.27/VS2019/MS64/dll',
]
# Pieces that need Qt or network libraries we do not ship, and the E1.31
# driver, whose libe131 is Apache-2.0 (not compatible with GPL-2.0-only).
SKIP = ['Controllers/QMKController', 'Controllers/PhilipsHueController',
        'Controllers/NanoleafController', 'Controllers/E131Controller']

def empty(folder):
    """Deletes what is inside [folder]; folders that are open in a shell
    (and so cannot be deleted) are emptied and kept."""
    for child in folder.iterdir():
        if child.is_dir():
            try:
                shutil.rmtree(child)
            except PermissionError:
                empty(child)
        else:
            child.unlink()


dst.mkdir(parents=True, exist_ok=True)
empty(dst)
for f in ROOT_FILES:
    (dst / f).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / f, dst / f)
def other_os(directory, names):
    """Files for other systems only; '_Windows_Linux' files are kept."""
    def other(n):
        low = n.lower()
        return (any(t in low for t in ('linux', 'macos', 'freebsd', 'flatpak'))
                and 'windows' not in low)
    return [n for n in names if n.endswith('.pdb') or other(n)]


for d in DIRS:
    shutil.copytree(src / d, dst / d, ignore=other_os, dirs_exist_ok=True)
for s in SKIP:
    shutil.rmtree(dst / s, ignore_errors=True)
for lic in ['LICENSE', 'COPYING', 'LICENSE.txt', 'COPYING.txt', 'README.txt']:
    p = src / 'dependencies/libusb-1.0.27' / lic
    if p.exists():
        shutil.copy2(p, dst / 'dependencies/libusb-1.0.27' / lic)
PATCHES = [
    ('ResourceManager.cpp',
     'void ResourceManager::SetupConfigurationDirectory()\n'
     '{\n'
     '    config_dir.clear();\n',
     '/*---------------------------------------------------------*\\\n'
     '| OpenChroma: the host app picks the settings folder before |\n'
     '| the first ResourceManager::get(), so a separate OpenRGB   |\n'
     "| installation's settings are never read or changed.        |\n"
     '\\*---------------------------------------------------------*/\n'
     'filesystem::path openchroma_config_dir;\n'
     '\n'
     'void ResourceManager::SetupConfigurationDirectory()\n'
     '{\n'
     '    config_dir.clear();\n'
     '    if(!openchroma_config_dir.empty())\n'
     '    {\n'
     '        config_dir = openchroma_config_dir;\n'
     '        filesystem::create_directories(config_dir);\n'
     '        return;\n'
     '    }\n'),
    # Upstream includes a .cpp that is also compiled on its own, which
    # defines its functions twice when linking.
    ('Controllers/SinowealthController/SinowealthControllerDetect.cpp',
     '#include "GenesisXenon200Controller.cpp"\n',
     '#include "GenesisXenon200Controller.h" // OpenChroma: was the .cpp\n'),
    # Inside OpenChroma, COM security is already set up for the process
    # (WebView2), so CoInitializeSecurity returns RPC_E_TOO_LATE; that is
    # fine for the WMI queries, which otherwise all fail (no board name).
    ('wmi/wmi.cpp',
     '    if (FAILED(hres))\n'
     '    {\n'
     '        CoUninitialize();\n'
     '        return hres;\n'
     '    }\n'
     '\n'
     '    // Obtain the initial locator to WMI',
     '    if (FAILED(hres) && hres != RPC_E_TOO_LATE) // OpenChroma: already set\n'
     '    {\n'
     '        CoUninitialize();\n'
     '        return hres;\n'
     '    }\n'
     '\n'
     '    // Obtain the initial locator to WMI'),
    # Upstream connects to WMI from a static initializer. In a DLL that runs
    # on the loading thread (Flutter's), and the COM objects it creates
    # cannot be used from the detection thread, so every query failed.
    # Connect on first use instead, on the thread that queries.
    ('wmi/wmi.cpp',
     'HRESULT WmiInit = Wmi::init();\n',
     'HRESULT WmiInit = S_OK; // OpenChroma: connected on first query\n'),
    ('wmi/wmi.cpp',
     '    if (pSvc == nullptr)\n'
     '    {\n'
     '        return E_FAIL;\n'
     '    }\n',
     '    if (pSvc == nullptr && FAILED(init())) // OpenChroma: lazy init\n'
     '    {\n'
     '        return E_FAIL;\n'
     '    }\n'),
    # Each query reconnects without setting the proxy security again, which
    # upstream gets away with through process-wide COM security that, in
    # OpenChroma, belongs to WebView2. Set it on the new proxy and on the
    # enumerator, or WMI answers with nothing.
    ('wmi/wmi.cpp',
     '    );\n'
     '\n'
     '    // Make the WMI query\n'
     '    hres = pSvc->ExecQuery(\n'
     '        bstr_t("WQL"),\n'
     '        bstr_t(queryStr.c_str()),\n'
     '        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,\n'
     '        nullptr,\n'
     '        &pEnumerator\n'
     '    );\n'
     '\n'
     '    if (FAILED(hres))\n'
     '    {\n'
     '        return hres;\n'
     '    }\n',
     '    );\n'
     '    if (FAILED(hres) || pSvc == nullptr)\n'
     '    {\n'
     '        return FAILED(hres) ? hres : E_FAIL;\n'
     '    }\n'
     '    // OpenChroma: proxy security for the new connection\n'
     '    CoSetProxyBlanket(pSvc, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, nullptr,\n'
     '                      RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,\n'
     '                      nullptr, EOAC_NONE);\n'
     '\n'
     '    // Make the WMI query\n'
     '    hres = pSvc->ExecQuery(\n'
     '        bstr_t("WQL"),\n'
     '        bstr_t(queryStr.c_str()),\n'
     '        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,\n'
     '        nullptr,\n'
     '        &pEnumerator\n'
     '    );\n'
     '\n'
     '    if (FAILED(hres))\n'
     '    {\n'
     '        return hres;\n'
     '    }\n'
     '    // OpenChroma: and for the enumerator it returned\n'
     '    CoSetProxyBlanket(pEnumerator, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE,\n'
     '                      nullptr, RPC_C_AUTHN_LEVEL_CALL,\n'
     '                      RPC_C_IMP_LEVEL_IMPERSONATE, nullptr, EOAC_NONE);\n'),
    # Devices an OpenChroma plugin drives are claimed by VID:PID before
    # detection; OpenRGB's detectors then leave them alone, so two drivers
    # never talk to the same device.
    ('DetectionManager.cpp',
     'bool BasicHIDBlock::compare(hid_device_info* info)\n'
     '{\n',
     '/* OpenChroma: (vid << 16 | pid) of devices OpenChroma plugins drive. */\n'
     'std::set<unsigned int> openchroma_claimed_hid;\n'
     '\n'
     'bool BasicHIDBlock::compare(hid_device_info* info)\n'
     '{\n'
     '    if(openchroma_claimed_hid.count(((unsigned int)info->vendor_id << 16) | info->product_id))\n'
     '    {\n'
     '        return(false);\n'
     '    }\n'),
    ('DetectionManager.h',
     'class DetectionManager\n',
     '#include <set>\n'
     '/* OpenChroma: devices claimed by OpenChroma plugins (see BasicHIDBlock). */\n'
     'extern std::set<unsigned int> openchroma_claimed_hid;\n'
     '\n'
     'class DetectionManager\n'),
    ('ResourceManager.h',
     'class ResourceManager',
     '/* OpenChroma: settings folder chosen by the host app. */\n'
     'extern filesystem::path openchroma_config_dir;\n'
     '\n'
     'class ResourceManager'),
]
for name, old, new in PATCHES:
    path = dst / name
    text = path.read_bytes().decode('utf-8')
    crlf = '\r\n' in text
    if crlf:
        text = text.replace('\r\n', '\n')
    if old not in text:
        raise SystemExit(f'patch for {name} no longer applies; update PATCHES')
    text = text.replace(old, new, 1)
    if crlf:
        text = text.replace('\n', '\r\n')
    path.write_bytes(text.encode('utf-8'))

(dst / 'UPSTREAM_COMMIT').write_text(commit + '\n')
print('copied OpenRGB', commit, 'to', dst)
