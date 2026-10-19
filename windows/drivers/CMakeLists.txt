# oc_drivers.dll: the device drivers, built from the OpenRGB sources in
# third_party/openrgb plus OpenChroma's C API (oc_drivers.cpp).
# GPL-2.0-or-later, like the code it is built from.
cmake_minimum_required(VERSION 3.14)

set(ORGB "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/openrgb")
set(ORGB_DEPS "${ORGB}/dependencies")

# Every driver; the vendored tree only holds the Windows-capable ones.
file(GLOB_RECURSE ORGB_CONTROLLER_SOURCES CONFIGURE_DEPENDS
  "${ORGB}/Controllers/*.cpp")
file(GLOB_RECURSE ORGB_CONTROLLER_HEADERS CONFIGURE_DEPENDS
  "${ORGB}/Controllers/*.h")
set(ORGB_CONTROLLER_INCLUDES "")
foreach(header ${ORGB_CONTROLLER_HEADERS})
  get_filename_component(dir "${header}" DIRECTORY)
  list(APPEND ORGB_CONTROLLER_INCLUDES "${dir}")
endforeach()
list(REMOVE_DUPLICATES ORGB_CONTROLLER_INCLUDES)

set(ORGB_CORE_SOURCES
  cli.cpp
  DetectionManager.cpp
  JsonUtils.cpp
  LogManager.cpp
  MathUtils.cpp
  NetworkClient.cpp
  NetworkProtocol.cpp
  NetworkServer.cpp
  ProfileManager.cpp
  ResourceManager.cpp
  SettingsManager.cpp
  StringUtils.cpp
  AutoStart/AutoStart.cpp
  AutoStart/AutoStart-Windows.cpp
  KeyboardLayoutManager/KeyboardLayoutManager.cpp
  RGBController/RGBController.cpp
  RGBController/RGBController_Dummy.cpp
  RGBController/RGBControllerKeyNames.cpp
  RGBController/RGBController_Network.cpp
  RGBController/RGBController_Virtual.cpp
  SPDAccessor/DDR4DirectAccessor.cpp
  SPDAccessor/DDR5DirectAccessor.cpp
  SPDAccessor/SPDAccessor.cpp
  SPDAccessor/SPDDetector.cpp
  SPDAccessor/SPDWrapper.cpp
  dmiinfo/dmiinfo.cpp
  i2c_smbus/i2c_smbus.cpp
  i2c_smbus/Windows/i2c_smbus_amdadl.cpp
  i2c_smbus/Windows/i2c_smbus_nvapi.cpp
  i2c_smbus/Windows/i2c_smbus_pawnio.cpp
  i2c_tools/i2c_tools.cpp
  interop/DeviceGuard.cpp
  interop/DeviceGuardLock.cpp
  interop/DeviceGuardManager.cpp
  net_port/net_port.cpp
  scsiapi/scsiapi_windows.c
  serial_port/serial_port.cpp
  serial_port/find_usb_serial_port_win.cpp
  super_io/super_io_pawnio.cpp
  wmi/wmi.cpp
  dependencies/NVFC/nvapi.cpp
  qt/hsv.cpp
)
list(TRANSFORM ORGB_CORE_SOURCES PREPEND "${ORGB}/")

add_library(oc_drivers SHARED
  oc_drivers.cpp
  ${ORGB_CORE_SOURCES}
  ${ORGB_CONTROLLER_SOURCES}
)

target_include_directories(oc_drivers PRIVATE
  "${ORGB}"
  ${ORGB_CONTROLLER_INCLUDES}
  "${ORGB}/AutoStart"
  "${ORGB}/KeyboardLayoutManager"
  "${ORGB}/RGBController"
  "${ORGB}/SPDAccessor"
  "${ORGB}/qt"
  "${ORGB}/dmiinfo"
  "${ORGB}/hidapi_wrapper"
  "${ORGB}/i2c_smbus"
  "${ORGB}/i2c_smbus/Windows"
  "${ORGB}/i2c_tools"
  "${ORGB}/interop"
  "${ORGB}/net_port"
  "${ORGB}/pci_ids"
  "${ORGB}/scsiapi"
  "${ORGB}/serial_port"
  "${ORGB}/super_io"
  "${ORGB}/wmi"
  "${ORGB_DEPS}/CRCpp"
  "${ORGB_DEPS}/NVFC"
  "${ORGB_DEPS}/PawnIO"
  "${ORGB_DEPS}/display-library/include"
  "${ORGB_DEPS}/hidapi-hotplug-win/include"
  "${ORGB_DEPS}/json"
  "${ORGB_DEPS}/libusb-1.0.27/include"
  "${ORGB_DEPS}/stb"
)

target_compile_features(oc_drivers PRIVATE cxx_std_17)
# OpenRGB builds as a multi-byte (non-Unicode) app; the Flutter runner's
# global UNICODE definitions must not reach it.
target_compile_options(oc_drivers PRIVATE /utf-8 /EHsc /bigobj /MP /W0
  /UUNICODE /U_UNICODE)
target_compile_definitions(oc_drivers PRIVATE
  _MBCS WIN32 _CRT_SECURE_NO_WARNINGS _WINSOCK_DEPRECATED_NO_WARNINGS
  WIN32_LEAN_AND_MEAN HID_HOTPLUG_ENABLED=1 NOMINMAX
  VERSION_STRING="OpenChroma"
  BUILDDATE_STRING=""
  GIT_COMMIT_ID=""
  GIT_COMMIT_DATE=""
  GIT_BRANCH=""
)
# The release build of ~900 files is slow; optimize for size, it is all I/O.
target_compile_options(oc_drivers PRIVATE "$<$<CONFIG:Release>:/O1>")

target_link_libraries(oc_drivers PRIVATE
  ws2_32 iphlpapi setupapi hid wbemuuid ole32 oleaut32 advapi32 user32
  "${ORGB_DEPS}/hidapi-hotplug-win/x64/hidapi-hotplug.lib"
  "${ORGB_DEPS}/libusb-1.0.27/VS2019/MS64/dll/libusb-1.0.lib"
  "${ORGB_DEPS}/PawnIO/PawnIOLib.lib"
)

# DLLs oc_drivers.dll loads, and the PawnIO modules the SMBus drivers use.
set(OC_DRIVERS_RUNTIME
  "${ORGB_DEPS}/hidapi-hotplug-win/x64/hidapi-hotplug.dll"
  "${ORGB_DEPS}/libusb-1.0.27/VS2019/MS64/dll/libusb-1.0.dll"
  "${ORGB_DEPS}/PawnIO/PawnIOLib.dll"
  PARENT_SCOPE
)
set(OC_DRIVERS_PAWNIO_MODULES "${ORGB_DEPS}/PawnIO/modules" PARENT_SCOPE)
