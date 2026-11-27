// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutSection => 'About';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String aboutUpdateBanner(String version) {
    return 'OpenChroma $version is available.';
  }

  @override
  String get aboutChecking => 'Checking for updates…';

  @override
  String get aboutDevBuild => 'Development build: update checks are off.';

  @override
  String get aboutUpToDate => 'You\'re up to date.';

  @override
  String get aboutDownload => 'Download';

  @override
  String get aboutCheckNow => 'Check now';

  @override
  String get aboutDismiss => 'Dismiss';

  @override
  String get aboutAutoCheck => 'Check for updates automatically';

  @override
  String get aboutAutoCheckDescription =>
      'Once a day, OpenChroma asks GitHub for the latest release. Nothing about your PC is sent.';

  @override
  String get aboutReportProblem => 'Report a problem';

  @override
  String get aboutReportProblemDescription =>
      'Copy a diagnostics summary (app and Windows version, devices and errors; no serial numbers) and paste it into a GitHub issue.';

  @override
  String get aboutCopyDiagnostics => 'Copy diagnostics';

  @override
  String get aboutDiagnosticsCopied => 'Diagnostics copied to the clipboard.';

  @override
  String get aboutOpenIssue => 'Open an issue';

  @override
  String get fansTitle => 'Fans';

  @override
  String get fansProfileSilent => 'Silent';

  @override
  String get fansProfileBalanced => 'Balanced';

  @override
  String get fansProfileTurbo => 'Turbo';

  @override
  String get fansProfileCustom => 'Custom';

  @override
  String get fansConnected => 'Connected';

  @override
  String get fansHideEmpty => 'Hide empty';

  @override
  String fansShowEmpty(int count) {
    return 'Show empty ($count)';
  }

  @override
  String fansConflictTitle(String program) {
    return '$program is open.';
  }

  @override
  String get fansConflictText =>
      'Two programs on the same fans fight over the speed. Close it, including from the tray, to control them here.';

  @override
  String get fansAdminTitle => 'Administrator mode';

  @override
  String get fansAdminText =>
      'is needed to control fans and see the motherboard ones.';

  @override
  String get fansRestartAsAdmin => 'Restart as administrator';

  @override
  String get fansInstallPawnIoTitle => 'Install PawnIO';

  @override
  String get fansInstallPawnIoText => 'to see the motherboard fans.';

  @override
  String get fansDownload => 'Download';

  @override
  String get fansBusyTitle => 'The motherboard was busy';

  @override
  String get fansBusyText =>
      'with another program. Reopen OpenChroma to try again.';

  @override
  String get fansPumpQuestionTitle => 'Have a water cooler?';

  @override
  String get fansPumpQuestionText =>
      'Tap the pump to protect it: it never drops below 70% or stops.';

  @override
  String get fansPumpNone => 'I don\'t have one';

  @override
  String get fansCurveTitle => 'Curve';

  @override
  String get fansCpuTempNeedsAdmin =>
      'CPU temperature needs administrator mode';

  @override
  String get fansSearching => 'Looking for fans…';

  @override
  String get fansNone => 'No fans';

  @override
  String get fansNoTempDriver => 'No temperature · driver in control';

  @override
  String get fansNoTempBios => 'No temperature · BIOS in control';

  @override
  String get fansModeAuto => 'Auto';

  @override
  String get fansModeCurve => 'Curve';

  @override
  String get fansModeFixed => 'Fixed';

  @override
  String fansMotherboardDevice(String device) {
    return 'Motherboard · $device';
  }

  @override
  String get fansStopWhenCold => 'Stop when cold';

  @override
  String get fansPumpToggle => 'Water cooler pump';

  @override
  String fansBlockedConflict(String program) {
    return '$program is open';
  }

  @override
  String get fansBlockedNeedsAdmin => 'Controlling needs administrator mode';

  @override
  String get fansBlockedReadOnly => 'Read-only';

  @override
  String fansDefaultName(int index) {
    return 'Fan $index';
  }

  @override
  String get effectsFilterAll => 'All';

  @override
  String get effectsFilterFavorites => 'Favorites';

  @override
  String get effectsFilterAudio => 'Sound-reactive';

  @override
  String get effectsFilterImported => 'Imported';

  @override
  String get effectsSearchHint => 'Search effects';

  @override
  String get effectsImport => 'Import';

  @override
  String get effectsEmptyFavoritesTitle => 'No favorites yet';

  @override
  String get effectsEmptyFavoritesMessage =>
      'Hover over an effect and click the star to keep it here.';

  @override
  String get effectsEmptyImportedTitle => 'No imported effects';

  @override
  String get effectsEmptyImportedMessage =>
      'Create an .ocfx effect or bring an .html file.';

  @override
  String get effectsImportEffect => 'Import effect';

  @override
  String get effectsNotFoundTitle => 'Nothing found';

  @override
  String get effectsNotFoundMessage => 'Try a different search term.';

  @override
  String get effectsReactsToSound => 'Reacts to sound';

  @override
  String get effectsRemoveFavorite => 'Remove from favorites';

  @override
  String get effectsAddFavorite => 'Add to favorites';

  @override
  String get effectsLive => 'Live';

  @override
  String get effectsRemoveImported => 'Remove imported effect';

  @override
  String effectsByAuthor(String author) {
    return 'by $author';
  }

  @override
  String get effectsAdjustments => 'Adjustments';

  @override
  String get effectsReset => 'Reset';

  @override
  String get effectsNoAdjustments => 'This effect has no adjustments.';

  @override
  String effectsRemoveTitle(String title) {
    return 'Remove \"$title\"?';
  }

  @override
  String get effectsRemoveMessage =>
      'The effect is removed from the library. The original file you imported is not deleted.';

  @override
  String get effectsCancel => 'Cancel';

  @override
  String get effectsRemove => 'Remove';

  @override
  String get effectsFileTypeEffects => 'Effects';

  @override
  String get effectsFileTypeOpenChroma => 'OpenChroma effect';

  @override
  String get effectsTemplateFileName => 'my-effect.ocfx';

  @override
  String get effectsTemplateName => 'My effect';

  @override
  String get effectsTemplateDescription => 'A short sentence about the effect.';

  @override
  String get effectsTemplateAuthor => 'Your name';

  @override
  String get effectsTemplateSpeed => 'Speed';

  @override
  String get effectsTemplateColor => 'Color';

  @override
  String effectsImportFailed(String error) {
    return 'Could not import: $error';
  }

  @override
  String get effectsImportIntro =>
      'Bring an .ocfx effect, OpenChroma\'s format, or an .html page that draws on a 320×200 canvas.';

  @override
  String get effectsFormatLayers => 'Layers';

  @override
  String get effectsFormatLayersText =>
      'gradient, spectrum, wave, pulse, sweep, rings, sparkle and solid, stacked with normal, screen, add, multiply or overlay blending.';

  @override
  String get effectsFormatParams => 'Parameters';

  @override
  String get effectsFormatParamsText =>
      'Declare them in \"params\" and use them as \"\$name\" in any layer. They become controls in the app.';

  @override
  String effectsTemplateSaved(String path) {
    return 'Template saved to $path';
  }

  @override
  String get effectsSaveTemplate => 'Save template';

  @override
  String get effectsChooseFile => 'Choose file';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLighting => 'Lighting';

  @override
  String get settingsBrightness => 'Brightness';

  @override
  String get settingsEffectAudio => 'Effect audio';

  @override
  String get settingsAudioUnavailable => 'Unavailable in this build.';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get settingsDevices => 'Devices';

  @override
  String settingsDevicesConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count connected',
      one: '1 connected',
    );
    return '$_temp0';
  }

  @override
  String get settingsScan => 'Scan';

  @override
  String get settingsEffects => 'Effects';

  @override
  String settingsEffectsInLibrary(int count) {
    return '$count in the library';
  }

  @override
  String get settingsImport => 'Import';

  @override
  String get settingsPlugins => 'Device plugins';

  @override
  String settingsPluginsLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loaded',
      one: '1 loaded',
    );
    return '$_temp0. New or changed .js files in the folder run only after you approve them.';
  }

  @override
  String get settingsReloadPlugins => 'Reload plugins';

  @override
  String get settingsOpenFolder => 'Open folder';

  @override
  String get settingsDataFolder => 'Data folder';

  @override
  String get settingsOpen => 'Open';

  @override
  String get settingsAlerts => 'Alerts';

  @override
  String get settingsWindowsNotifications => 'Windows notifications';

  @override
  String get settingsWindowsNotificationsDescription =>
      'Warns you when something gets too hot, memory or disk fills up, or the water cooler pump stops, even with the app in the tray.';

  @override
  String get settingsFlashLeds => 'Flash the LEDs red';

  @override
  String get settingsFlashLedsDescription =>
      'Devices flash for a few seconds along with the alert.';

  @override
  String get settingsAiAssistant => 'AI assistant';

  @override
  String get settingsAiKeyNote =>
      'The key stays only on this PC, encrypted for your Windows user, and is only sent to the chosen provider. When you ask something, the provider also receives your PC\'s readings: hardware model, temperatures, usage, device names and the names of the heaviest processes.';

  @override
  String get settingsStartup => 'Startup and permissions';

  @override
  String get settingsAdminMode => 'Administrator mode';

  @override
  String get settingsAdminActive =>
      'Active. CPU temperature shows up in Monitor.';

  @override
  String get settingsAdminInactive =>
      'Off. Required to read the CPU temperature.';

  @override
  String get settingsAdminAlreadyActive => 'Already active';

  @override
  String get settingsRestartAsAdmin => 'Restart as administrator';

  @override
  String get settingsAlwaysAdmin => 'Always open as administrator';

  @override
  String get settingsAlwaysAdminDescription =>
      'Windows asks for permission (UAC) every time OpenChroma opens.';

  @override
  String get settingsStartWithWindows => 'Open at PC startup';

  @override
  String get settingsStartWithWindowsAdminDescription =>
      'Opens in the tray, as administrator, when you sign in to Windows, without asking for permission. Turning it on or off asks for UAC once.';

  @override
  String get settingsStartWithWindowsDescription =>
      'Opens in the tray along with Windows.';

  @override
  String get settingsRunInBackground => 'Keep running in the background';

  @override
  String get settingsRunInBackgroundDescription =>
      'When you close the window, OpenChroma stays in the tray and keeps controlling lights and fans.';

  @override
  String get aiProviderCompatible => 'OpenAI-compatible';

  @override
  String get aiProvider => 'Provider';

  @override
  String get aiApiKey => 'API key';

  @override
  String get aiKeyHintAnthropic => 'Create one at console.anthropic.com.';

  @override
  String get aiKeyHintOpenai => 'Create one at platform.openai.com.';

  @override
  String get aiKeyHintCompatible =>
      'Optional for local servers (Ollama, LM Studio).';

  @override
  String get aiBaseUrl => 'API address';

  @override
  String get aiBaseUrlHint =>
      'E.g. https://openrouter.ai/api/v1, http://localhost:11434/v1 (Ollama).';

  @override
  String get aiModel => 'Model';

  @override
  String get aiModelsLoading => 'Fetching the available models…';

  @override
  String get aiModelsNeedKey => 'Enter the key to see the models.';

  @override
  String get aiModelsNone => 'No models found.';

  @override
  String aiModelsAvailable(int count) {
    return '$count available, updated automatically.';
  }

  @override
  String get aiRefreshList => 'Refresh list';

  @override
  String get aiPasteKey => 'Paste the key here';

  @override
  String get aiHide => 'Hide';

  @override
  String get aiShow => 'Show';

  @override
  String aiErrorListModels(String error) {
    return 'Could not list the models ($error).';
  }

  @override
  String get aiErrorTimeout => 'The server took too long to respond.';

  @override
  String aiErrorNoConnection(String host, String message) {
    return 'Could not connect to $host ($message).';
  }

  @override
  String aiErrorSecureConnection(String host) {
    return 'Secure connection to $host failed.';
  }

  @override
  String get aiErrorUnexpectedResponse =>
      'Unexpected response from the server.';

  @override
  String get aiErrorInvalidKey => 'Invalid API key or missing permission.';

  @override
  String get aiErrorNotFound => 'Address or model not found.';

  @override
  String get aiErrorRateLimit => 'Usage limit reached. Try again in a moment.';

  @override
  String aiErrorProviderUnstable(int status) {
    return 'The provider is unstable right now ($status).';
  }

  @override
  String aiErrorStatus(int status) {
    return 'Error $status.';
  }

  @override
  String get aiErrorNoKey => 'Set an API key in Settings.';

  @override
  String get aiErrorNoModel => 'Pick a model in Settings.';

  @override
  String get aiErrorRefused => 'The model declined this request.';

  @override
  String get aiErrorEmptyReply => 'The model returned nothing.';

  @override
  String get aiEffectDone => 'Done, I made the effect.';

  @override
  String alertsTempWarm(String what) {
    return '$what hot';
  }

  @override
  String alertsTempHot(String what) {
    return '$what very hot';
  }

  @override
  String alertsTempNow(String temp) {
    return '$temp °C right now';
  }

  @override
  String get alertsDiskFallback => 'Disk';

  @override
  String get alertsMemoryTitle => 'Memory almost full';

  @override
  String alertsMemoryDetail(String percent, String free) {
    return '$percent% in use · $free free';
  }

  @override
  String alertsVolumeTitle(String letter) {
    return 'Drive $letter: almost full';
  }

  @override
  String alertsVolumeDetail(String free, String total) {
    return '$free free of $total';
  }

  @override
  String get alertsPumpTitle => 'Water cooler pump stopped';

  @override
  String alertsPumpDetail(String name, int rpm) {
    return '$name at $rpm RPM';
  }

  @override
  String get audioSourceOff => 'Off';

  @override
  String get audioSourceSystem => 'PC sound';

  @override
  String get audioSourceMicrophone => 'Microphone';

  @override
  String get audioSourceBoth => 'PC sound and microphone';

  @override
  String profileAppsTitle(String profile) {
    return 'Turn on \"$profile\" with programs';
  }

  @override
  String get profileAppsDescription =>
      'When one of these programs opens, the profile turns on by itself. When it closes, your previous lighting comes back, unless you picked another one in the meantime.';

  @override
  String get profileAppsNone => 'No programs yet.';

  @override
  String get profileAppsRemove => 'Remove';

  @override
  String get profileAppsNameHint => 'Program name, e.g. cs2.exe';

  @override
  String get profileAppsOpenNow => 'Open now';

  @override
  String get profileAppsNoOthers => 'No other program with an open window.';

  @override
  String get profileAppsBrowse => 'Browse for .exe';

  @override
  String get profileAppsCancel => 'Cancel';

  @override
  String get profileAppsSave => 'Save';

  @override
  String get profileAppsFileTypeLabel => 'Programs';

  @override
  String aiErrorInsecureUrl(String host) {
    return 'Only HTTPS addresses are allowed for $host. Plain HTTP is accepted only for servers on this PC (localhost).';
  }

  @override
  String get settingsManagePlugins => 'Manage';

  @override
  String ocfxErrorInvalidJson(String message) {
    return 'The file isn\'t valid JSON ($message).';
  }

  @override
  String get ocfxErrorNotObject => 'The file must be a JSON object.';

  @override
  String get ocfxErrorMissingVersion =>
      'The \"openchroma\": 1 field is missing.';

  @override
  String get ocfxErrorMissingName => 'The \"name\" field is missing.';

  @override
  String get ocfxErrorNoLayers =>
      'The effect needs at least one layer in \"layers\".';

  @override
  String ocfxErrorLayerType(int index, String types) {
    return 'Layer $index: \"type\" must be one of: $types.';
  }

  @override
  String get ocfxErrorParamsNotObject => '\"params\" must be an object.';

  @override
  String ocfxErrorParamType(String key, String types) {
    return 'Parameter \"$key\": \"type\" must be one of: $types.';
  }

  @override
  String get ocfxErrorI18nNotObject =>
      '\"i18n\" must be an object with one object per language.';

  @override
  String get paramColorPickerTitle => 'Color';

  @override
  String get paramColorPickerCancel => 'Cancel';

  @override
  String get paramColorPickerApply => 'Apply';

  @override
  String get appTitle => 'OpenChroma';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String colorOrderTitle(String header) {
    return 'Color order · $header';
  }

  @override
  String get colorOrderQuestion =>
      'What color are the fans on this connector showing right now?';

  @override
  String get colorOrderBlueTitle => 'Is it blue?';

  @override
  String colorOrderTesting(String order) {
    return 'Testing order $order.';
  }

  @override
  String get colorOrderDoneTitle => 'Done';

  @override
  String get colorOrderFailedTitle => 'That didn\'t work';

  @override
  String colorOrderNothingLit(String header) {
    return 'If nothing lit up, check the LED count of $header and that the fans are on this connector.';
  }

  @override
  String colorOrderAlreadyRight(String order) {
    return 'The order was already correct ($order).';
  }

  @override
  String get colorOrderSameColors => 'Both colors looked the same. Try again.';

  @override
  String get colorOrderCouldNotFix =>
      'Couldn\'t fix it automatically. Pick the order manually from the list.';

  @override
  String colorOrderSaved(String order, String header) {
    return 'Order $order saved on $header.';
  }

  @override
  String get colorOrderNothingLitButton => 'Nothing lit up';

  @override
  String get colorOrderRed => 'Red';

  @override
  String get colorOrderGreen => 'Green';

  @override
  String get colorOrderBlue => 'Blue';

  @override
  String get colorOrderNo => 'No';

  @override
  String get colorOrderYes => 'Yes';

  @override
  String get colorOrderClose => 'Close';

  @override
  String get devicesTitle => 'Devices';

  @override
  String get devicesScanning => 'Scanning…';

  @override
  String devicesConnectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count connected',
      one: '1 connected',
    );
    return '$_temp0';
  }

  @override
  String get devicesScan => 'Scan';

  @override
  String get devicesOtherWireless => 'Other wireless';

  @override
  String get devicesScanningTitle => 'Scanning for devices';

  @override
  String get devicesDriversUnavailable => 'Drivers unavailable';

  @override
  String get devicesNone => 'No devices';

  @override
  String get devicesScanTakesSeconds => 'This takes a few seconds.';

  @override
  String get devicesDriversMissing =>
      'The drivers weren\'t found in this installation. Reinstall OpenChroma.';

  @override
  String get devicesNoneHint =>
      'Connect a compatible device. If another RGB program is open, close it first. Memory modules and graphics cards need administrator mode and PawnIO.';

  @override
  String get devicesScanAgain => 'Scan again';

  @override
  String get devicesStatusConnected => 'Connected';

  @override
  String get devicesStatusStarting => 'Starting';

  @override
  String get devicesStatusError => 'Error';

  @override
  String get devicesStatusDisabled => 'Disabled';

  @override
  String get devicesStatusUnsupported => 'Unsupported';

  @override
  String get devicesStatusStopped => 'Stopped';

  @override
  String get devicesKindKeyboard => 'Keyboard';

  @override
  String get devicesKindMouse => 'Mouse';

  @override
  String get devicesKindHeadset => 'Headset';

  @override
  String get devicesKindMousepad => 'Mousepad';

  @override
  String get devicesKindMotherboard => 'Motherboard';

  @override
  String get devicesKindGpu => 'Graphics card';

  @override
  String get devicesKindRam => 'Memory';

  @override
  String get devicesKindFan => 'Fans';

  @override
  String get devicesKindCooler => 'Water cooler';

  @override
  String get devicesKindController => 'RGB controller';

  @override
  String get devicesKindStrip => 'LED strip';

  @override
  String get devicesKindSpeakers => 'Speakers';

  @override
  String get devicesKindMicrophone => 'Microphone';

  @override
  String get devicesKindGamepad => 'Gamepad';

  @override
  String get devicesKindCase => 'PC case';

  @override
  String get devicesKindOther => 'Device';

  @override
  String devicesLedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count LEDs',
      one: '1 LED',
    );
    return '$_temp0';
  }

  @override
  String devicesCharging(int level) {
    return 'Charging · $level%';
  }

  @override
  String devicesBattery(int level) {
    return 'Battery $level%';
  }

  @override
  String get devicesRestoreDefaults => 'Restore defaults';

  @override
  String get devicesEnable => 'Enable';

  @override
  String get devicesDisable => 'Disable';

  @override
  String get devicesTabLighting => 'Lighting';

  @override
  String get devicesTabScreen => 'Screen';

  @override
  String get devicesTabDetails => 'Details';

  @override
  String get devicesOff => 'Off';

  @override
  String get devicesModeStatic => 'Static';

  @override
  String get devicesModeBreathing => 'Breathing';

  @override
  String get devicesModeBlinking => 'Blinking';

  @override
  String get devicesModeFlashing => 'Flashing';

  @override
  String get devicesModeColorCycle => 'Color cycle';

  @override
  String get devicesModeSpectrumCycle => 'Spectrum cycle';

  @override
  String get devicesModeRainbow => 'Rainbow';

  @override
  String get devicesModeRainbowWave => 'Rainbow wave';

  @override
  String get devicesModeWave => 'Wave';

  @override
  String get devicesModeColorWave => 'Color wave';

  @override
  String get devicesModeReactive => 'Reactive';

  @override
  String get devicesModeRipple => 'Ripple';

  @override
  String get devicesModeStarlight => 'Starlight';

  @override
  String get devicesModeRandomFlicker => 'Random flicker';

  @override
  String get devicesModeDoubleFlash => 'Double flash';

  @override
  String get devicesModeSpectrum => 'Spectrum';

  @override
  String get devicesModeCustom => 'Custom';

  @override
  String get devicesModeRandom => 'Random';

  @override
  String get devicesDirLeft => 'To the left';

  @override
  String get devicesDirRight => 'To the right';

  @override
  String get devicesDirUp => 'Upward';

  @override
  String get devicesDirDown => 'Downward';

  @override
  String get devicesDirHorizontal => 'Horizontal';

  @override
  String get devicesDirVertical => 'Vertical';

  @override
  String get devicesDirUpLeft => 'Upward and left';

  @override
  String get devicesDirUpRight => 'Upward and right';

  @override
  String get devicesDirDownLeft => 'Downward and left';

  @override
  String get devicesDirDownRight => 'Downward and right';

  @override
  String get devicesSpeed => 'Speed';

  @override
  String get devicesBrightness => 'Brightness';

  @override
  String get devicesDirection => 'Direction';

  @override
  String get devicesRandomColors => 'Random colors';

  @override
  String get devicesColor => 'Color';

  @override
  String get devicesColors => 'Colors';

  @override
  String get devicesRemoveColor => 'Remove a color';

  @override
  String get devicesAddColor => 'Add a color';

  @override
  String get devicesLighting => 'Lighting';

  @override
  String get devicesFollowsApp => 'Follows OpenChroma effects.';

  @override
  String get devicesRunsItself => 'The device runs the effect itself.';

  @override
  String get devicesAppEffects => 'OpenChroma effects';

  @override
  String devicesZonesWithoutLeds(String zones) {
    return '$zones without LEDs: whatever is plugged into those connectors doesn\'t follow the effects and stays on the previous effect. Enter the LED count below.';
  }

  @override
  String get devicesArgbHint =>
      'On ARGB connectors, enter how many LEDs are plugged in. A 120 mm fan usually has between 8 and 24. Then position each zone in Lighting › Layout.';

  @override
  String devicesZoneN(int n) {
    return 'Zone $n';
  }

  @override
  String devicesUpToLeds(int max) {
    return 'Up to $max LEDs';
  }

  @override
  String devicesMatrix(int width, int height) {
    return 'Matrix $width × $height';
  }

  @override
  String get devicesCountLeds => 'Count';

  @override
  String devicesCountLedsTitle(String zone) {
    return 'Count LEDs of $zone';
  }

  @override
  String get devicesCountLedsHint =>
      'The first LEDs light up green. Increase the count until the last fan or strip is fully lit, and stop at the point where lighting one more changes nothing.';

  @override
  String get devicesOneLess => 'One less';

  @override
  String get devicesOneMore => 'One more';

  @override
  String get devicesCancel => 'Cancel';

  @override
  String devicesUseLeds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use $count LEDs',
      one: 'Use 1 LED',
    );
    return '$_temp0';
  }

  @override
  String get devicesInfoVendor => 'Manufacturer';

  @override
  String get devicesInfoDescription => 'Description';

  @override
  String get devicesInfoVersion => 'Version';

  @override
  String get devicesInfoSerial => 'Serial number';

  @override
  String get devicesInfoDriver => 'Driver';

  @override
  String get devicesDriverBuiltIn => 'OpenRGB (included)';

  @override
  String devicesDriverPluginBundled(String name) {
    return '$name · bundled plugin';
  }

  @override
  String devicesDriverPluginUser(String name) {
    return '$name · your plugin';
  }

  @override
  String get devicesInfoConnection => 'Connection';

  @override
  String get devicesInfoZones => 'Zones';

  @override
  String get devicesInfoHardwareModes => 'Hardware modes';

  @override
  String devicesColorOrderOption(String what) {
    return 'Color order · $what';
  }

  @override
  String get devicesBoardLedC => 'board LED_C';

  @override
  String devicesDetectGen2(String name) {
    return 'Detect ARGB Gen2 · $name';
  }

  @override
  String get devicesPersistLighting => 'Save lighting on exit';

  @override
  String get devicesCalibrationHint =>
      'If the color comes out swapped (e.g. green instead of blue), use \"Detect\": two questions and the app finds the right order.';

  @override
  String get devicesDetect => 'Detect';

  @override
  String get devicesResetTitle => 'Restore defaults?';

  @override
  String get devicesResetBody =>
      'Returns the device\'s options (such as color order) to what they were when it was first detected, makes it follow OpenChroma effects again and restores its position in the layout. Connector LED counts are kept.';

  @override
  String get devicesRestore => 'Restore';

  @override
  String get engineProfileGame => 'Game';

  @override
  String get engineProfileWork => 'Work';

  @override
  String get engineProfileNight => 'Night';

  @override
  String get engineProfileOff => 'Off';

  @override
  String get engineImportBadExtension => 'Use an .ocfx, .json or .html file.';

  @override
  String get engineImportUnreadable => 'Couldn\'t read that file.';

  @override
  String enginePluginStopped(String error) {
    return 'The plugin stopped: $error';
  }

  @override
  String get enginePluginRejected =>
      'The plugin didn\'t recognize this device.';

  @override
  String get engineScreenNoLiveValues =>
      'This screen doesn\'t show live values.';

  @override
  String engineScreenMaxLiveValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This screen shows up to $count different live values.',
      one: 'This screen shows up to 1 different live value.',
    );
    return '$_temp0';
  }

  @override
  String get engineScreenRejected => 'The device didn\'t accept the image.';

  @override
  String get engineScreenCannotOpen => 'Couldn\'t open the image.';

  @override
  String get pluginsNoDefinition => 'the file doesn\'t call plugin()';

  @override
  String get pluginsNoDevices => 'no devices in \"devices\"';

  @override
  String get pluginsNoPort => 'no port chosen';

  @override
  String get pluginsNoInterface => 'no interface chosen';

  @override
  String pluginsCannotOpen(String path) {
    return 'couldn\'t open $path';
  }

  @override
  String get layoutPreview => 'Preview';

  @override
  String get layoutApply => 'Apply';

  @override
  String get layoutCancel => 'Cancel';

  @override
  String get layoutAutoArrange => 'Auto arrange';

  @override
  String get layoutUndo => 'Undo';

  @override
  String get layoutHint =>
      'Click a zone to identify its LEDs, or drag to move it.';

  @override
  String get layoutDimEffect => 'Dim effect';

  @override
  String get layoutNothingTitle => 'Nothing to place';

  @override
  String get layoutNothingMessage => 'Connected devices appear here.';

  @override
  String get layoutDevice => 'Device';

  @override
  String get layoutSelectedZone => 'Selected zone';

  @override
  String get layoutFill => 'Fill';

  @override
  String get layoutSwitchToApp =>
      'Switch to OpenChroma effects to identify this zone.';

  @override
  String get layoutRotate => 'Rotate 90°';

  @override
  String get layoutFlipHorizontal => 'Flip horizontal';

  @override
  String get layoutFlipVertical => 'Flip vertical';

  @override
  String get layoutScale => 'Scale';

  @override
  String get layoutPositionX => 'X position';

  @override
  String get layoutPositionY => 'Y position';

  @override
  String get screenImageFiles => 'Images and GIFs';

  @override
  String get screenImageOrGif => 'Image or GIF';

  @override
  String screenSending(int percent) {
    return 'Sending… $percent%';
  }

  @override
  String get screenImageHint =>
      'Crop, pick the clip and write over it before sending. The screen keeps what it receives, even with the app closed.';

  @override
  String get screenEdit => 'Edit';

  @override
  String get screenChooseFile => 'Choose file';

  @override
  String get screenEditorCannotOpen => 'Couldn\'t open the image.';

  @override
  String get screenEditorTitle => 'Edit screen image';

  @override
  String get screenEditorHintIdle =>
      'Click a text to select it. Drag the image to position it and use the mouse wheel to zoom.';

  @override
  String get screenEditorHintSelected =>
      'Drag to move and pull the corner (or use the mouse wheel over the text) to resize. Arrow keys nudge the position, Delete removes, Ctrl+D duplicates and Esc clears the selection.';

  @override
  String get screenEditorCancel => 'Cancel';

  @override
  String get screenEditorSend => 'Send to screen';

  @override
  String get screenEditorFraming => 'Framing';

  @override
  String get screenEditorFill => 'Fill';

  @override
  String get screenEditorFit => 'Fit';

  @override
  String get screenEditorBackgroundColor => 'Background color';

  @override
  String get screenEditorZoom => 'Zoom';

  @override
  String get screenEditorGifClip => 'GIF clip';

  @override
  String screenEditorFrameRange(
    int first,
    int last,
    int total,
    String duration,
  ) {
    return 'Frames $first to $last of $total · $duration';
  }

  @override
  String screenEditorFramesReduced(int max) {
    return ' · will be reduced to $max frames';
  }

  @override
  String get screenEditorTexts => 'Texts';

  @override
  String get screenEditorAddText => 'Add';

  @override
  String screenEditorLiveValues(int used, int total) {
    return 'Live values: $used of $total. The screen updates every second while the app is open.';
  }

  @override
  String get screenEditorTextHint => 'Text';

  @override
  String get screenEditorBold => 'Bold';

  @override
  String get screenEditorNormal => 'Regular';

  @override
  String get screenEditorTextColor => 'Text color';

  @override
  String get screenEditorDuplicate => 'Duplicate';

  @override
  String get screenEditorRemove => 'Remove';

  @override
  String screenEditorLiveHint(String unit) {
    return 'Live · put the unit ($unit) in a fixed text';
  }

  @override
  String get screenEditorShow => 'Show';

  @override
  String get screenEditorFixedText => 'Fixed text';

  @override
  String get screenDefaultText => 'Text';

  @override
  String get screenSourceCpuTemp => 'CPU temperature';

  @override
  String get screenSourceCpuUsage => 'CPU usage';

  @override
  String get screenSourceCpuClock => 'CPU clock';

  @override
  String get screenSourceCpuPower => 'CPU power';

  @override
  String get screenSourceGpuTemp => 'GPU temperature';

  @override
  String get screenSourceGpuUsage => 'GPU usage';

  @override
  String get screenSourceGpuClock => 'GPU clock';

  @override
  String get screenSourceGpuPower => 'GPU power';

  @override
  String get screenSourceGpuFan => 'GPU fan';

  @override
  String get screenSourceRamUsage => 'RAM usage';

  @override
  String get perfTitle => 'Performance';

  @override
  String get perfRestartAsAdmin => 'Restart as administrator';

  @override
  String get perfClose => 'Close';

  @override
  String get monitorUnavailableTitle => 'Monitor unavailable';

  @override
  String get monitorUnavailableMessage =>
      'This build does not include the system sensors.';

  @override
  String get monitorReadingSensors => 'Reading sensors…';

  @override
  String monitorSubtitle(String uptime) {
    return 'Updated every second · PC up for $uptime';
  }

  @override
  String get monitorStalledTitle => 'Sensors did not respond';

  @override
  String get monitorStalledMessage =>
      'No readings arrived from the system. Close and reopen OpenChroma; if it keeps happening, let us know.';

  @override
  String monitorProcessesAt(String time) {
    return 'Processes at $time';
  }

  @override
  String monitorInspectSummary(String cpu, String memory) {
    return 'CPU $cpu · Memory $memory';
  }

  @override
  String get monitorProcessor => 'Processor';

  @override
  String monitorCoresThreads(int cores, int threads) {
    return '$cores cores · $threads threads';
  }

  @override
  String get monitorUsage => 'Usage';

  @override
  String get monitorTemperature => 'Temperature';

  @override
  String get monitorClock => 'Clock';

  @override
  String get monitorPower => 'Power';

  @override
  String get monitorUsagePerThread => 'Usage per thread';

  @override
  String get monitorNeedsAdminTitle => 'Administrator required';

  @override
  String get monitorNeedsAdminMessage =>
      'The CPU sensor is read by the PawnIO driver, which only serves programs running as administrator.';

  @override
  String get monitorSensorPendingTitle => 'Reading the sensor…';

  @override
  String get monitorSensorPendingMessage => 'Opening the PawnIO driver.';

  @override
  String get monitorSensorFailedTitle => 'The sensor did not respond';

  @override
  String get monitorSensorFailedMessage =>
      'The PawnIO driver stopped responding. The other readings keep working.';

  @override
  String get monitorNoDriverTitle => 'PawnIO driver not found';

  @override
  String get monitorNoDriverMessage =>
      'Install PawnIO (pawnio.eu) to see the CPU temperature.';

  @override
  String get monitorNoSensorTitle => 'No sensor';

  @override
  String get monitorNoSensorMessage =>
      'This processor has no supported temperature sensor.';

  @override
  String get monitorGraphicsCard => 'Graphics card';

  @override
  String get monitorTemperatureUnavailable => 'Temperature unavailable';

  @override
  String get monitorFan => 'Fan';

  @override
  String get monitorVideoMemory => 'Video memory';

  @override
  String monitorUsedOfTotal(String used, String total) {
    return '$used of $total';
  }

  @override
  String monitorIntegratedGpu(String name) {
    return '$name · integrated';
  }

  @override
  String get monitorMemoryRam => 'RAM';

  @override
  String monitorMemoryInstalled(String size) {
    return '$size installed';
  }

  @override
  String get monitorMemoryAvailable => 'Available';

  @override
  String get monitorMemoryCached => 'Cached';

  @override
  String get monitorMemoryCommitted => 'Committed';

  @override
  String get monitorStorage => 'Storage';

  @override
  String monitorDiskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disks',
      one: '1 disk',
    );
    return '$_temp0';
  }

  @override
  String monitorDiskNumber(int number) {
    return 'Disk $number';
  }

  @override
  String monitorDiskActive(String percent) {
    return 'Active $percent';
  }

  @override
  String get monitorVolumeRemovable => 'Removable';

  @override
  String get monitorVolumeLocal => 'Local disk';

  @override
  String monitorFreeOfTotal(String free, String total) {
    return '$free free of $total';
  }

  @override
  String get monitorNetwork => 'Network';

  @override
  String get monitorTraffic => 'Traffic';

  @override
  String get monitorDownload => 'Download';

  @override
  String get monitorUpload => 'Upload';

  @override
  String get monitorProcesses => 'Processes';

  @override
  String get monitorTopMemory => 'Top memory users';

  @override
  String get monitorTopCpu => 'Top CPU users';

  @override
  String get monitorColumnName => 'Name';

  @override
  String get monitorColumnCpu => 'CPU';

  @override
  String get monitorColumnMemory => 'Memory';

  @override
  String get monitorNoProcessData => 'No process data for this sample.';

  @override
  String monitorSortTooltip(String column) {
    return 'Sort by $column, highest first';
  }

  @override
  String get monitorTempNormal => 'Normal';

  @override
  String get monitorTempWarm => 'Warm';

  @override
  String get monitorTempHot => 'Very hot';

  @override
  String monitorThreadTooltip(int number, String usage) {
    return 'Thread $number: $usage';
  }

  @override
  String get monitorClickToInspect => 'Click to inspect';

  @override
  String get monitorNow => 'now';

  @override
  String monitorSecondsAgo(int seconds) {
    return '$seconds s ago';
  }

  @override
  String get checkupSubtitleRunning => 'Checkup in progress';

  @override
  String get checkupSubtitleEmpty => 'Test your PC stability and health';

  @override
  String checkupSubtitleLast(String when) {
    return 'Last checkup $when';
  }

  @override
  String checkupWhenToday(String time) {
    return 'today at $time';
  }

  @override
  String checkupWhenYesterday(String time) {
    return 'yesterday at $time';
  }

  @override
  String checkupWhenDate(String date, String time) {
    return 'on $date at $time';
  }

  @override
  String get checkupTests => 'Tests';

  @override
  String checkupSelectedCount(int selected, int total) {
    return '$selected of $total';
  }

  @override
  String get checkupPlanQuick => 'Quick';

  @override
  String get checkupPlanStandard => 'Standard';

  @override
  String get checkupPlanLong => 'Long';

  @override
  String get checkupTestCpuSingle => 'Processor · 1 core';

  @override
  String get checkupTestCpuAll => 'Processor · all cores';

  @override
  String get checkupTestMemory => 'RAM';

  @override
  String get checkupTestGpu => 'Graphics card';

  @override
  String get checkupTestCpuGpu => 'CPU + GPU together';

  @override
  String get checkupTestDisk => 'Storage';

  @override
  String checkupThousands(String value) {
    return '${value}k';
  }

  @override
  String checkupMemoryMetricRead(String read) {
    return 'Reads $read GB/s';
  }

  @override
  String checkupMemoryMetricWrite(String write) {
    return 'writes $write';
  }

  @override
  String checkupDiskMetricWrite(String write) {
    return 'Writes $write GB/s';
  }

  @override
  String checkupDiskMetricRead(String read) {
    return 'reads $read';
  }

  @override
  String get checkupTitle => 'Checkup';

  @override
  String get checkupCancel => 'Cancel';

  @override
  String get checkupPreparing => 'Preparing…';

  @override
  String get checkupStart => 'Start checkup';

  @override
  String get checkupRunAgain => 'Run again';

  @override
  String get checkupNoAdminNote =>
      'Without administrator rights, the CPU temperature and the cause of blue screens are left out.';

  @override
  String checkupProblemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems',
      one: '1 problem',
    );
    return '$_temp0';
  }

  @override
  String checkupWarningCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String get checkupAllGood => 'All good';

  @override
  String checkupCalcErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calculation errors',
      one: '1 calculation error',
      zero: 'No calculation errors',
    );
    return '$_temp0';
  }

  @override
  String checkupNext(String plan, int minutes) {
    return 'Next: $plan · ≈ $minutes min';
  }

  @override
  String checkupTestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tests',
      one: '1 test',
    );
    return '$_temp0';
  }

  @override
  String get checkupFinishing => 'Finishing…';

  @override
  String checkupTestProgress(int index, int total) {
    return 'Test $index of $total';
  }

  @override
  String checkupProgressRemaining(int percent, String time) {
    return '$percent% · $time left';
  }

  @override
  String get checkupStatusQueued => 'Queued';

  @override
  String get checkupStatusStable => 'Stable';

  @override
  String checkupStatusErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String get checkupStatusStopped => 'Stopped';

  @override
  String get checkupStatusDidNotRun => 'Did not run';

  @override
  String get checkupStatusCancelled => 'Cancelled';

  @override
  String get systemCardTitle => 'System';

  @override
  String get systemAfterFirstCheckup => 'Appears after the first checkup';

  @override
  String get systemMotherboard => 'Motherboard';

  @override
  String get systemProcessor => 'Processor';

  @override
  String get systemGraphicsCard => 'Graphics card';

  @override
  String get systemMemory => 'Memory';

  @override
  String systemModuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modules',
      one: '1 module',
    );
    return '$_temp0';
  }

  @override
  String systemSlotCount(int count) {
    return '$count slots';
  }

  @override
  String get systemMemoryInUse => 'Memory in use';

  @override
  String systemMemoryUsedOfTotal(String used, String total) {
    return '$used of $total GB';
  }

  @override
  String get systemDrive => 'System drive';

  @override
  String systemDriveFree(String free, String total) {
    return '$free GB free of $total GB';
  }

  @override
  String get systemBlueScreens => 'Blue screens · 30 days';

  @override
  String get systemBlueScreensNone => 'None';

  @override
  String get systemStartupApps => 'Start with Windows';

  @override
  String systemStartupAppsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count programs',
      one: '1 program',
    );
    return '$_temp0';
  }

  @override
  String get systemIdleCpu => 'CPU at idle';

  @override
  String systemIdleCpuValue(int temp, int usage) {
    return '$temp °C · $usage% usage';
  }

  @override
  String get checkupRecommendations => 'Recommendations';

  @override
  String get checkupRecommendationsEmpty =>
      'Finish a checkup to see the recommendations';

  @override
  String get checkupAiTitle => 'AI analysis';

  @override
  String get checkupAiNotReady => 'Connect an AI in Settings to use this.';

  @override
  String get checkupAiRunFirst => 'Run a checkup to analyze the results.';

  @override
  String get checkupAiHint =>
      'Explains the results and suggests tweaks for your PC.';

  @override
  String get checkupAiAnalyze => 'Analyze';

  @override
  String get checkupAiAnalyzeAgain => 'Analyze again';

  @override
  String get checkupAiSystemPrompt =>
      'You are an experienced hardware technician analyzing the checkup of a Windows PC run by the OpenChroma app. Answer in American English, in plain text (no tables), with: a one-line verdict; the real problems in order of importance, each with the probable cause and what to do; and what is fine. Be specific with the numbers in the report and do not invent data that is not in it. 250 words at most.';

  @override
  String checkupAbortCpuTemp(int temp) {
    return 'CPU went over $temp °C';
  }

  @override
  String checkupAbortGpuTemp(int temp) {
    return 'The graphics card went over $temp °C';
  }

  @override
  String get checkupAbortPump => 'The liquid cooler pump stopped';

  @override
  String checkupAdviceAbortedTitle(String reason) {
    return 'Test stopped: $reason';
  }

  @override
  String get checkupAdviceAbortedDetail =>
      'Cooling could not keep up with the load. Check the cooler (mounting, thermal paste, fans and pump) before using the PC under heavy load.';

  @override
  String get checkupAdviceCpuErrorsTitle =>
      'The CPU made calculation errors under load';

  @override
  String get checkupAdviceCpuErrorsDetail =>
      'Sign of instability. Undo any overclock or undervolt (PBO, Curve Optimizer) and update the BIOS; if it keeps happening, it may be a defect.';

  @override
  String get checkupAdviceGpuErrorsTitle =>
      'The graphics card calculated incorrectly';

  @override
  String get checkupAdviceGpuErrorsDetail =>
      'Remove any GPU overclock and update the graphics driver.';

  @override
  String get checkupAdviceMemoryErrorsTitle => 'The memory returned wrong data';

  @override
  String get checkupAdviceMemoryErrorsDetail =>
      'Turn off EXPO/XMP in the BIOS and test again. If it keeps happening, test one module at a time to find the faulty one.';

  @override
  String get checkupAdviceDiskErrorsTitle =>
      'The disk returned data different from what was written';

  @override
  String get checkupAdviceDiskErrorsDetail =>
      'Back up now and check the disk health.';

  @override
  String checkupAdviceBlueScreensTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blue screens in the last 30 days',
      one: '1 blue screen in the last 30 days',
    );
    return '$_temp0';
  }

  @override
  String checkupAdviceBlueScreensSuspect(String driver, int count, int total) {
    return 'The driver $driver appears in $count of $total crash records. Update or uninstall the program that owns it.';
  }

  @override
  String get checkupAdviceBlueScreensNoSuspect =>
      'The records do not point to a third-party driver. Update the BIOS, the chipset and the graphics driver, and test the memory.';

  @override
  String get checkupAdviceBlueScreensNeedAdmin =>
      'Run the checkup as administrator to find the responsible driver.';

  @override
  String checkupAdviceCpuHotTitle(int temp) {
    return 'The CPU reaches $temp °C at full load';
  }

  @override
  String get checkupAdviceCpuHotDetail =>
      'It is at its thermal limit and loses performance. Improve cooling or limit the temperature/power in the BIOS (Eco Mode on AMD, PL1/PL2 on Intel).';

  @override
  String checkupAdviceGpuHotTitle(int temp) {
    return 'The graphics card reaches $temp °C';
  }

  @override
  String get checkupAdviceGpuHotDetail =>
      'Improve the case airflow or adjust the GPU fan curve.';

  @override
  String get checkupAdviceSingleChannelTitle => 'Single-channel memory';

  @override
  String get checkupAdviceSingleChannelDetail =>
      'A single module uses half the bandwidth. Adding an identical one (same model) enables dual channel.';

  @override
  String get checkupAdviceSameChannelTitle =>
      'The modules are on the same channel';

  @override
  String get checkupAdviceSameChannelDetail =>
      'Move them to the slots shown in the motherboard manual (usually A2 and B2).';

  @override
  String get checkupAdviceSlowMemoryTitle =>
      'The memory runs below what it supports';

  @override
  String checkupAdviceSlowMemoryDetail(int configured, int speed) {
    return '$configured of $speed MT/s. Turn on EXPO (AMD) or XMP (Intel) in the BIOS.';
  }

  @override
  String get checkupAdviceProfileOffTitle => 'EXPO/XMP is probably off';

  @override
  String checkupAdviceProfileOffDetail(int configured) {
    return 'The memory is at its base speed ($configured MT/s). If the module is rated for a higher speed, turn on EXPO/XMP in the BIOS.';
  }

  @override
  String get checkupAdviceMemoryFullTitle => 'Memory almost full';

  @override
  String checkupAdviceMemoryFullDetail(
    String used,
    String total,
    String committed,
  ) {
    return '$used of $total GB in use and $committed GB requested by programs; the excess goes to disk and slows everything down. Close heavy apps or add RAM.';
  }

  @override
  String get checkupAdviceDriveFullTitle => 'System drive almost full';

  @override
  String checkupAdviceDriveFullDetail(String free) {
    return 'Only $free GB free. Below 10%, Windows slows down, runs short of space for virtual memory and deletes crash records.';
  }

  @override
  String checkupAdviceStartupTitle(int count) {
    return '$count programs start with Windows';
  }

  @override
  String get checkupAdviceStartupDetail =>
      'Turn off the ones you do not use every day in Task Manager > Startup apps.';

  @override
  String get checkupAdviceBusyTitle => 'The PC was busy before the tests';

  @override
  String checkupAdviceBusyDetail(int usage) {
    return '$usage% CPU usage at idle: background programs heat up the PC and affect the results.';
  }

  @override
  String get checkupAdviceNoCpuTempTitle => 'No CPU temperature';

  @override
  String get checkupAdviceNoCpuTempDetail =>
      'Run the checkup as administrator to measure the temperature and protect the CPU during the tests.';

  @override
  String get checkupAdviceAllGoodDetail =>
      'No errors in the tests and nothing out of the ordinary on the system.';

  @override
  String get systemErrorWindowsSetting =>
      'Could not change the Windows setting.';

  @override
  String get systemErrorSaveSetting => 'Could not save the setting.';

  @override
  String get systemErrorEnableStartup =>
      'Could not turn on starting with Windows.';

  @override
  String get systemErrorTaskNotCreated =>
      'The startup task was not created. You need to accept the Windows permission prompt.';

  @override
  String get systemErrorTaskNotRemoved =>
      'The startup task was not removed. You need to accept the Windows permission prompt.';

  @override
  String get systemTaskDescription =>
      'Opens OpenChroma as administrator when you sign in to Windows.';

  @override
  String get pluginTrustTimedOut =>
      'The plugin took too long to start and was stopped.';

  @override
  String get pluginTrustLoadFailed => 'The plugin stopped while loading.';

  @override
  String get pluginTrustTooLarge => 'The file is larger than 1 MB.';

  @override
  String get pluginTrustUnresponsive => 'The plugin stopped responding.';

  @override
  String pluginTrustBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new plugins need your approval',
      one: '1 new plugin needs your approval',
    );
    return '$_temp0';
  }

  @override
  String get pluginTrustReview => 'Review';

  @override
  String get pluginTrustTitle => 'Device plugins';

  @override
  String get pluginTrustIntro =>
      'A plugin is a program that runs inside OpenChroma and can send any command to your USB devices. Approve only plugins from a source you trust.';

  @override
  String get pluginTrustElevated =>
      'OpenChroma is running as administrator, so an approved plugin runs with administrator rights.';

  @override
  String get pluginTrustPending => 'Waiting for approval';

  @override
  String get pluginTrustApproved => 'Approved';

  @override
  String get pluginTrustDenied => 'Not allowed';

  @override
  String get pluginTrustApprove => 'Approve';

  @override
  String get pluginTrustDeny => 'Don\'t allow';

  @override
  String get pluginTrustRevoke => 'Revoke';

  @override
  String get pluginTrustClose => 'Close';

  @override
  String get pluginTrustPath => 'Path';

  @override
  String get pluginTrustSize => 'Size';

  @override
  String get pluginTrustModified => 'Modified';

  @override
  String get pluginTrustHash => 'SHA-256';

  @override
  String get pluginTrustChanged => 'Changed since you approved it';

  @override
  String get pluginTrustReplaces =>
      'Replaces the built-in plugin with the same file name';

  @override
  String pluginTrustOverrides(String names) {
    return 'Replaces the built-in plugin: $names';
  }

  @override
  String get pluginTrustEmpty =>
      'There are no plugins in your plugins folder. Built-in plugins don\'t need approval.';

  @override
  String get securityStartupAdminDescription =>
      'Opens in the tray, as administrator, when you sign in to Windows, without asking for permission. Changing it needs OpenChroma running as administrator.';

  @override
  String get securityStartupInstallUnsafe =>
      'To start as administrator automatically, install OpenChroma for all users (in Program Files). This copy can be modified without administrator rights, so it cannot be trusted to run with full access when you sign in.';

  @override
  String get securityStartupInstallUnsafeRemove =>
      'This copy can be modified without administrator rights, so starting it as administrator is unsafe. Turn this off to remove the automatic start as administrator.';

  @override
  String get securityStartupNeedsAdmin =>
      'Restart OpenChroma as administrator to change the automatic start as administrator.';

  @override
  String get securityErrorNeedsAdmin =>
      'Restart OpenChroma as administrator to change this setting.';

  @override
  String get securityErrorInstallNotTrusted =>
      'To start as administrator automatically, install OpenChroma for all users (in Program Files).';

  @override
  String get securityErrorTaskNotCreated => 'The startup task was not created.';

  @override
  String get securityErrorTaskNotRemoved => 'The startup task was not removed.';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonOff => 'Off';

  @override
  String get commonPaused => 'Paused';

  @override
  String get commonLive => 'Live';

  @override
  String get commonNoEffect => 'No effect';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get shellNavHome => 'Home';

  @override
  String get shellNavLighting => 'Lighting';

  @override
  String get shellNavDevices => 'Devices';

  @override
  String get shellNavFans => 'Fans';

  @override
  String get shellNavPerformance => 'Performance';

  @override
  String get shellNavSettings => 'Settings';

  @override
  String get shellAdminActive => 'Administrator mode on';

  @override
  String get shellRestartAsAdmin => 'Restart as administrator';

  @override
  String get shellTabEffects => 'Effects';

  @override
  String get shellTabLayout => 'Layout';

  @override
  String get shellTabMonitor => 'Monitor';

  @override
  String get shellTabDiagnostics => 'Diagnostics';

  @override
  String shellConflictOpen(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names are open.',
      one: '$names is open.',
    );
    return '$_temp0';
  }

  @override
  String get shellConflictAdvice =>
      'Two programs on the same LEDs make the colors flicker. Close it, including in the tray.';

  @override
  String get shellWebviewMissing =>
      'Effects need Microsoft WebView2, which isn\'t installed on this PC.';

  @override
  String get shellWebviewDownload => 'Download WebView2';

  @override
  String get shellPlayerOffPaused => 'Off · effect paused';

  @override
  String shellPlayerLiveOnDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Live on $count devices',
      one: 'Live on 1 device',
    );
    return '$_temp0';
  }

  @override
  String get lightingTitle => 'Lighting';

  @override
  String get lightingBrightnessPerDevice => 'Brightness of each device';

  @override
  String get lightingBrightnessTitle => 'Brightness';

  @override
  String get lightingAll => 'All';

  @override
  String get lightingLights => 'Lights';

  @override
  String get lightingScreens => 'Screens';

  @override
  String get lightingNoDevices => 'No devices connected.';

  @override
  String get lightingBrightnessNote =>
      '\"All\" applies to every device, on top of each one\'s own brightness. At 0%, the effect pauses and nothing is sent.';

  @override
  String get lightingPausedAtZero => 'Paused: brightness is at 0%';

  @override
  String get lightingResumeEffect => 'Resume the effect';

  @override
  String get lightingPauseEffect => 'Pause the effect';

  @override
  String get homeGreetingNight => 'Good night';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeStatusReading => 'Reading sensors…';

  @override
  String get homeStatusAllGood => 'Everything looks good with your PC.';

  @override
  String homeStatusAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerts need attention.',
      one: '1 alert needs attention.',
    );
    return '$_temp0';
  }

  @override
  String homeWeekday(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
      'sat': 'Saturday',
      'other': 'Sunday',
    });
    return '$_temp0';
  }

  @override
  String homeMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'January',
      'feb': 'February',
      'mar': 'March',
      'apr': 'April',
      'may': 'May',
      'jun': 'June',
      'jul': 'July',
      'aug': 'August',
      'sep': 'September',
      'oct': 'October',
      'nov': 'November',
      'other': 'December',
    });
    return '$_temp0';
  }

  @override
  String homeDate(String weekday, String month, int day) {
    return '$weekday, $month $day';
  }

  @override
  String get homeOpenLighting => 'Open lighting';

  @override
  String homeOnDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'On $count devices',
      one: 'On 1 device',
    );
    return '$_temp0';
  }

  @override
  String get homeProfilesTitle => 'Profiles';

  @override
  String get homeProfilesHint =>
      'Right-click a profile to save the current lighting to it or to turn it on along with a program';

  @override
  String homeProfileWithApp(String app) {
    return 'With $app';
  }

  @override
  String get homeProfileLightsOff => 'Lights off';

  @override
  String get homeProfileCurrentEffect => 'Current effect';

  @override
  String homeProfileAutoOn(String apps) {
    return 'Turns on automatically with $apps';
  }

  @override
  String get homeProfileSaveHere => 'Save current lighting here';

  @override
  String get homeProfileRename => 'Rename';

  @override
  String get homeProfileLinkApps => 'Turn on with apps…';

  @override
  String get homeProfileReset => 'Restore default profiles';

  @override
  String get homeProfileNameTitle => 'Profile name';

  @override
  String get homeLevelNormal => 'Normal';

  @override
  String get homeLevelWarm => 'Warm';

  @override
  String get homeLevelHot => 'Very hot';

  @override
  String homeVitalUsage(String value) {
    return 'Usage $value%';
  }

  @override
  String get homeVitalUsageNeedsAdmin => 'Usage · temperature needs admin';

  @override
  String get homeVitalMemory => 'Memory';

  @override
  String get homeVitalStorage => 'Storage';

  @override
  String get homeVitalFreeUnit => 'GB free';

  @override
  String homeVitalMemoryUsed(String used, String total) {
    return '$used of $total';
  }

  @override
  String homeVitalDiskUsed(String letter, String percent) {
    return '$letter: · $percent% used';
  }

  @override
  String get homeAlertsTitle => 'Alerts';

  @override
  String get homeAlertsAllGood => 'All good';

  @override
  String get homeFansTitle => 'Fans';

  @override
  String get homeFanSilent => 'Silent';

  @override
  String get homeFanBalanced => 'Balanced';

  @override
  String get homeFanTurbo => 'Turbo';

  @override
  String homeFanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fans',
      one: '1 fan',
    );
    return '$_temp0';
  }

  @override
  String homeFanUpTo(int rpm) {
    return 'up to $rpm RPM';
  }

  @override
  String get homeReactiveTitle => 'Reactive light';

  @override
  String get homeReactiveNoGpu => 'No GPU reading on this PC.';

  @override
  String get homeReactiveCpuNeedsAdmin =>
      'CPU temperature needs administrator mode.';

  @override
  String get homeReactiveOn =>
      'The LEDs show the temperature instead of the effect.';

  @override
  String get homeReactiveOff => 'LED color follows the temperature.';

  @override
  String homeScreenSending(int percent) {
    return 'Sending… $percent%';
  }

  @override
  String get homeScreenOff => 'Screen off';

  @override
  String homeScreenBrightness(int percent) {
    return 'Brightness $percent%';
  }

  @override
  String get homeScreenOn => 'Screen on';

  @override
  String get homeScreenTurnOff => 'Turn off the screen';

  @override
  String get homeScreenTurnOn => 'Turn on the screen';

  @override
  String get homeDevicesTitle => 'Devices';

  @override
  String get homeDevicesSearching => 'Searching…';

  @override
  String get homeDevicesNone => 'No devices';

  @override
  String get homeDeviceConnected => 'Connected';

  @override
  String get homeDeviceStarting => 'Starting';

  @override
  String get homeDeviceProblem => 'Problem';

  @override
  String get homeAssistantTitle => 'Assistant';

  @override
  String get homeAssistantNewChat => 'New chat';

  @override
  String get homeAssistantSuggestionSlow => 'Why is my PC slow?';

  @override
  String get homeAssistantSuggestionGpu => 'What is heating up the GPU?';

  @override
  String get homeAssistantSuggestionEffect => 'Create a calm blue effect';

  @override
  String get homeAssistantConnect => 'Connect an AI to ask about your PC.';

  @override
  String get homeAssistantConnectHint =>
      'Use your Anthropic or OpenAI key, or one from a compatible service.';

  @override
  String get homeAssistantSetUp => 'Set up AI';

  @override
  String get homeAssistantAskAnything => 'Ask anything about your PC.';

  @override
  String get homeAssistantThinking => 'Thinking…';

  @override
  String get homeAssistantApplyEffect => 'Apply effect';

  @override
  String get homeAssistantHint => 'Ask something…';

  @override
  String homeAssistantEffectOn(String title) {
    return '\"$title\" is on.';
  }
}
