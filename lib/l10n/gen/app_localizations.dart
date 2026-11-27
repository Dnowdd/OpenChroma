import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @aboutUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String aboutUpdateAvailable(String version);

  /// No description provided for @aboutUpdateBanner.
  ///
  /// In en, this message translates to:
  /// **'OpenChroma {version} is available.'**
  String aboutUpdateBanner(String version);

  /// No description provided for @aboutChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get aboutChecking;

  /// No description provided for @aboutDevBuild.
  ///
  /// In en, this message translates to:
  /// **'Development build: update checks are off.'**
  String get aboutDevBuild;

  /// No description provided for @aboutUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date.'**
  String get aboutUpToDate;

  /// No description provided for @aboutDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get aboutDownload;

  /// No description provided for @aboutCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get aboutCheckNow;

  /// No description provided for @aboutDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get aboutDismiss;

  /// No description provided for @aboutAutoCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get aboutAutoCheck;

  /// No description provided for @aboutAutoCheckDescription.
  ///
  /// In en, this message translates to:
  /// **'Once a day, OpenChroma asks GitHub for the latest release. Nothing about your PC is sent.'**
  String get aboutAutoCheckDescription;

  /// No description provided for @aboutReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get aboutReportProblem;

  /// No description provided for @aboutReportProblemDescription.
  ///
  /// In en, this message translates to:
  /// **'Copy a diagnostics summary (app and Windows version, devices and errors; no serial numbers) and paste it into a GitHub issue.'**
  String get aboutReportProblemDescription;

  /// No description provided for @aboutCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get aboutCopyDiagnostics;

  /// No description provided for @aboutDiagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied to the clipboard.'**
  String get aboutDiagnosticsCopied;

  /// No description provided for @aboutOpenIssue.
  ///
  /// In en, this message translates to:
  /// **'Open an issue'**
  String get aboutOpenIssue;

  /// No description provided for @fansTitle.
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get fansTitle;

  /// No description provided for @fansProfileSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get fansProfileSilent;

  /// No description provided for @fansProfileBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get fansProfileBalanced;

  /// No description provided for @fansProfileTurbo.
  ///
  /// In en, this message translates to:
  /// **'Turbo'**
  String get fansProfileTurbo;

  /// No description provided for @fansProfileCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get fansProfileCustom;

  /// No description provided for @fansConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get fansConnected;

  /// No description provided for @fansHideEmpty.
  ///
  /// In en, this message translates to:
  /// **'Hide empty'**
  String get fansHideEmpty;

  /// No description provided for @fansShowEmpty.
  ///
  /// In en, this message translates to:
  /// **'Show empty ({count})'**
  String fansShowEmpty(int count);

  /// No description provided for @fansConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'{program} is open.'**
  String fansConflictTitle(String program);

  /// No description provided for @fansConflictText.
  ///
  /// In en, this message translates to:
  /// **'Two programs on the same fans fight over the speed. Close it, including from the tray, to control them here.'**
  String get fansConflictText;

  /// No description provided for @fansAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator mode'**
  String get fansAdminTitle;

  /// No description provided for @fansAdminText.
  ///
  /// In en, this message translates to:
  /// **'is needed to control fans and see the motherboard ones.'**
  String get fansAdminText;

  /// No description provided for @fansRestartAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Restart as administrator'**
  String get fansRestartAsAdmin;

  /// No description provided for @fansInstallPawnIoTitle.
  ///
  /// In en, this message translates to:
  /// **'Install PawnIO'**
  String get fansInstallPawnIoTitle;

  /// No description provided for @fansInstallPawnIoText.
  ///
  /// In en, this message translates to:
  /// **'to see the motherboard fans.'**
  String get fansInstallPawnIoText;

  /// No description provided for @fansDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get fansDownload;

  /// No description provided for @fansBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'The motherboard was busy'**
  String get fansBusyTitle;

  /// No description provided for @fansBusyText.
  ///
  /// In en, this message translates to:
  /// **'with another program. Reopen OpenChroma to try again.'**
  String get fansBusyText;

  /// No description provided for @fansPumpQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Have a water cooler?'**
  String get fansPumpQuestionTitle;

  /// No description provided for @fansPumpQuestionText.
  ///
  /// In en, this message translates to:
  /// **'Tap the pump to protect it: it never drops below 70% or stops.'**
  String get fansPumpQuestionText;

  /// No description provided for @fansPumpNone.
  ///
  /// In en, this message translates to:
  /// **'I don\'t have one'**
  String get fansPumpNone;

  /// No description provided for @fansCurveTitle.
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get fansCurveTitle;

  /// No description provided for @fansCpuTempNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature needs administrator mode'**
  String get fansCpuTempNeedsAdmin;

  /// No description provided for @fansSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for fans…'**
  String get fansSearching;

  /// No description provided for @fansNone.
  ///
  /// In en, this message translates to:
  /// **'No fans'**
  String get fansNone;

  /// No description provided for @fansNoTempDriver.
  ///
  /// In en, this message translates to:
  /// **'No temperature · driver in control'**
  String get fansNoTempDriver;

  /// No description provided for @fansNoTempBios.
  ///
  /// In en, this message translates to:
  /// **'No temperature · BIOS in control'**
  String get fansNoTempBios;

  /// No description provided for @fansModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get fansModeAuto;

  /// No description provided for @fansModeCurve.
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get fansModeCurve;

  /// No description provided for @fansModeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get fansModeFixed;

  /// No description provided for @fansMotherboardDevice.
  ///
  /// In en, this message translates to:
  /// **'Motherboard · {device}'**
  String fansMotherboardDevice(String device);

  /// No description provided for @fansStopWhenCold.
  ///
  /// In en, this message translates to:
  /// **'Stop when cold'**
  String get fansStopWhenCold;

  /// No description provided for @fansPumpToggle.
  ///
  /// In en, this message translates to:
  /// **'Water cooler pump'**
  String get fansPumpToggle;

  /// No description provided for @fansBlockedConflict.
  ///
  /// In en, this message translates to:
  /// **'{program} is open'**
  String fansBlockedConflict(String program);

  /// No description provided for @fansBlockedNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Controlling needs administrator mode'**
  String get fansBlockedNeedsAdmin;

  /// No description provided for @fansBlockedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get fansBlockedReadOnly;

  /// No description provided for @fansDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Fan {index}'**
  String fansDefaultName(int index);

  /// No description provided for @effectsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get effectsFilterAll;

  /// No description provided for @effectsFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get effectsFilterFavorites;

  /// No description provided for @effectsFilterAudio.
  ///
  /// In en, this message translates to:
  /// **'Sound-reactive'**
  String get effectsFilterAudio;

  /// No description provided for @effectsFilterImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get effectsFilterImported;

  /// No description provided for @effectsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search effects'**
  String get effectsSearchHint;

  /// No description provided for @effectsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get effectsImport;

  /// No description provided for @effectsEmptyFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get effectsEmptyFavoritesTitle;

  /// No description provided for @effectsEmptyFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'Hover over an effect and click the star to keep it here.'**
  String get effectsEmptyFavoritesMessage;

  /// No description provided for @effectsEmptyImportedTitle.
  ///
  /// In en, this message translates to:
  /// **'No imported effects'**
  String get effectsEmptyImportedTitle;

  /// No description provided for @effectsEmptyImportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Create an .ocfx effect or bring an .html file.'**
  String get effectsEmptyImportedMessage;

  /// No description provided for @effectsImportEffect.
  ///
  /// In en, this message translates to:
  /// **'Import effect'**
  String get effectsImportEffect;

  /// No description provided for @effectsNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get effectsNotFoundTitle;

  /// No description provided for @effectsNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get effectsNotFoundMessage;

  /// No description provided for @effectsReactsToSound.
  ///
  /// In en, this message translates to:
  /// **'Reacts to sound'**
  String get effectsReactsToSound;

  /// No description provided for @effectsRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get effectsRemoveFavorite;

  /// No description provided for @effectsAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get effectsAddFavorite;

  /// No description provided for @effectsLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get effectsLive;

  /// No description provided for @effectsRemoveImported.
  ///
  /// In en, this message translates to:
  /// **'Remove imported effect'**
  String get effectsRemoveImported;

  /// No description provided for @effectsByAuthor.
  ///
  /// In en, this message translates to:
  /// **'by {author}'**
  String effectsByAuthor(String author);

  /// No description provided for @effectsAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get effectsAdjustments;

  /// No description provided for @effectsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get effectsReset;

  /// No description provided for @effectsNoAdjustments.
  ///
  /// In en, this message translates to:
  /// **'This effect has no adjustments.'**
  String get effectsNoAdjustments;

  /// No description provided for @effectsRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\"?'**
  String effectsRemoveTitle(String title);

  /// No description provided for @effectsRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'The effect is removed from the library. The original file you imported is not deleted.'**
  String get effectsRemoveMessage;

  /// No description provided for @effectsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get effectsCancel;

  /// No description provided for @effectsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get effectsRemove;

  /// No description provided for @effectsFileTypeEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get effectsFileTypeEffects;

  /// No description provided for @effectsFileTypeOpenChroma.
  ///
  /// In en, this message translates to:
  /// **'OpenChroma effect'**
  String get effectsFileTypeOpenChroma;

  /// No description provided for @effectsTemplateFileName.
  ///
  /// In en, this message translates to:
  /// **'my-effect.ocfx'**
  String get effectsTemplateFileName;

  /// No description provided for @effectsTemplateName.
  ///
  /// In en, this message translates to:
  /// **'My effect'**
  String get effectsTemplateName;

  /// No description provided for @effectsTemplateDescription.
  ///
  /// In en, this message translates to:
  /// **'A short sentence about the effect.'**
  String get effectsTemplateDescription;

  /// No description provided for @effectsTemplateAuthor.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get effectsTemplateAuthor;

  /// No description provided for @effectsTemplateSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get effectsTemplateSpeed;

  /// No description provided for @effectsTemplateColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get effectsTemplateColor;

  /// No description provided for @effectsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import: {error}'**
  String effectsImportFailed(String error);

  /// No description provided for @effectsImportIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring an .ocfx effect, OpenChroma\'s format, or an .html page that draws on a 320×200 canvas.'**
  String get effectsImportIntro;

  /// No description provided for @effectsFormatLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get effectsFormatLayers;

  /// No description provided for @effectsFormatLayersText.
  ///
  /// In en, this message translates to:
  /// **'gradient, spectrum, wave, pulse, sweep, rings, sparkle and solid, stacked with normal, screen, add, multiply or overlay blending.'**
  String get effectsFormatLayersText;

  /// No description provided for @effectsFormatParams.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get effectsFormatParams;

  /// No description provided for @effectsFormatParamsText.
  ///
  /// In en, this message translates to:
  /// **'Declare them in \"params\" and use them as \"\$name\" in any layer. They become controls in the app.'**
  String get effectsFormatParamsText;

  /// No description provided for @effectsTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved to {path}'**
  String effectsTemplateSaved(String path);

  /// No description provided for @effectsSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get effectsSaveTemplate;

  /// No description provided for @effectsChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get effectsChooseFile;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get settingsLighting;

  /// No description provided for @settingsBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get settingsBrightness;

  /// No description provided for @settingsEffectAudio.
  ///
  /// In en, this message translates to:
  /// **'Effect audio'**
  String get settingsEffectAudio;

  /// No description provided for @settingsAudioUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable in this build.'**
  String get settingsAudioUnavailable;

  /// No description provided for @settingsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsLibrary;

  /// No description provided for @settingsDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get settingsDevices;

  /// No description provided for @settingsDevicesConnected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 connected} other{{count} connected}}'**
  String settingsDevicesConnected(int count);

  /// No description provided for @settingsScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get settingsScan;

  /// No description provided for @settingsEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get settingsEffects;

  /// No description provided for @settingsEffectsInLibrary.
  ///
  /// In en, this message translates to:
  /// **'{count} in the library'**
  String settingsEffectsInLibrary(int count);

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImport;

  /// No description provided for @settingsPlugins.
  ///
  /// In en, this message translates to:
  /// **'Device plugins'**
  String get settingsPlugins;

  /// No description provided for @settingsPluginsLoaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 loaded} other{{count} loaded}}. New or changed .js files in the folder run only after you approve them.'**
  String settingsPluginsLoaded(int count);

  /// No description provided for @settingsReloadPlugins.
  ///
  /// In en, this message translates to:
  /// **'Reload plugins'**
  String get settingsReloadPlugins;

  /// No description provided for @settingsOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get settingsOpenFolder;

  /// No description provided for @settingsDataFolder.
  ///
  /// In en, this message translates to:
  /// **'Data folder'**
  String get settingsDataFolder;

  /// No description provided for @settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsOpen;

  /// No description provided for @settingsAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get settingsAlerts;

  /// No description provided for @settingsWindowsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Windows notifications'**
  String get settingsWindowsNotifications;

  /// No description provided for @settingsWindowsNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Warns you when something gets too hot, memory or disk fills up, or the water cooler pump stops, even with the app in the tray.'**
  String get settingsWindowsNotificationsDescription;

  /// No description provided for @settingsFlashLeds.
  ///
  /// In en, this message translates to:
  /// **'Flash the LEDs red'**
  String get settingsFlashLeds;

  /// No description provided for @settingsFlashLedsDescription.
  ///
  /// In en, this message translates to:
  /// **'Devices flash for a few seconds along with the alert.'**
  String get settingsFlashLedsDescription;

  /// No description provided for @settingsAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get settingsAiAssistant;

  /// No description provided for @settingsAiKeyNote.
  ///
  /// In en, this message translates to:
  /// **'The key stays only on this PC, encrypted for your Windows user, and is only sent to the chosen provider. When you ask something, the provider also receives your PC\'s readings: hardware model, temperatures, usage, device names and the names of the heaviest processes.'**
  String get settingsAiKeyNote;

  /// No description provided for @settingsStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup and permissions'**
  String get settingsStartup;

  /// No description provided for @settingsAdminMode.
  ///
  /// In en, this message translates to:
  /// **'Administrator mode'**
  String get settingsAdminMode;

  /// No description provided for @settingsAdminActive.
  ///
  /// In en, this message translates to:
  /// **'Active. CPU temperature shows up in Monitor.'**
  String get settingsAdminActive;

  /// No description provided for @settingsAdminInactive.
  ///
  /// In en, this message translates to:
  /// **'Off. Required to read the CPU temperature.'**
  String get settingsAdminInactive;

  /// No description provided for @settingsAdminAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'Already active'**
  String get settingsAdminAlreadyActive;

  /// No description provided for @settingsRestartAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Restart as administrator'**
  String get settingsRestartAsAdmin;

  /// No description provided for @settingsAlwaysAdmin.
  ///
  /// In en, this message translates to:
  /// **'Always open as administrator'**
  String get settingsAlwaysAdmin;

  /// No description provided for @settingsAlwaysAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Windows asks for permission (UAC) every time OpenChroma opens.'**
  String get settingsAlwaysAdminDescription;

  /// No description provided for @settingsStartWithWindows.
  ///
  /// In en, this message translates to:
  /// **'Open at PC startup'**
  String get settingsStartWithWindows;

  /// No description provided for @settingsStartWithWindowsAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Opens in the tray, as administrator, when you sign in to Windows, without asking for permission. Turning it on or off asks for UAC once.'**
  String get settingsStartWithWindowsAdminDescription;

  /// No description provided for @settingsStartWithWindowsDescription.
  ///
  /// In en, this message translates to:
  /// **'Opens in the tray along with Windows.'**
  String get settingsStartWithWindowsDescription;

  /// No description provided for @settingsRunInBackground.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the background'**
  String get settingsRunInBackground;

  /// No description provided for @settingsRunInBackgroundDescription.
  ///
  /// In en, this message translates to:
  /// **'When you close the window, OpenChroma stays in the tray and keeps controlling lights and fans.'**
  String get settingsRunInBackgroundDescription;

  /// No description provided for @aiProviderCompatible.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible'**
  String get aiProviderCompatible;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get aiProvider;

  /// No description provided for @aiApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get aiApiKey;

  /// No description provided for @aiKeyHintAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Create one at console.anthropic.com.'**
  String get aiKeyHintAnthropic;

  /// No description provided for @aiKeyHintOpenai.
  ///
  /// In en, this message translates to:
  /// **'Create one at platform.openai.com.'**
  String get aiKeyHintOpenai;

  /// No description provided for @aiKeyHintCompatible.
  ///
  /// In en, this message translates to:
  /// **'Optional for local servers (Ollama, LM Studio).'**
  String get aiKeyHintCompatible;

  /// No description provided for @aiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API address'**
  String get aiBaseUrl;

  /// No description provided for @aiBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. https://openrouter.ai/api/v1, http://localhost:11434/v1 (Ollama).'**
  String get aiBaseUrlHint;

  /// No description provided for @aiModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get aiModel;

  /// No description provided for @aiModelsLoading.
  ///
  /// In en, this message translates to:
  /// **'Fetching the available models…'**
  String get aiModelsLoading;

  /// No description provided for @aiModelsNeedKey.
  ///
  /// In en, this message translates to:
  /// **'Enter the key to see the models.'**
  String get aiModelsNeedKey;

  /// No description provided for @aiModelsNone.
  ///
  /// In en, this message translates to:
  /// **'No models found.'**
  String get aiModelsNone;

  /// No description provided for @aiModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available, updated automatically.'**
  String aiModelsAvailable(int count);

  /// No description provided for @aiRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get aiRefreshList;

  /// No description provided for @aiPasteKey.
  ///
  /// In en, this message translates to:
  /// **'Paste the key here'**
  String get aiPasteKey;

  /// No description provided for @aiHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get aiHide;

  /// No description provided for @aiShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get aiShow;

  /// No description provided for @aiErrorListModels.
  ///
  /// In en, this message translates to:
  /// **'Could not list the models ({error}).'**
  String aiErrorListModels(String error);

  /// No description provided for @aiErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond.'**
  String get aiErrorTimeout;

  /// No description provided for @aiErrorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {host} ({message}).'**
  String aiErrorNoConnection(String host, String message);

  /// No description provided for @aiErrorSecureConnection.
  ///
  /// In en, this message translates to:
  /// **'Secure connection to {host} failed.'**
  String aiErrorSecureConnection(String host);

  /// No description provided for @aiErrorUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from the server.'**
  String get aiErrorUnexpectedResponse;

  /// No description provided for @aiErrorInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid API key or missing permission.'**
  String get aiErrorInvalidKey;

  /// No description provided for @aiErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Address or model not found.'**
  String get aiErrorNotFound;

  /// No description provided for @aiErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Usage limit reached. Try again in a moment.'**
  String get aiErrorRateLimit;

  /// No description provided for @aiErrorProviderUnstable.
  ///
  /// In en, this message translates to:
  /// **'The provider is unstable right now ({status}).'**
  String aiErrorProviderUnstable(int status);

  /// No description provided for @aiErrorStatus.
  ///
  /// In en, this message translates to:
  /// **'Error {status}.'**
  String aiErrorStatus(int status);

  /// No description provided for @aiErrorNoKey.
  ///
  /// In en, this message translates to:
  /// **'Set an API key in Settings.'**
  String get aiErrorNoKey;

  /// No description provided for @aiErrorNoModel.
  ///
  /// In en, this message translates to:
  /// **'Pick a model in Settings.'**
  String get aiErrorNoModel;

  /// No description provided for @aiErrorRefused.
  ///
  /// In en, this message translates to:
  /// **'The model declined this request.'**
  String get aiErrorRefused;

  /// No description provided for @aiErrorEmptyReply.
  ///
  /// In en, this message translates to:
  /// **'The model returned nothing.'**
  String get aiErrorEmptyReply;

  /// No description provided for @aiEffectDone.
  ///
  /// In en, this message translates to:
  /// **'Done, I made the effect.'**
  String get aiEffectDone;

  /// No description provided for @alertsTempWarm.
  ///
  /// In en, this message translates to:
  /// **'{what} hot'**
  String alertsTempWarm(String what);

  /// No description provided for @alertsTempHot.
  ///
  /// In en, this message translates to:
  /// **'{what} very hot'**
  String alertsTempHot(String what);

  /// No description provided for @alertsTempNow.
  ///
  /// In en, this message translates to:
  /// **'{temp} °C right now'**
  String alertsTempNow(String temp);

  /// No description provided for @alertsDiskFallback.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get alertsDiskFallback;

  /// No description provided for @alertsMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory almost full'**
  String get alertsMemoryTitle;

  /// No description provided for @alertsMemoryDetail.
  ///
  /// In en, this message translates to:
  /// **'{percent}% in use · {free} free'**
  String alertsMemoryDetail(String percent, String free);

  /// No description provided for @alertsVolumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Drive {letter}: almost full'**
  String alertsVolumeTitle(String letter);

  /// No description provided for @alertsVolumeDetail.
  ///
  /// In en, this message translates to:
  /// **'{free} free of {total}'**
  String alertsVolumeDetail(String free, String total);

  /// No description provided for @alertsPumpTitle.
  ///
  /// In en, this message translates to:
  /// **'Water cooler pump stopped'**
  String get alertsPumpTitle;

  /// No description provided for @alertsPumpDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} at {rpm} RPM'**
  String alertsPumpDetail(String name, int rpm);

  /// No description provided for @audioSourceOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get audioSourceOff;

  /// No description provided for @audioSourceSystem.
  ///
  /// In en, this message translates to:
  /// **'PC sound'**
  String get audioSourceSystem;

  /// No description provided for @audioSourceMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get audioSourceMicrophone;

  /// No description provided for @audioSourceBoth.
  ///
  /// In en, this message translates to:
  /// **'PC sound and microphone'**
  String get audioSourceBoth;

  /// No description provided for @profileAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on \"{profile}\" with programs'**
  String profileAppsTitle(String profile);

  /// No description provided for @profileAppsDescription.
  ///
  /// In en, this message translates to:
  /// **'When one of these programs opens, the profile turns on by itself. When it closes, your previous lighting comes back, unless you picked another one in the meantime.'**
  String get profileAppsDescription;

  /// No description provided for @profileAppsNone.
  ///
  /// In en, this message translates to:
  /// **'No programs yet.'**
  String get profileAppsNone;

  /// No description provided for @profileAppsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profileAppsRemove;

  /// No description provided for @profileAppsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Program name, e.g. cs2.exe'**
  String get profileAppsNameHint;

  /// No description provided for @profileAppsOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get profileAppsOpenNow;

  /// No description provided for @profileAppsNoOthers.
  ///
  /// In en, this message translates to:
  /// **'No other program with an open window.'**
  String get profileAppsNoOthers;

  /// No description provided for @profileAppsBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse for .exe'**
  String get profileAppsBrowse;

  /// No description provided for @profileAppsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileAppsCancel;

  /// No description provided for @profileAppsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileAppsSave;

  /// No description provided for @profileAppsFileTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get profileAppsFileTypeLabel;

  /// No description provided for @aiErrorInsecureUrl.
  ///
  /// In en, this message translates to:
  /// **'Only HTTPS addresses are allowed for {host}. Plain HTTP is accepted only for servers on this PC (localhost).'**
  String aiErrorInsecureUrl(String host);

  /// No description provided for @settingsManagePlugins.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get settingsManagePlugins;

  /// No description provided for @ocfxErrorInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The file isn\'t valid JSON ({message}).'**
  String ocfxErrorInvalidJson(String message);

  /// No description provided for @ocfxErrorNotObject.
  ///
  /// In en, this message translates to:
  /// **'The file must be a JSON object.'**
  String get ocfxErrorNotObject;

  /// No description provided for @ocfxErrorMissingVersion.
  ///
  /// In en, this message translates to:
  /// **'The \"openchroma\": 1 field is missing.'**
  String get ocfxErrorMissingVersion;

  /// No description provided for @ocfxErrorMissingName.
  ///
  /// In en, this message translates to:
  /// **'The \"name\" field is missing.'**
  String get ocfxErrorMissingName;

  /// No description provided for @ocfxErrorNoLayers.
  ///
  /// In en, this message translates to:
  /// **'The effect needs at least one layer in \"layers\".'**
  String get ocfxErrorNoLayers;

  /// No description provided for @ocfxErrorLayerType.
  ///
  /// In en, this message translates to:
  /// **'Layer {index}: \"type\" must be one of: {types}.'**
  String ocfxErrorLayerType(int index, String types);

  /// No description provided for @ocfxErrorParamsNotObject.
  ///
  /// In en, this message translates to:
  /// **'\"params\" must be an object.'**
  String get ocfxErrorParamsNotObject;

  /// No description provided for @ocfxErrorParamType.
  ///
  /// In en, this message translates to:
  /// **'Parameter \"{key}\": \"type\" must be one of: {types}.'**
  String ocfxErrorParamType(String key, String types);

  /// No description provided for @ocfxErrorI18nNotObject.
  ///
  /// In en, this message translates to:
  /// **'\"i18n\" must be an object with one object per language.'**
  String get ocfxErrorI18nNotObject;

  /// No description provided for @paramColorPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get paramColorPickerTitle;

  /// No description provided for @paramColorPickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get paramColorPickerCancel;

  /// No description provided for @paramColorPickerApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get paramColorPickerApply;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenChroma'**
  String get appTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get languagePortuguese;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @colorOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Color order · {header}'**
  String colorOrderTitle(String header);

  /// No description provided for @colorOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'What color are the fans on this connector showing right now?'**
  String get colorOrderQuestion;

  /// No description provided for @colorOrderBlueTitle.
  ///
  /// In en, this message translates to:
  /// **'Is it blue?'**
  String get colorOrderBlueTitle;

  /// No description provided for @colorOrderTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing order {order}.'**
  String colorOrderTesting(String order);

  /// No description provided for @colorOrderDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get colorOrderDoneTitle;

  /// No description provided for @colorOrderFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work'**
  String get colorOrderFailedTitle;

  /// No description provided for @colorOrderNothingLit.
  ///
  /// In en, this message translates to:
  /// **'If nothing lit up, check the LED count of {header} and that the fans are on this connector.'**
  String colorOrderNothingLit(String header);

  /// No description provided for @colorOrderAlreadyRight.
  ///
  /// In en, this message translates to:
  /// **'The order was already correct ({order}).'**
  String colorOrderAlreadyRight(String order);

  /// No description provided for @colorOrderSameColors.
  ///
  /// In en, this message translates to:
  /// **'Both colors looked the same. Try again.'**
  String get colorOrderSameColors;

  /// No description provided for @colorOrderCouldNotFix.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fix it automatically. Pick the order manually from the list.'**
  String get colorOrderCouldNotFix;

  /// No description provided for @colorOrderSaved.
  ///
  /// In en, this message translates to:
  /// **'Order {order} saved on {header}.'**
  String colorOrderSaved(String order, String header);

  /// No description provided for @colorOrderNothingLitButton.
  ///
  /// In en, this message translates to:
  /// **'Nothing lit up'**
  String get colorOrderNothingLitButton;

  /// No description provided for @colorOrderRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorOrderRed;

  /// No description provided for @colorOrderGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorOrderGreen;

  /// No description provided for @colorOrderBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorOrderBlue;

  /// No description provided for @colorOrderNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get colorOrderNo;

  /// No description provided for @colorOrderYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get colorOrderYes;

  /// No description provided for @colorOrderClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get colorOrderClose;

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTitle;

  /// No description provided for @devicesScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get devicesScanning;

  /// No description provided for @devicesConnectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 connected} other{{count} connected}}'**
  String devicesConnectedCount(int count);

  /// No description provided for @devicesScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get devicesScan;

  /// No description provided for @devicesOtherWireless.
  ///
  /// In en, this message translates to:
  /// **'Other wireless'**
  String get devicesOtherWireless;

  /// No description provided for @devicesScanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices'**
  String get devicesScanningTitle;

  /// No description provided for @devicesDriversUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Drivers unavailable'**
  String get devicesDriversUnavailable;

  /// No description provided for @devicesNone.
  ///
  /// In en, this message translates to:
  /// **'No devices'**
  String get devicesNone;

  /// No description provided for @devicesScanTakesSeconds.
  ///
  /// In en, this message translates to:
  /// **'This takes a few seconds.'**
  String get devicesScanTakesSeconds;

  /// No description provided for @devicesDriversMissing.
  ///
  /// In en, this message translates to:
  /// **'The drivers weren\'t found in this installation. Reinstall OpenChroma.'**
  String get devicesDriversMissing;

  /// No description provided for @devicesNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Connect a compatible device. If another RGB program is open, close it first. Memory modules and graphics cards need administrator mode and PawnIO.'**
  String get devicesNoneHint;

  /// No description provided for @devicesScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get devicesScanAgain;

  /// No description provided for @devicesStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get devicesStatusConnected;

  /// No description provided for @devicesStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get devicesStatusStarting;

  /// No description provided for @devicesStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get devicesStatusError;

  /// No description provided for @devicesStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get devicesStatusDisabled;

  /// No description provided for @devicesStatusUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get devicesStatusUnsupported;

  /// No description provided for @devicesStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get devicesStatusStopped;

  /// No description provided for @devicesKindKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get devicesKindKeyboard;

  /// No description provided for @devicesKindMouse.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get devicesKindMouse;

  /// No description provided for @devicesKindHeadset.
  ///
  /// In en, this message translates to:
  /// **'Headset'**
  String get devicesKindHeadset;

  /// No description provided for @devicesKindMousepad.
  ///
  /// In en, this message translates to:
  /// **'Mousepad'**
  String get devicesKindMousepad;

  /// No description provided for @devicesKindMotherboard.
  ///
  /// In en, this message translates to:
  /// **'Motherboard'**
  String get devicesKindMotherboard;

  /// No description provided for @devicesKindGpu.
  ///
  /// In en, this message translates to:
  /// **'Graphics card'**
  String get devicesKindGpu;

  /// No description provided for @devicesKindRam.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get devicesKindRam;

  /// No description provided for @devicesKindFan.
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get devicesKindFan;

  /// No description provided for @devicesKindCooler.
  ///
  /// In en, this message translates to:
  /// **'Water cooler'**
  String get devicesKindCooler;

  /// No description provided for @devicesKindController.
  ///
  /// In en, this message translates to:
  /// **'RGB controller'**
  String get devicesKindController;

  /// No description provided for @devicesKindStrip.
  ///
  /// In en, this message translates to:
  /// **'LED strip'**
  String get devicesKindStrip;

  /// No description provided for @devicesKindSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get devicesKindSpeakers;

  /// No description provided for @devicesKindMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get devicesKindMicrophone;

  /// No description provided for @devicesKindGamepad.
  ///
  /// In en, this message translates to:
  /// **'Gamepad'**
  String get devicesKindGamepad;

  /// No description provided for @devicesKindCase.
  ///
  /// In en, this message translates to:
  /// **'PC case'**
  String get devicesKindCase;

  /// No description provided for @devicesKindOther.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get devicesKindOther;

  /// No description provided for @devicesLedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 LED} other{{count} LEDs}}'**
  String devicesLedCount(int count);

  /// No description provided for @devicesCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging · {level}%'**
  String devicesCharging(int level);

  /// No description provided for @devicesBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery {level}%'**
  String devicesBattery(int level);

  /// No description provided for @devicesRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get devicesRestoreDefaults;

  /// No description provided for @devicesEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get devicesEnable;

  /// No description provided for @devicesDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get devicesDisable;

  /// No description provided for @devicesTabLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get devicesTabLighting;

  /// No description provided for @devicesTabScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get devicesTabScreen;

  /// No description provided for @devicesTabDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get devicesTabDetails;

  /// No description provided for @devicesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get devicesOff;

  /// No description provided for @devicesModeStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get devicesModeStatic;

  /// No description provided for @devicesModeBreathing.
  ///
  /// In en, this message translates to:
  /// **'Breathing'**
  String get devicesModeBreathing;

  /// No description provided for @devicesModeBlinking.
  ///
  /// In en, this message translates to:
  /// **'Blinking'**
  String get devicesModeBlinking;

  /// No description provided for @devicesModeFlashing.
  ///
  /// In en, this message translates to:
  /// **'Flashing'**
  String get devicesModeFlashing;

  /// No description provided for @devicesModeColorCycle.
  ///
  /// In en, this message translates to:
  /// **'Color cycle'**
  String get devicesModeColorCycle;

  /// No description provided for @devicesModeSpectrumCycle.
  ///
  /// In en, this message translates to:
  /// **'Spectrum cycle'**
  String get devicesModeSpectrumCycle;

  /// No description provided for @devicesModeRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get devicesModeRainbow;

  /// No description provided for @devicesModeRainbowWave.
  ///
  /// In en, this message translates to:
  /// **'Rainbow wave'**
  String get devicesModeRainbowWave;

  /// No description provided for @devicesModeWave.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get devicesModeWave;

  /// No description provided for @devicesModeColorWave.
  ///
  /// In en, this message translates to:
  /// **'Color wave'**
  String get devicesModeColorWave;

  /// No description provided for @devicesModeReactive.
  ///
  /// In en, this message translates to:
  /// **'Reactive'**
  String get devicesModeReactive;

  /// No description provided for @devicesModeRipple.
  ///
  /// In en, this message translates to:
  /// **'Ripple'**
  String get devicesModeRipple;

  /// No description provided for @devicesModeStarlight.
  ///
  /// In en, this message translates to:
  /// **'Starlight'**
  String get devicesModeStarlight;

  /// No description provided for @devicesModeRandomFlicker.
  ///
  /// In en, this message translates to:
  /// **'Random flicker'**
  String get devicesModeRandomFlicker;

  /// No description provided for @devicesModeDoubleFlash.
  ///
  /// In en, this message translates to:
  /// **'Double flash'**
  String get devicesModeDoubleFlash;

  /// No description provided for @devicesModeSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get devicesModeSpectrum;

  /// No description provided for @devicesModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get devicesModeCustom;

  /// No description provided for @devicesModeRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get devicesModeRandom;

  /// No description provided for @devicesDirLeft.
  ///
  /// In en, this message translates to:
  /// **'To the left'**
  String get devicesDirLeft;

  /// No description provided for @devicesDirRight.
  ///
  /// In en, this message translates to:
  /// **'To the right'**
  String get devicesDirRight;

  /// No description provided for @devicesDirUp.
  ///
  /// In en, this message translates to:
  /// **'Upward'**
  String get devicesDirUp;

  /// No description provided for @devicesDirDown.
  ///
  /// In en, this message translates to:
  /// **'Downward'**
  String get devicesDirDown;

  /// No description provided for @devicesDirHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get devicesDirHorizontal;

  /// No description provided for @devicesDirVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get devicesDirVertical;

  /// No description provided for @devicesDirUpLeft.
  ///
  /// In en, this message translates to:
  /// **'Upward and left'**
  String get devicesDirUpLeft;

  /// No description provided for @devicesDirUpRight.
  ///
  /// In en, this message translates to:
  /// **'Upward and right'**
  String get devicesDirUpRight;

  /// No description provided for @devicesDirDownLeft.
  ///
  /// In en, this message translates to:
  /// **'Downward and left'**
  String get devicesDirDownLeft;

  /// No description provided for @devicesDirDownRight.
  ///
  /// In en, this message translates to:
  /// **'Downward and right'**
  String get devicesDirDownRight;

  /// No description provided for @devicesSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get devicesSpeed;

  /// No description provided for @devicesBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get devicesBrightness;

  /// No description provided for @devicesDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get devicesDirection;

  /// No description provided for @devicesRandomColors.
  ///
  /// In en, this message translates to:
  /// **'Random colors'**
  String get devicesRandomColors;

  /// No description provided for @devicesColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get devicesColor;

  /// No description provided for @devicesColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get devicesColors;

  /// No description provided for @devicesRemoveColor.
  ///
  /// In en, this message translates to:
  /// **'Remove a color'**
  String get devicesRemoveColor;

  /// No description provided for @devicesAddColor.
  ///
  /// In en, this message translates to:
  /// **'Add a color'**
  String get devicesAddColor;

  /// No description provided for @devicesLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get devicesLighting;

  /// No description provided for @devicesFollowsApp.
  ///
  /// In en, this message translates to:
  /// **'Follows OpenChroma effects.'**
  String get devicesFollowsApp;

  /// No description provided for @devicesRunsItself.
  ///
  /// In en, this message translates to:
  /// **'The device runs the effect itself.'**
  String get devicesRunsItself;

  /// No description provided for @devicesAppEffects.
  ///
  /// In en, this message translates to:
  /// **'OpenChroma effects'**
  String get devicesAppEffects;

  /// No description provided for @devicesZonesWithoutLeds.
  ///
  /// In en, this message translates to:
  /// **'{zones} without LEDs: whatever is plugged into those connectors doesn\'t follow the effects and stays on the previous effect. Enter the LED count below.'**
  String devicesZonesWithoutLeds(String zones);

  /// No description provided for @devicesArgbHint.
  ///
  /// In en, this message translates to:
  /// **'On ARGB connectors, enter how many LEDs are plugged in. A 120 mm fan usually has between 8 and 24. Then position each zone in Lighting › Layout.'**
  String get devicesArgbHint;

  /// No description provided for @devicesZoneN.
  ///
  /// In en, this message translates to:
  /// **'Zone {n}'**
  String devicesZoneN(int n);

  /// No description provided for @devicesUpToLeds.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} LEDs'**
  String devicesUpToLeds(int max);

  /// No description provided for @devicesMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix {width} × {height}'**
  String devicesMatrix(int width, int height);

  /// No description provided for @devicesCountLeds.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get devicesCountLeds;

  /// No description provided for @devicesCountLedsTitle.
  ///
  /// In en, this message translates to:
  /// **'Count LEDs of {zone}'**
  String devicesCountLedsTitle(String zone);

  /// No description provided for @devicesCountLedsHint.
  ///
  /// In en, this message translates to:
  /// **'The first LEDs light up green. Increase the count until the last fan or strip is fully lit, and stop at the point where lighting one more changes nothing.'**
  String get devicesCountLedsHint;

  /// No description provided for @devicesOneLess.
  ///
  /// In en, this message translates to:
  /// **'One less'**
  String get devicesOneLess;

  /// No description provided for @devicesOneMore.
  ///
  /// In en, this message translates to:
  /// **'One more'**
  String get devicesOneMore;

  /// No description provided for @devicesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devicesCancel;

  /// No description provided for @devicesUseLeds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use 1 LED} other{Use {count} LEDs}}'**
  String devicesUseLeds(int count);

  /// No description provided for @devicesInfoVendor.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get devicesInfoVendor;

  /// No description provided for @devicesInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get devicesInfoDescription;

  /// No description provided for @devicesInfoVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get devicesInfoVersion;

  /// No description provided for @devicesInfoSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get devicesInfoSerial;

  /// No description provided for @devicesInfoDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get devicesInfoDriver;

  /// No description provided for @devicesDriverBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'OpenRGB (included)'**
  String get devicesDriverBuiltIn;

  /// No description provided for @devicesDriverPluginBundled.
  ///
  /// In en, this message translates to:
  /// **'{name} · bundled plugin'**
  String devicesDriverPluginBundled(String name);

  /// No description provided for @devicesDriverPluginUser.
  ///
  /// In en, this message translates to:
  /// **'{name} · your plugin'**
  String devicesDriverPluginUser(String name);

  /// No description provided for @devicesInfoConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get devicesInfoConnection;

  /// No description provided for @devicesInfoZones.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get devicesInfoZones;

  /// No description provided for @devicesInfoHardwareModes.
  ///
  /// In en, this message translates to:
  /// **'Hardware modes'**
  String get devicesInfoHardwareModes;

  /// No description provided for @devicesColorOrderOption.
  ///
  /// In en, this message translates to:
  /// **'Color order · {what}'**
  String devicesColorOrderOption(String what);

  /// No description provided for @devicesBoardLedC.
  ///
  /// In en, this message translates to:
  /// **'board LED_C'**
  String get devicesBoardLedC;

  /// No description provided for @devicesDetectGen2.
  ///
  /// In en, this message translates to:
  /// **'Detect ARGB Gen2 · {name}'**
  String devicesDetectGen2(String name);

  /// No description provided for @devicesPersistLighting.
  ///
  /// In en, this message translates to:
  /// **'Save lighting on exit'**
  String get devicesPersistLighting;

  /// No description provided for @devicesCalibrationHint.
  ///
  /// In en, this message translates to:
  /// **'If the color comes out swapped (e.g. green instead of blue), use \"Detect\": two questions and the app finds the right order.'**
  String get devicesCalibrationHint;

  /// No description provided for @devicesDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get devicesDetect;

  /// No description provided for @devicesResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults?'**
  String get devicesResetTitle;

  /// No description provided for @devicesResetBody.
  ///
  /// In en, this message translates to:
  /// **'Returns the device\'s options (such as color order) to what they were when it was first detected, makes it follow OpenChroma effects again and restores its position in the layout. Connector LED counts are kept.'**
  String get devicesResetBody;

  /// No description provided for @devicesRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get devicesRestore;

  /// No description provided for @engineProfileGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get engineProfileGame;

  /// No description provided for @engineProfileWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get engineProfileWork;

  /// No description provided for @engineProfileNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get engineProfileNight;

  /// No description provided for @engineProfileOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get engineProfileOff;

  /// No description provided for @engineImportBadExtension.
  ///
  /// In en, this message translates to:
  /// **'Use an .ocfx, .json or .html file.'**
  String get engineImportBadExtension;

  /// No description provided for @engineImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that file.'**
  String get engineImportUnreadable;

  /// No description provided for @enginePluginStopped.
  ///
  /// In en, this message translates to:
  /// **'The plugin stopped: {error}'**
  String enginePluginStopped(String error);

  /// No description provided for @enginePluginRejected.
  ///
  /// In en, this message translates to:
  /// **'The plugin didn\'t recognize this device.'**
  String get enginePluginRejected;

  /// No description provided for @engineScreenNoLiveValues.
  ///
  /// In en, this message translates to:
  /// **'This screen doesn\'t show live values.'**
  String get engineScreenNoLiveValues;

  /// No description provided for @engineScreenMaxLiveValues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This screen shows up to 1 different live value.} other{This screen shows up to {count} different live values.}}'**
  String engineScreenMaxLiveValues(int count);

  /// No description provided for @engineScreenRejected.
  ///
  /// In en, this message translates to:
  /// **'The device didn\'t accept the image.'**
  String get engineScreenRejected;

  /// No description provided for @engineScreenCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the image.'**
  String get engineScreenCannotOpen;

  /// No description provided for @pluginsNoDefinition.
  ///
  /// In en, this message translates to:
  /// **'the file doesn\'t call plugin()'**
  String get pluginsNoDefinition;

  /// No description provided for @pluginsNoDevices.
  ///
  /// In en, this message translates to:
  /// **'no devices in \"devices\"'**
  String get pluginsNoDevices;

  /// No description provided for @pluginsNoPort.
  ///
  /// In en, this message translates to:
  /// **'no port chosen'**
  String get pluginsNoPort;

  /// No description provided for @pluginsNoInterface.
  ///
  /// In en, this message translates to:
  /// **'no interface chosen'**
  String get pluginsNoInterface;

  /// No description provided for @pluginsCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t open {path}'**
  String pluginsCannotOpen(String path);

  /// No description provided for @layoutPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get layoutPreview;

  /// No description provided for @layoutApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get layoutApply;

  /// No description provided for @layoutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get layoutCancel;

  /// No description provided for @layoutAutoArrange.
  ///
  /// In en, this message translates to:
  /// **'Auto arrange'**
  String get layoutAutoArrange;

  /// No description provided for @layoutUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get layoutUndo;

  /// No description provided for @layoutHint.
  ///
  /// In en, this message translates to:
  /// **'Click a zone to identify its LEDs, or drag to move it.'**
  String get layoutHint;

  /// No description provided for @layoutDimEffect.
  ///
  /// In en, this message translates to:
  /// **'Dim effect'**
  String get layoutDimEffect;

  /// No description provided for @layoutNothingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to place'**
  String get layoutNothingTitle;

  /// No description provided for @layoutNothingMessage.
  ///
  /// In en, this message translates to:
  /// **'Connected devices appear here.'**
  String get layoutNothingMessage;

  /// No description provided for @layoutDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get layoutDevice;

  /// No description provided for @layoutSelectedZone.
  ///
  /// In en, this message translates to:
  /// **'Selected zone'**
  String get layoutSelectedZone;

  /// No description provided for @layoutFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get layoutFill;

  /// No description provided for @layoutSwitchToApp.
  ///
  /// In en, this message translates to:
  /// **'Switch to OpenChroma effects to identify this zone.'**
  String get layoutSwitchToApp;

  /// No description provided for @layoutRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90°'**
  String get layoutRotate;

  /// No description provided for @layoutFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip horizontal'**
  String get layoutFlipHorizontal;

  /// No description provided for @layoutFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip vertical'**
  String get layoutFlipVertical;

  /// No description provided for @layoutScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get layoutScale;

  /// No description provided for @layoutPositionX.
  ///
  /// In en, this message translates to:
  /// **'X position'**
  String get layoutPositionX;

  /// No description provided for @layoutPositionY.
  ///
  /// In en, this message translates to:
  /// **'Y position'**
  String get layoutPositionY;

  /// No description provided for @screenImageFiles.
  ///
  /// In en, this message translates to:
  /// **'Images and GIFs'**
  String get screenImageFiles;

  /// No description provided for @screenImageOrGif.
  ///
  /// In en, this message translates to:
  /// **'Image or GIF'**
  String get screenImageOrGif;

  /// No description provided for @screenSending.
  ///
  /// In en, this message translates to:
  /// **'Sending… {percent}%'**
  String screenSending(int percent);

  /// No description provided for @screenImageHint.
  ///
  /// In en, this message translates to:
  /// **'Crop, pick the clip and write over it before sending. The screen keeps what it receives, even with the app closed.'**
  String get screenImageHint;

  /// No description provided for @screenEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get screenEdit;

  /// No description provided for @screenChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get screenChooseFile;

  /// No description provided for @screenEditorCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the image.'**
  String get screenEditorCannotOpen;

  /// No description provided for @screenEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit screen image'**
  String get screenEditorTitle;

  /// No description provided for @screenEditorHintIdle.
  ///
  /// In en, this message translates to:
  /// **'Click a text to select it. Drag the image to position it and use the mouse wheel to zoom.'**
  String get screenEditorHintIdle;

  /// No description provided for @screenEditorHintSelected.
  ///
  /// In en, this message translates to:
  /// **'Drag to move and pull the corner (or use the mouse wheel over the text) to resize. Arrow keys nudge the position, Delete removes, Ctrl+D duplicates and Esc clears the selection.'**
  String get screenEditorHintSelected;

  /// No description provided for @screenEditorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get screenEditorCancel;

  /// No description provided for @screenEditorSend.
  ///
  /// In en, this message translates to:
  /// **'Send to screen'**
  String get screenEditorSend;

  /// No description provided for @screenEditorFraming.
  ///
  /// In en, this message translates to:
  /// **'Framing'**
  String get screenEditorFraming;

  /// No description provided for @screenEditorFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get screenEditorFill;

  /// No description provided for @screenEditorFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get screenEditorFit;

  /// No description provided for @screenEditorBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get screenEditorBackgroundColor;

  /// No description provided for @screenEditorZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get screenEditorZoom;

  /// No description provided for @screenEditorGifClip.
  ///
  /// In en, this message translates to:
  /// **'GIF clip'**
  String get screenEditorGifClip;

  /// No description provided for @screenEditorFrameRange.
  ///
  /// In en, this message translates to:
  /// **'Frames {first} to {last} of {total} · {duration}'**
  String screenEditorFrameRange(
    int first,
    int last,
    int total,
    String duration,
  );

  /// No description provided for @screenEditorFramesReduced.
  ///
  /// In en, this message translates to:
  /// **' · will be reduced to {max} frames'**
  String screenEditorFramesReduced(int max);

  /// No description provided for @screenEditorTexts.
  ///
  /// In en, this message translates to:
  /// **'Texts'**
  String get screenEditorTexts;

  /// No description provided for @screenEditorAddText.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get screenEditorAddText;

  /// No description provided for @screenEditorLiveValues.
  ///
  /// In en, this message translates to:
  /// **'Live values: {used} of {total}. The screen updates every second while the app is open.'**
  String screenEditorLiveValues(int used, int total);

  /// No description provided for @screenEditorTextHint.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get screenEditorTextHint;

  /// No description provided for @screenEditorBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get screenEditorBold;

  /// No description provided for @screenEditorNormal.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get screenEditorNormal;

  /// No description provided for @screenEditorTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get screenEditorTextColor;

  /// No description provided for @screenEditorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get screenEditorDuplicate;

  /// No description provided for @screenEditorRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get screenEditorRemove;

  /// No description provided for @screenEditorLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Live · put the unit ({unit}) in a fixed text'**
  String screenEditorLiveHint(String unit);

  /// No description provided for @screenEditorShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get screenEditorShow;

  /// No description provided for @screenEditorFixedText.
  ///
  /// In en, this message translates to:
  /// **'Fixed text'**
  String get screenEditorFixedText;

  /// No description provided for @screenDefaultText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get screenDefaultText;

  /// No description provided for @screenSourceCpuTemp.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature'**
  String get screenSourceCpuTemp;

  /// No description provided for @screenSourceCpuUsage.
  ///
  /// In en, this message translates to:
  /// **'CPU usage'**
  String get screenSourceCpuUsage;

  /// No description provided for @screenSourceCpuClock.
  ///
  /// In en, this message translates to:
  /// **'CPU clock'**
  String get screenSourceCpuClock;

  /// No description provided for @screenSourceCpuPower.
  ///
  /// In en, this message translates to:
  /// **'CPU power'**
  String get screenSourceCpuPower;

  /// No description provided for @screenSourceGpuTemp.
  ///
  /// In en, this message translates to:
  /// **'GPU temperature'**
  String get screenSourceGpuTemp;

  /// No description provided for @screenSourceGpuUsage.
  ///
  /// In en, this message translates to:
  /// **'GPU usage'**
  String get screenSourceGpuUsage;

  /// No description provided for @screenSourceGpuClock.
  ///
  /// In en, this message translates to:
  /// **'GPU clock'**
  String get screenSourceGpuClock;

  /// No description provided for @screenSourceGpuPower.
  ///
  /// In en, this message translates to:
  /// **'GPU power'**
  String get screenSourceGpuPower;

  /// No description provided for @screenSourceGpuFan.
  ///
  /// In en, this message translates to:
  /// **'GPU fan'**
  String get screenSourceGpuFan;

  /// No description provided for @screenSourceRamUsage.
  ///
  /// In en, this message translates to:
  /// **'RAM usage'**
  String get screenSourceRamUsage;

  /// No description provided for @perfTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get perfTitle;

  /// No description provided for @perfRestartAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Restart as administrator'**
  String get perfRestartAsAdmin;

  /// No description provided for @perfClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get perfClose;

  /// No description provided for @monitorUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor unavailable'**
  String get monitorUnavailableTitle;

  /// No description provided for @monitorUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This build does not include the system sensors.'**
  String get monitorUnavailableMessage;

  /// No description provided for @monitorReadingSensors.
  ///
  /// In en, this message translates to:
  /// **'Reading sensors…'**
  String get monitorReadingSensors;

  /// No description provided for @monitorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Updated every second · PC up for {uptime}'**
  String monitorSubtitle(String uptime);

  /// No description provided for @monitorStalledTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensors did not respond'**
  String get monitorStalledTitle;

  /// No description provided for @monitorStalledMessage.
  ///
  /// In en, this message translates to:
  /// **'No readings arrived from the system. Close and reopen OpenChroma; if it keeps happening, let us know.'**
  String get monitorStalledMessage;

  /// No description provided for @monitorProcessesAt.
  ///
  /// In en, this message translates to:
  /// **'Processes at {time}'**
  String monitorProcessesAt(String time);

  /// No description provided for @monitorInspectSummary.
  ///
  /// In en, this message translates to:
  /// **'CPU {cpu} · Memory {memory}'**
  String monitorInspectSummary(String cpu, String memory);

  /// No description provided for @monitorProcessor.
  ///
  /// In en, this message translates to:
  /// **'Processor'**
  String get monitorProcessor;

  /// No description provided for @monitorCoresThreads.
  ///
  /// In en, this message translates to:
  /// **'{cores} cores · {threads} threads'**
  String monitorCoresThreads(int cores, int threads);

  /// No description provided for @monitorUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get monitorUsage;

  /// No description provided for @monitorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get monitorTemperature;

  /// No description provided for @monitorClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get monitorClock;

  /// No description provided for @monitorPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get monitorPower;

  /// No description provided for @monitorUsagePerThread.
  ///
  /// In en, this message translates to:
  /// **'Usage per thread'**
  String get monitorUsagePerThread;

  /// No description provided for @monitorNeedsAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator required'**
  String get monitorNeedsAdminTitle;

  /// No description provided for @monitorNeedsAdminMessage.
  ///
  /// In en, this message translates to:
  /// **'The CPU sensor is read by the PawnIO driver, which only serves programs running as administrator.'**
  String get monitorNeedsAdminMessage;

  /// No description provided for @monitorSensorPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading the sensor…'**
  String get monitorSensorPendingTitle;

  /// No description provided for @monitorSensorPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Opening the PawnIO driver.'**
  String get monitorSensorPendingMessage;

  /// No description provided for @monitorSensorFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The sensor did not respond'**
  String get monitorSensorFailedTitle;

  /// No description provided for @monitorSensorFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The PawnIO driver stopped responding. The other readings keep working.'**
  String get monitorSensorFailedMessage;

  /// No description provided for @monitorNoDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'PawnIO driver not found'**
  String get monitorNoDriverTitle;

  /// No description provided for @monitorNoDriverMessage.
  ///
  /// In en, this message translates to:
  /// **'Install PawnIO (pawnio.eu) to see the CPU temperature.'**
  String get monitorNoDriverMessage;

  /// No description provided for @monitorNoSensorTitle.
  ///
  /// In en, this message translates to:
  /// **'No sensor'**
  String get monitorNoSensorTitle;

  /// No description provided for @monitorNoSensorMessage.
  ///
  /// In en, this message translates to:
  /// **'This processor has no supported temperature sensor.'**
  String get monitorNoSensorMessage;

  /// No description provided for @monitorGraphicsCard.
  ///
  /// In en, this message translates to:
  /// **'Graphics card'**
  String get monitorGraphicsCard;

  /// No description provided for @monitorTemperatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Temperature unavailable'**
  String get monitorTemperatureUnavailable;

  /// No description provided for @monitorFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get monitorFan;

  /// No description provided for @monitorVideoMemory.
  ///
  /// In en, this message translates to:
  /// **'Video memory'**
  String get monitorVideoMemory;

  /// No description provided for @monitorUsedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String monitorUsedOfTotal(String used, String total);

  /// No description provided for @monitorIntegratedGpu.
  ///
  /// In en, this message translates to:
  /// **'{name} · integrated'**
  String monitorIntegratedGpu(String name);

  /// No description provided for @monitorMemoryRam.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get monitorMemoryRam;

  /// No description provided for @monitorMemoryInstalled.
  ///
  /// In en, this message translates to:
  /// **'{size} installed'**
  String monitorMemoryInstalled(String size);

  /// No description provided for @monitorMemoryAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get monitorMemoryAvailable;

  /// No description provided for @monitorMemoryCached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get monitorMemoryCached;

  /// No description provided for @monitorMemoryCommitted.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get monitorMemoryCommitted;

  /// No description provided for @monitorStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get monitorStorage;

  /// No description provided for @monitorDiskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 disk} other{{count} disks}}'**
  String monitorDiskCount(int count);

  /// No description provided for @monitorDiskNumber.
  ///
  /// In en, this message translates to:
  /// **'Disk {number}'**
  String monitorDiskNumber(int number);

  /// No description provided for @monitorDiskActive.
  ///
  /// In en, this message translates to:
  /// **'Active {percent}'**
  String monitorDiskActive(String percent);

  /// No description provided for @monitorVolumeRemovable.
  ///
  /// In en, this message translates to:
  /// **'Removable'**
  String get monitorVolumeRemovable;

  /// No description provided for @monitorVolumeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local disk'**
  String get monitorVolumeLocal;

  /// No description provided for @monitorFreeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{free} free of {total}'**
  String monitorFreeOfTotal(String free, String total);

  /// No description provided for @monitorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get monitorNetwork;

  /// No description provided for @monitorTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get monitorTraffic;

  /// No description provided for @monitorDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get monitorDownload;

  /// No description provided for @monitorUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get monitorUpload;

  /// No description provided for @monitorProcesses.
  ///
  /// In en, this message translates to:
  /// **'Processes'**
  String get monitorProcesses;

  /// No description provided for @monitorTopMemory.
  ///
  /// In en, this message translates to:
  /// **'Top memory users'**
  String get monitorTopMemory;

  /// No description provided for @monitorTopCpu.
  ///
  /// In en, this message translates to:
  /// **'Top CPU users'**
  String get monitorTopCpu;

  /// No description provided for @monitorColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get monitorColumnName;

  /// No description provided for @monitorColumnCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get monitorColumnCpu;

  /// No description provided for @monitorColumnMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get monitorColumnMemory;

  /// No description provided for @monitorNoProcessData.
  ///
  /// In en, this message translates to:
  /// **'No process data for this sample.'**
  String get monitorNoProcessData;

  /// No description provided for @monitorSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort by {column}, highest first'**
  String monitorSortTooltip(String column);

  /// No description provided for @monitorTempNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get monitorTempNormal;

  /// No description provided for @monitorTempWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get monitorTempWarm;

  /// No description provided for @monitorTempHot.
  ///
  /// In en, this message translates to:
  /// **'Very hot'**
  String get monitorTempHot;

  /// No description provided for @monitorThreadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Thread {number}: {usage}'**
  String monitorThreadTooltip(int number, String usage);

  /// No description provided for @monitorClickToInspect.
  ///
  /// In en, this message translates to:
  /// **'Click to inspect'**
  String get monitorClickToInspect;

  /// No description provided for @monitorNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get monitorNow;

  /// No description provided for @monitorSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s ago'**
  String monitorSecondsAgo(int seconds);

  /// No description provided for @checkupSubtitleRunning.
  ///
  /// In en, this message translates to:
  /// **'Checkup in progress'**
  String get checkupSubtitleRunning;

  /// No description provided for @checkupSubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Test your PC stability and health'**
  String get checkupSubtitleEmpty;

  /// No description provided for @checkupSubtitleLast.
  ///
  /// In en, this message translates to:
  /// **'Last checkup {when}'**
  String checkupSubtitleLast(String when);

  /// No description provided for @checkupWhenToday.
  ///
  /// In en, this message translates to:
  /// **'today at {time}'**
  String checkupWhenToday(String time);

  /// No description provided for @checkupWhenYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday at {time}'**
  String checkupWhenYesterday(String time);

  /// No description provided for @checkupWhenDate.
  ///
  /// In en, this message translates to:
  /// **'on {date} at {time}'**
  String checkupWhenDate(String date, String time);

  /// No description provided for @checkupTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get checkupTests;

  /// No description provided for @checkupSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total}'**
  String checkupSelectedCount(int selected, int total);

  /// No description provided for @checkupPlanQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get checkupPlanQuick;

  /// No description provided for @checkupPlanStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get checkupPlanStandard;

  /// No description provided for @checkupPlanLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get checkupPlanLong;

  /// No description provided for @checkupTestCpuSingle.
  ///
  /// In en, this message translates to:
  /// **'Processor · 1 core'**
  String get checkupTestCpuSingle;

  /// No description provided for @checkupTestCpuAll.
  ///
  /// In en, this message translates to:
  /// **'Processor · all cores'**
  String get checkupTestCpuAll;

  /// No description provided for @checkupTestMemory.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get checkupTestMemory;

  /// No description provided for @checkupTestGpu.
  ///
  /// In en, this message translates to:
  /// **'Graphics card'**
  String get checkupTestGpu;

  /// No description provided for @checkupTestCpuGpu.
  ///
  /// In en, this message translates to:
  /// **'CPU + GPU together'**
  String get checkupTestCpuGpu;

  /// No description provided for @checkupTestDisk.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get checkupTestDisk;

  /// No description provided for @checkupThousands.
  ///
  /// In en, this message translates to:
  /// **'{value}k'**
  String checkupThousands(String value);

  /// No description provided for @checkupMemoryMetricRead.
  ///
  /// In en, this message translates to:
  /// **'Reads {read} GB/s'**
  String checkupMemoryMetricRead(String read);

  /// No description provided for @checkupMemoryMetricWrite.
  ///
  /// In en, this message translates to:
  /// **'writes {write}'**
  String checkupMemoryMetricWrite(String write);

  /// No description provided for @checkupDiskMetricWrite.
  ///
  /// In en, this message translates to:
  /// **'Writes {write} GB/s'**
  String checkupDiskMetricWrite(String write);

  /// No description provided for @checkupDiskMetricRead.
  ///
  /// In en, this message translates to:
  /// **'reads {read}'**
  String checkupDiskMetricRead(String read);

  /// No description provided for @checkupTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkup'**
  String get checkupTitle;

  /// No description provided for @checkupCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get checkupCancel;

  /// No description provided for @checkupPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get checkupPreparing;

  /// No description provided for @checkupStart.
  ///
  /// In en, this message translates to:
  /// **'Start checkup'**
  String get checkupStart;

  /// No description provided for @checkupRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get checkupRunAgain;

  /// No description provided for @checkupNoAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Without administrator rights, the CPU temperature and the cause of blue screens are left out.'**
  String get checkupNoAdminNote;

  /// No description provided for @checkupProblemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 problem} other{{count} problems}}'**
  String checkupProblemCount(int count);

  /// No description provided for @checkupWarningCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String checkupWarningCount(int count);

  /// No description provided for @checkupAllGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get checkupAllGood;

  /// No description provided for @checkupCalcErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No calculation errors} =1{1 calculation error} other{{count} calculation errors}}'**
  String checkupCalcErrors(int count);

  /// No description provided for @checkupNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {plan} · ≈ {minutes} min'**
  String checkupNext(String plan, int minutes);

  /// No description provided for @checkupTestCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 test} other{{count} tests}}'**
  String checkupTestCount(int count);

  /// No description provided for @checkupFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get checkupFinishing;

  /// No description provided for @checkupTestProgress.
  ///
  /// In en, this message translates to:
  /// **'Test {index} of {total}'**
  String checkupTestProgress(int index, int total);

  /// No description provided for @checkupProgressRemaining.
  ///
  /// In en, this message translates to:
  /// **'{percent}% · {time} left'**
  String checkupProgressRemaining(int percent, String time);

  /// No description provided for @checkupStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get checkupStatusQueued;

  /// No description provided for @checkupStatusStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get checkupStatusStable;

  /// No description provided for @checkupStatusErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String checkupStatusErrors(int count);

  /// No description provided for @checkupStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get checkupStatusStopped;

  /// No description provided for @checkupStatusDidNotRun.
  ///
  /// In en, this message translates to:
  /// **'Did not run'**
  String get checkupStatusDidNotRun;

  /// No description provided for @checkupStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get checkupStatusCancelled;

  /// No description provided for @systemCardTitle.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemCardTitle;

  /// No description provided for @systemAfterFirstCheckup.
  ///
  /// In en, this message translates to:
  /// **'Appears after the first checkup'**
  String get systemAfterFirstCheckup;

  /// No description provided for @systemMotherboard.
  ///
  /// In en, this message translates to:
  /// **'Motherboard'**
  String get systemMotherboard;

  /// No description provided for @systemProcessor.
  ///
  /// In en, this message translates to:
  /// **'Processor'**
  String get systemProcessor;

  /// No description provided for @systemGraphicsCard.
  ///
  /// In en, this message translates to:
  /// **'Graphics card'**
  String get systemGraphicsCard;

  /// No description provided for @systemMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get systemMemory;

  /// No description provided for @systemModuleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 module} other{{count} modules}}'**
  String systemModuleCount(int count);

  /// No description provided for @systemSlotCount.
  ///
  /// In en, this message translates to:
  /// **'{count} slots'**
  String systemSlotCount(int count);

  /// No description provided for @systemMemoryInUse.
  ///
  /// In en, this message translates to:
  /// **'Memory in use'**
  String get systemMemoryInUse;

  /// No description provided for @systemMemoryUsedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} GB'**
  String systemMemoryUsedOfTotal(String used, String total);

  /// No description provided for @systemDrive.
  ///
  /// In en, this message translates to:
  /// **'System drive'**
  String get systemDrive;

  /// No description provided for @systemDriveFree.
  ///
  /// In en, this message translates to:
  /// **'{free} GB free of {total} GB'**
  String systemDriveFree(String free, String total);

  /// No description provided for @systemBlueScreens.
  ///
  /// In en, this message translates to:
  /// **'Blue screens · 30 days'**
  String get systemBlueScreens;

  /// No description provided for @systemBlueScreensNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get systemBlueScreensNone;

  /// No description provided for @systemStartupApps.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get systemStartupApps;

  /// No description provided for @systemStartupAppsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 program} other{{count} programs}}'**
  String systemStartupAppsValue(int count);

  /// No description provided for @systemIdleCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU at idle'**
  String get systemIdleCpu;

  /// No description provided for @systemIdleCpuValue.
  ///
  /// In en, this message translates to:
  /// **'{temp} °C · {usage}% usage'**
  String systemIdleCpuValue(int temp, int usage);

  /// No description provided for @checkupRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get checkupRecommendations;

  /// No description provided for @checkupRecommendationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Finish a checkup to see the recommendations'**
  String get checkupRecommendationsEmpty;

  /// No description provided for @checkupAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI analysis'**
  String get checkupAiTitle;

  /// No description provided for @checkupAiNotReady.
  ///
  /// In en, this message translates to:
  /// **'Connect an AI in Settings to use this.'**
  String get checkupAiNotReady;

  /// No description provided for @checkupAiRunFirst.
  ///
  /// In en, this message translates to:
  /// **'Run a checkup to analyze the results.'**
  String get checkupAiRunFirst;

  /// No description provided for @checkupAiHint.
  ///
  /// In en, this message translates to:
  /// **'Explains the results and suggests tweaks for your PC.'**
  String get checkupAiHint;

  /// No description provided for @checkupAiAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get checkupAiAnalyze;

  /// No description provided for @checkupAiAnalyzeAgain.
  ///
  /// In en, this message translates to:
  /// **'Analyze again'**
  String get checkupAiAnalyzeAgain;

  /// No description provided for @checkupAiSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are an experienced hardware technician analyzing the checkup of a Windows PC run by the OpenChroma app. Answer in American English, in plain text (no tables), with: a one-line verdict; the real problems in order of importance, each with the probable cause and what to do; and what is fine. Be specific with the numbers in the report and do not invent data that is not in it. 250 words at most.'**
  String get checkupAiSystemPrompt;

  /// No description provided for @checkupAbortCpuTemp.
  ///
  /// In en, this message translates to:
  /// **'CPU went over {temp} °C'**
  String checkupAbortCpuTemp(int temp);

  /// No description provided for @checkupAbortGpuTemp.
  ///
  /// In en, this message translates to:
  /// **'The graphics card went over {temp} °C'**
  String checkupAbortGpuTemp(int temp);

  /// No description provided for @checkupAbortPump.
  ///
  /// In en, this message translates to:
  /// **'The liquid cooler pump stopped'**
  String get checkupAbortPump;

  /// No description provided for @checkupAdviceAbortedTitle.
  ///
  /// In en, this message translates to:
  /// **'Test stopped: {reason}'**
  String checkupAdviceAbortedTitle(String reason);

  /// No description provided for @checkupAdviceAbortedDetail.
  ///
  /// In en, this message translates to:
  /// **'Cooling could not keep up with the load. Check the cooler (mounting, thermal paste, fans and pump) before using the PC under heavy load.'**
  String get checkupAdviceAbortedDetail;

  /// No description provided for @checkupAdviceCpuErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'The CPU made calculation errors under load'**
  String get checkupAdviceCpuErrorsTitle;

  /// No description provided for @checkupAdviceCpuErrorsDetail.
  ///
  /// In en, this message translates to:
  /// **'Sign of instability. Undo any overclock or undervolt (PBO, Curve Optimizer) and update the BIOS; if it keeps happening, it may be a defect.'**
  String get checkupAdviceCpuErrorsDetail;

  /// No description provided for @checkupAdviceGpuErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'The graphics card calculated incorrectly'**
  String get checkupAdviceGpuErrorsTitle;

  /// No description provided for @checkupAdviceGpuErrorsDetail.
  ///
  /// In en, this message translates to:
  /// **'Remove any GPU overclock and update the graphics driver.'**
  String get checkupAdviceGpuErrorsDetail;

  /// No description provided for @checkupAdviceMemoryErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'The memory returned wrong data'**
  String get checkupAdviceMemoryErrorsTitle;

  /// No description provided for @checkupAdviceMemoryErrorsDetail.
  ///
  /// In en, this message translates to:
  /// **'Turn off EXPO/XMP in the BIOS and test again. If it keeps happening, test one module at a time to find the faulty one.'**
  String get checkupAdviceMemoryErrorsDetail;

  /// No description provided for @checkupAdviceDiskErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'The disk returned data different from what was written'**
  String get checkupAdviceDiskErrorsTitle;

  /// No description provided for @checkupAdviceDiskErrorsDetail.
  ///
  /// In en, this message translates to:
  /// **'Back up now and check the disk health.'**
  String get checkupAdviceDiskErrorsDetail;

  /// No description provided for @checkupAdviceBlueScreensTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 blue screen in the last 30 days} other{{count} blue screens in the last 30 days}}'**
  String checkupAdviceBlueScreensTitle(int count);

  /// No description provided for @checkupAdviceBlueScreensSuspect.
  ///
  /// In en, this message translates to:
  /// **'The driver {driver} appears in {count} of {total} crash records. Update or uninstall the program that owns it.'**
  String checkupAdviceBlueScreensSuspect(String driver, int count, int total);

  /// No description provided for @checkupAdviceBlueScreensNoSuspect.
  ///
  /// In en, this message translates to:
  /// **'The records do not point to a third-party driver. Update the BIOS, the chipset and the graphics driver, and test the memory.'**
  String get checkupAdviceBlueScreensNoSuspect;

  /// No description provided for @checkupAdviceBlueScreensNeedAdmin.
  ///
  /// In en, this message translates to:
  /// **'Run the checkup as administrator to find the responsible driver.'**
  String get checkupAdviceBlueScreensNeedAdmin;

  /// No description provided for @checkupAdviceCpuHotTitle.
  ///
  /// In en, this message translates to:
  /// **'The CPU reaches {temp} °C at full load'**
  String checkupAdviceCpuHotTitle(int temp);

  /// No description provided for @checkupAdviceCpuHotDetail.
  ///
  /// In en, this message translates to:
  /// **'It is at its thermal limit and loses performance. Improve cooling or limit the temperature/power in the BIOS (Eco Mode on AMD, PL1/PL2 on Intel).'**
  String get checkupAdviceCpuHotDetail;

  /// No description provided for @checkupAdviceGpuHotTitle.
  ///
  /// In en, this message translates to:
  /// **'The graphics card reaches {temp} °C'**
  String checkupAdviceGpuHotTitle(int temp);

  /// No description provided for @checkupAdviceGpuHotDetail.
  ///
  /// In en, this message translates to:
  /// **'Improve the case airflow or adjust the GPU fan curve.'**
  String get checkupAdviceGpuHotDetail;

  /// No description provided for @checkupAdviceSingleChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Single-channel memory'**
  String get checkupAdviceSingleChannelTitle;

  /// No description provided for @checkupAdviceSingleChannelDetail.
  ///
  /// In en, this message translates to:
  /// **'A single module uses half the bandwidth. Adding an identical one (same model) enables dual channel.'**
  String get checkupAdviceSingleChannelDetail;

  /// No description provided for @checkupAdviceSameChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'The modules are on the same channel'**
  String get checkupAdviceSameChannelTitle;

  /// No description provided for @checkupAdviceSameChannelDetail.
  ///
  /// In en, this message translates to:
  /// **'Move them to the slots shown in the motherboard manual (usually A2 and B2).'**
  String get checkupAdviceSameChannelDetail;

  /// No description provided for @checkupAdviceSlowMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'The memory runs below what it supports'**
  String get checkupAdviceSlowMemoryTitle;

  /// No description provided for @checkupAdviceSlowMemoryDetail.
  ///
  /// In en, this message translates to:
  /// **'{configured} of {speed} MT/s. Turn on EXPO (AMD) or XMP (Intel) in the BIOS.'**
  String checkupAdviceSlowMemoryDetail(int configured, int speed);

  /// No description provided for @checkupAdviceProfileOffTitle.
  ///
  /// In en, this message translates to:
  /// **'EXPO/XMP is probably off'**
  String get checkupAdviceProfileOffTitle;

  /// No description provided for @checkupAdviceProfileOffDetail.
  ///
  /// In en, this message translates to:
  /// **'The memory is at its base speed ({configured} MT/s). If the module is rated for a higher speed, turn on EXPO/XMP in the BIOS.'**
  String checkupAdviceProfileOffDetail(int configured);

  /// No description provided for @checkupAdviceMemoryFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory almost full'**
  String get checkupAdviceMemoryFullTitle;

  /// No description provided for @checkupAdviceMemoryFullDetail.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} GB in use and {committed} GB requested by programs; the excess goes to disk and slows everything down. Close heavy apps or add RAM.'**
  String checkupAdviceMemoryFullDetail(
    String used,
    String total,
    String committed,
  );

  /// No description provided for @checkupAdviceDriveFullTitle.
  ///
  /// In en, this message translates to:
  /// **'System drive almost full'**
  String get checkupAdviceDriveFullTitle;

  /// No description provided for @checkupAdviceDriveFullDetail.
  ///
  /// In en, this message translates to:
  /// **'Only {free} GB free. Below 10%, Windows slows down, runs short of space for virtual memory and deletes crash records.'**
  String checkupAdviceDriveFullDetail(String free);

  /// No description provided for @checkupAdviceStartupTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} programs start with Windows'**
  String checkupAdviceStartupTitle(int count);

  /// No description provided for @checkupAdviceStartupDetail.
  ///
  /// In en, this message translates to:
  /// **'Turn off the ones you do not use every day in Task Manager > Startup apps.'**
  String get checkupAdviceStartupDetail;

  /// No description provided for @checkupAdviceBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'The PC was busy before the tests'**
  String get checkupAdviceBusyTitle;

  /// No description provided for @checkupAdviceBusyDetail.
  ///
  /// In en, this message translates to:
  /// **'{usage}% CPU usage at idle: background programs heat up the PC and affect the results.'**
  String checkupAdviceBusyDetail(int usage);

  /// No description provided for @checkupAdviceNoCpuTempTitle.
  ///
  /// In en, this message translates to:
  /// **'No CPU temperature'**
  String get checkupAdviceNoCpuTempTitle;

  /// No description provided for @checkupAdviceNoCpuTempDetail.
  ///
  /// In en, this message translates to:
  /// **'Run the checkup as administrator to measure the temperature and protect the CPU during the tests.'**
  String get checkupAdviceNoCpuTempDetail;

  /// No description provided for @checkupAdviceAllGoodDetail.
  ///
  /// In en, this message translates to:
  /// **'No errors in the tests and nothing out of the ordinary on the system.'**
  String get checkupAdviceAllGoodDetail;

  /// No description provided for @systemErrorWindowsSetting.
  ///
  /// In en, this message translates to:
  /// **'Could not change the Windows setting.'**
  String get systemErrorWindowsSetting;

  /// No description provided for @systemErrorSaveSetting.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting.'**
  String get systemErrorSaveSetting;

  /// No description provided for @systemErrorEnableStartup.
  ///
  /// In en, this message translates to:
  /// **'Could not turn on starting with Windows.'**
  String get systemErrorEnableStartup;

  /// No description provided for @systemErrorTaskNotCreated.
  ///
  /// In en, this message translates to:
  /// **'The startup task was not created. You need to accept the Windows permission prompt.'**
  String get systemErrorTaskNotCreated;

  /// No description provided for @systemErrorTaskNotRemoved.
  ///
  /// In en, this message translates to:
  /// **'The startup task was not removed. You need to accept the Windows permission prompt.'**
  String get systemErrorTaskNotRemoved;

  /// No description provided for @systemTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Opens OpenChroma as administrator when you sign in to Windows.'**
  String get systemTaskDescription;

  /// No description provided for @pluginTrustTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The plugin took too long to start and was stopped.'**
  String get pluginTrustTimedOut;

  /// No description provided for @pluginTrustLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The plugin stopped while loading.'**
  String get pluginTrustLoadFailed;

  /// No description provided for @pluginTrustTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 1 MB.'**
  String get pluginTrustTooLarge;

  /// No description provided for @pluginTrustUnresponsive.
  ///
  /// In en, this message translates to:
  /// **'The plugin stopped responding.'**
  String get pluginTrustUnresponsive;

  /// No description provided for @pluginTrustBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new plugin needs your approval} other{{count} new plugins need your approval}}'**
  String pluginTrustBanner(int count);

  /// No description provided for @pluginTrustReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get pluginTrustReview;

  /// No description provided for @pluginTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Device plugins'**
  String get pluginTrustTitle;

  /// No description provided for @pluginTrustIntro.
  ///
  /// In en, this message translates to:
  /// **'A plugin is a program that runs inside OpenChroma and can send any command to your USB devices. Approve only plugins from a source you trust.'**
  String get pluginTrustIntro;

  /// No description provided for @pluginTrustElevated.
  ///
  /// In en, this message translates to:
  /// **'OpenChroma is running as administrator, so an approved plugin runs with administrator rights.'**
  String get pluginTrustElevated;

  /// No description provided for @pluginTrustPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get pluginTrustPending;

  /// No description provided for @pluginTrustApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get pluginTrustApproved;

  /// No description provided for @pluginTrustDenied.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get pluginTrustDenied;

  /// No description provided for @pluginTrustApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get pluginTrustApprove;

  /// No description provided for @pluginTrustDeny.
  ///
  /// In en, this message translates to:
  /// **'Don\'t allow'**
  String get pluginTrustDeny;

  /// No description provided for @pluginTrustRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get pluginTrustRevoke;

  /// No description provided for @pluginTrustClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get pluginTrustClose;

  /// No description provided for @pluginTrustPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get pluginTrustPath;

  /// No description provided for @pluginTrustSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get pluginTrustSize;

  /// No description provided for @pluginTrustModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get pluginTrustModified;

  /// No description provided for @pluginTrustHash.
  ///
  /// In en, this message translates to:
  /// **'SHA-256'**
  String get pluginTrustHash;

  /// No description provided for @pluginTrustChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed since you approved it'**
  String get pluginTrustChanged;

  /// No description provided for @pluginTrustReplaces.
  ///
  /// In en, this message translates to:
  /// **'Replaces the built-in plugin with the same file name'**
  String get pluginTrustReplaces;

  /// No description provided for @pluginTrustOverrides.
  ///
  /// In en, this message translates to:
  /// **'Replaces the built-in plugin: {names}'**
  String pluginTrustOverrides(String names);

  /// No description provided for @pluginTrustEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no plugins in your plugins folder. Built-in plugins don\'t need approval.'**
  String get pluginTrustEmpty;

  /// No description provided for @securityStartupAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Opens in the tray, as administrator, when you sign in to Windows, without asking for permission. Changing it needs OpenChroma running as administrator.'**
  String get securityStartupAdminDescription;

  /// No description provided for @securityStartupInstallUnsafe.
  ///
  /// In en, this message translates to:
  /// **'To start as administrator automatically, install OpenChroma for all users (in Program Files). This copy can be modified without administrator rights, so it cannot be trusted to run with full access when you sign in.'**
  String get securityStartupInstallUnsafe;

  /// No description provided for @securityStartupInstallUnsafeRemove.
  ///
  /// In en, this message translates to:
  /// **'This copy can be modified without administrator rights, so starting it as administrator is unsafe. Turn this off to remove the automatic start as administrator.'**
  String get securityStartupInstallUnsafeRemove;

  /// No description provided for @securityStartupNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Restart OpenChroma as administrator to change the automatic start as administrator.'**
  String get securityStartupNeedsAdmin;

  /// No description provided for @securityErrorNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Restart OpenChroma as administrator to change this setting.'**
  String get securityErrorNeedsAdmin;

  /// No description provided for @securityErrorInstallNotTrusted.
  ///
  /// In en, this message translates to:
  /// **'To start as administrator automatically, install OpenChroma for all users (in Program Files).'**
  String get securityErrorInstallNotTrusted;

  /// No description provided for @securityErrorTaskNotCreated.
  ///
  /// In en, this message translates to:
  /// **'The startup task was not created.'**
  String get securityErrorTaskNotCreated;

  /// No description provided for @securityErrorTaskNotRemoved.
  ///
  /// In en, this message translates to:
  /// **'The startup task was not removed.'**
  String get securityErrorTaskNotRemoved;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get commonPaused;

  /// No description provided for @commonLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get commonLive;

  /// No description provided for @commonNoEffect.
  ///
  /// In en, this message translates to:
  /// **'No effect'**
  String get commonNoEffect;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @shellNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellNavHome;

  /// No description provided for @shellNavLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get shellNavLighting;

  /// No description provided for @shellNavDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get shellNavDevices;

  /// No description provided for @shellNavFans.
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get shellNavFans;

  /// No description provided for @shellNavPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get shellNavPerformance;

  /// No description provided for @shellNavSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellNavSettings;

  /// No description provided for @shellAdminActive.
  ///
  /// In en, this message translates to:
  /// **'Administrator mode on'**
  String get shellAdminActive;

  /// No description provided for @shellRestartAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Restart as administrator'**
  String get shellRestartAsAdmin;

  /// No description provided for @shellTabEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get shellTabEffects;

  /// No description provided for @shellTabLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get shellTabLayout;

  /// No description provided for @shellTabMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get shellTabMonitor;

  /// No description provided for @shellTabDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get shellTabDiagnostics;

  /// No description provided for @shellConflictOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{names} is open.} other{{names} are open.}}'**
  String shellConflictOpen(String names, int count);

  /// No description provided for @shellConflictAdvice.
  ///
  /// In en, this message translates to:
  /// **'Two programs on the same LEDs make the colors flicker. Close it, including in the tray.'**
  String get shellConflictAdvice;

  /// No description provided for @shellWebviewMissing.
  ///
  /// In en, this message translates to:
  /// **'Effects need Microsoft WebView2, which isn\'t installed on this PC.'**
  String get shellWebviewMissing;

  /// No description provided for @shellWebviewDownload.
  ///
  /// In en, this message translates to:
  /// **'Download WebView2'**
  String get shellWebviewDownload;

  /// No description provided for @shellPlayerOffPaused.
  ///
  /// In en, this message translates to:
  /// **'Off · effect paused'**
  String get shellPlayerOffPaused;

  /// No description provided for @shellPlayerLiveOnDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Live on 1 device} other{Live on {count} devices}}'**
  String shellPlayerLiveOnDevices(int count);

  /// No description provided for @lightingTitle.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get lightingTitle;

  /// No description provided for @lightingBrightnessPerDevice.
  ///
  /// In en, this message translates to:
  /// **'Brightness of each device'**
  String get lightingBrightnessPerDevice;

  /// No description provided for @lightingBrightnessTitle.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get lightingBrightnessTitle;

  /// No description provided for @lightingAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get lightingAll;

  /// No description provided for @lightingLights.
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get lightingLights;

  /// No description provided for @lightingScreens.
  ///
  /// In en, this message translates to:
  /// **'Screens'**
  String get lightingScreens;

  /// No description provided for @lightingNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices connected.'**
  String get lightingNoDevices;

  /// No description provided for @lightingBrightnessNote.
  ///
  /// In en, this message translates to:
  /// **'\"All\" applies to every device, on top of each one\'s own brightness. At 0%, the effect pauses and nothing is sent.'**
  String get lightingBrightnessNote;

  /// No description provided for @lightingPausedAtZero.
  ///
  /// In en, this message translates to:
  /// **'Paused: brightness is at 0%'**
  String get lightingPausedAtZero;

  /// No description provided for @lightingResumeEffect.
  ///
  /// In en, this message translates to:
  /// **'Resume the effect'**
  String get lightingResumeEffect;

  /// No description provided for @lightingPauseEffect.
  ///
  /// In en, this message translates to:
  /// **'Pause the effect'**
  String get lightingPauseEffect;

  /// No description provided for @homeGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get homeGreetingNight;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeStatusReading.
  ///
  /// In en, this message translates to:
  /// **'Reading sensors…'**
  String get homeStatusReading;

  /// No description provided for @homeStatusAllGood.
  ///
  /// In en, this message translates to:
  /// **'Everything looks good with your PC.'**
  String get homeStatusAllGood;

  /// No description provided for @homeStatusAlerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 alert needs attention.} other{{count} alerts need attention.}}'**
  String homeStatusAlerts(int count);

  /// No description provided for @homeWeekday.
  ///
  /// In en, this message translates to:
  /// **'{day, select, mon{Monday} tue{Tuesday} wed{Wednesday} thu{Thursday} fri{Friday} sat{Saturday} other{Sunday}}'**
  String homeWeekday(String day);

  /// No description provided for @homeMonth.
  ///
  /// In en, this message translates to:
  /// **'{month, select, jan{January} feb{February} mar{March} apr{April} may{May} jun{June} jul{July} aug{August} sep{September} oct{October} nov{November} other{December}}'**
  String homeMonth(String month);

  /// No description provided for @homeDate.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {month} {day}'**
  String homeDate(String weekday, String month, int day);

  /// No description provided for @homeOpenLighting.
  ///
  /// In en, this message translates to:
  /// **'Open lighting'**
  String get homeOpenLighting;

  /// No description provided for @homeOnDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{On 1 device} other{On {count} devices}}'**
  String homeOnDevices(int count);

  /// No description provided for @homeProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get homeProfilesTitle;

  /// No description provided for @homeProfilesHint.
  ///
  /// In en, this message translates to:
  /// **'Right-click a profile to save the current lighting to it or to turn it on along with a program'**
  String get homeProfilesHint;

  /// No description provided for @homeProfileWithApp.
  ///
  /// In en, this message translates to:
  /// **'With {app}'**
  String homeProfileWithApp(String app);

  /// No description provided for @homeProfileLightsOff.
  ///
  /// In en, this message translates to:
  /// **'Lights off'**
  String get homeProfileLightsOff;

  /// No description provided for @homeProfileCurrentEffect.
  ///
  /// In en, this message translates to:
  /// **'Current effect'**
  String get homeProfileCurrentEffect;

  /// No description provided for @homeProfileAutoOn.
  ///
  /// In en, this message translates to:
  /// **'Turns on automatically with {apps}'**
  String homeProfileAutoOn(String apps);

  /// No description provided for @homeProfileSaveHere.
  ///
  /// In en, this message translates to:
  /// **'Save current lighting here'**
  String get homeProfileSaveHere;

  /// No description provided for @homeProfileRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get homeProfileRename;

  /// No description provided for @homeProfileLinkApps.
  ///
  /// In en, this message translates to:
  /// **'Turn on with apps…'**
  String get homeProfileLinkApps;

  /// No description provided for @homeProfileReset.
  ///
  /// In en, this message translates to:
  /// **'Restore default profiles'**
  String get homeProfileReset;

  /// No description provided for @homeProfileNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get homeProfileNameTitle;

  /// No description provided for @homeLevelNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get homeLevelNormal;

  /// No description provided for @homeLevelWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get homeLevelWarm;

  /// No description provided for @homeLevelHot.
  ///
  /// In en, this message translates to:
  /// **'Very hot'**
  String get homeLevelHot;

  /// No description provided for @homeVitalUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage {value}%'**
  String homeVitalUsage(String value);

  /// No description provided for @homeVitalUsageNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Usage · temperature needs admin'**
  String get homeVitalUsageNeedsAdmin;

  /// No description provided for @homeVitalMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get homeVitalMemory;

  /// No description provided for @homeVitalStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get homeVitalStorage;

  /// No description provided for @homeVitalFreeUnit.
  ///
  /// In en, this message translates to:
  /// **'GB free'**
  String get homeVitalFreeUnit;

  /// No description provided for @homeVitalMemoryUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String homeVitalMemoryUsed(String used, String total);

  /// No description provided for @homeVitalDiskUsed.
  ///
  /// In en, this message translates to:
  /// **'{letter}: · {percent}% used'**
  String homeVitalDiskUsed(String letter, String percent);

  /// No description provided for @homeAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get homeAlertsTitle;

  /// No description provided for @homeAlertsAllGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get homeAlertsAllGood;

  /// No description provided for @homeFansTitle.
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get homeFansTitle;

  /// No description provided for @homeFanSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get homeFanSilent;

  /// No description provided for @homeFanBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get homeFanBalanced;

  /// No description provided for @homeFanTurbo.
  ///
  /// In en, this message translates to:
  /// **'Turbo'**
  String get homeFanTurbo;

  /// No description provided for @homeFanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 fan} other{{count} fans}}'**
  String homeFanCount(int count);

  /// No description provided for @homeFanUpTo.
  ///
  /// In en, this message translates to:
  /// **'up to {rpm} RPM'**
  String homeFanUpTo(int rpm);

  /// No description provided for @homeReactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactive light'**
  String get homeReactiveTitle;

  /// No description provided for @homeReactiveNoGpu.
  ///
  /// In en, this message translates to:
  /// **'No GPU reading on this PC.'**
  String get homeReactiveNoGpu;

  /// No description provided for @homeReactiveCpuNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature needs administrator mode.'**
  String get homeReactiveCpuNeedsAdmin;

  /// No description provided for @homeReactiveOn.
  ///
  /// In en, this message translates to:
  /// **'The LEDs show the temperature instead of the effect.'**
  String get homeReactiveOn;

  /// No description provided for @homeReactiveOff.
  ///
  /// In en, this message translates to:
  /// **'LED color follows the temperature.'**
  String get homeReactiveOff;

  /// No description provided for @homeScreenSending.
  ///
  /// In en, this message translates to:
  /// **'Sending… {percent}%'**
  String homeScreenSending(int percent);

  /// No description provided for @homeScreenOff.
  ///
  /// In en, this message translates to:
  /// **'Screen off'**
  String get homeScreenOff;

  /// No description provided for @homeScreenBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness {percent}%'**
  String homeScreenBrightness(int percent);

  /// No description provided for @homeScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Screen on'**
  String get homeScreenOn;

  /// No description provided for @homeScreenTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off the screen'**
  String get homeScreenTurnOff;

  /// No description provided for @homeScreenTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on the screen'**
  String get homeScreenTurnOn;

  /// No description provided for @homeDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get homeDevicesTitle;

  /// No description provided for @homeDevicesSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get homeDevicesSearching;

  /// No description provided for @homeDevicesNone.
  ///
  /// In en, this message translates to:
  /// **'No devices'**
  String get homeDevicesNone;

  /// No description provided for @homeDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get homeDeviceConnected;

  /// No description provided for @homeDeviceStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get homeDeviceStarting;

  /// No description provided for @homeDeviceProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get homeDeviceProblem;

  /// No description provided for @homeAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get homeAssistantTitle;

  /// No description provided for @homeAssistantNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get homeAssistantNewChat;

  /// No description provided for @homeAssistantSuggestionSlow.
  ///
  /// In en, this message translates to:
  /// **'Why is my PC slow?'**
  String get homeAssistantSuggestionSlow;

  /// No description provided for @homeAssistantSuggestionGpu.
  ///
  /// In en, this message translates to:
  /// **'What is heating up the GPU?'**
  String get homeAssistantSuggestionGpu;

  /// No description provided for @homeAssistantSuggestionEffect.
  ///
  /// In en, this message translates to:
  /// **'Create a calm blue effect'**
  String get homeAssistantSuggestionEffect;

  /// No description provided for @homeAssistantConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect an AI to ask about your PC.'**
  String get homeAssistantConnect;

  /// No description provided for @homeAssistantConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Use your Anthropic or OpenAI key, or one from a compatible service.'**
  String get homeAssistantConnectHint;

  /// No description provided for @homeAssistantSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up AI'**
  String get homeAssistantSetUp;

  /// No description provided for @homeAssistantAskAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your PC.'**
  String get homeAssistantAskAnything;

  /// No description provided for @homeAssistantThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get homeAssistantThinking;

  /// No description provided for @homeAssistantApplyEffect.
  ///
  /// In en, this message translates to:
  /// **'Apply effect'**
  String get homeAssistantApplyEffect;

  /// No description provided for @homeAssistantHint.
  ///
  /// In en, this message translates to:
  /// **'Ask something…'**
  String get homeAssistantHint;

  /// No description provided for @homeAssistantEffectOn.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is on.'**
  String homeAssistantEffectOn(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
