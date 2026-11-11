import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Media Cleaner'**
  String get appTitle;

  /// No description provided for @appWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get appWhatsApp;

  /// No description provided for @appWhatsAppBusiness.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Business'**
  String get appWhatsAppBusiness;

  /// No description provided for @appOtherFolder.
  ///
  /// In en, this message translates to:
  /// **'Chat media folder'**
  String get appOtherFolder;

  /// No description provided for @accessTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your chat media folder'**
  String get accessTitle;

  /// No description provided for @accessBody.
  ///
  /// In en, this message translates to:
  /// **'Android keeps WhatsApp photos, videos and voice notes in a folder that other apps can only open if you choose it. Choose it once, and Chat Media Cleaner can show you what\'s taking up space.'**
  String get accessBody;

  /// No description provided for @accessStep1.
  ///
  /// In en, this message translates to:
  /// **'Tap Choose WhatsApp folder below.'**
  String get accessStep1;

  /// No description provided for @accessStep2.
  ///
  /// In en, this message translates to:
  /// **'Android\'s file picker opens at Android › media › com.whatsapp › WhatsApp › Media.'**
  String get accessStep2;

  /// No description provided for @accessStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap Use this folder, then Allow.'**
  String get accessStep3;

  /// No description provided for @promiseOnlyFolder.
  ///
  /// In en, this message translates to:
  /// **'Only the folders you choose. Nothing else on your phone.'**
  String get promiseOnlyFolder;

  /// No description provided for @promiseOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet permission: nothing ever leaves your phone.'**
  String get promiseOffline;

  /// No description provided for @promiseReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing is deleted until you select files and confirm.'**
  String get promiseReview;

  /// No description provided for @promiseTrash.
  ///
  /// In en, this message translates to:
  /// **'Deleted files wait in the app\'s trash first, so you can restore them.'**
  String get promiseTrash;

  /// No description provided for @chooseWhatsAppFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose WhatsApp folder'**
  String get chooseWhatsAppFolder;

  /// No description provided for @chooseBusinessFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose WhatsApp Business folder'**
  String get chooseBusinessFolder;

  /// No description provided for @accessLegacyHint.
  ///
  /// In en, this message translates to:
  /// **'On Android 10 or older, the folder is WhatsApp › Media at the top of your phone\'s storage.'**
  String get accessLegacyHint;

  /// No description provided for @notAffiliatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not affiliated'**
  String get notAffiliatedTitle;

  /// No description provided for @notAffiliated.
  ///
  /// In en, this message translates to:
  /// **'Chat Media Cleaner is an independent app. It is not made by, affiliated with or endorsed by WhatsApp or Meta.'**
  String get notAffiliated;

  /// No description provided for @addFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a folder'**
  String get addFolderTitle;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFolder;

  /// No description provided for @folderAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {names}.'**
  String folderAdded(String names);

  /// No description provided for @folderNotChatMedia.
  ///
  /// In en, this message translates to:
  /// **'That folder doesn\'t contain WhatsApp media. Choose the Media folder inside WhatsApp, or use Choose another folder.'**
  String get folderNotChatMedia;

  /// No description provided for @folderPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the folder picker. Please try again.'**
  String get folderPickFailed;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @scanPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Find what\'s taking up space'**
  String get scanPromptTitle;

  /// No description provided for @scanPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Scanning reads file names, sizes and dates. Nothing is opened, changed or uploaded.'**
  String get scanPromptBody;

  /// No description provided for @scanNow.
  ///
  /// In en, this message translates to:
  /// **'Scan now'**
  String get scanNow;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get rescan;

  /// No description provided for @scanListing.
  ///
  /// In en, this message translates to:
  /// **'Looking through your media…'**
  String get scanListing;

  /// No description provided for @scanHashing.
  ///
  /// In en, this message translates to:
  /// **'Comparing files… {done} of {total}'**
  String scanHashing(int done, int total);

  /// No description provided for @scanFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{formattedCount} files}} · {size} so far'**
  String scanFound(int count, String formattedCount, String size);

  /// No description provided for @scanNoAccess.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open the folder any more. Access may have been removed in system settings, or WhatsApp moved its files. Choose the folder again.'**
  String get scanNoAccess;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'The scan didn\'t finish. Please try again.'**
  String get scanFailed;

  /// No description provided for @scanPartial.
  ///
  /// In en, this message translates to:
  /// **'Some folders couldn\'t be read and are not included.'**
  String get scanPartial;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @totalFiles.
  ///
  /// In en, this message translates to:
  /// **'in {count, plural, =1{1 file} other{{formatted} files}}'**
  String totalFiles(int count, String formatted);

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{formatted} files}}'**
  String fileCount(int count, String formatted);

  /// No description provided for @cleanUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get cleanUpTitle;

  /// No description provided for @groupLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest files'**
  String get groupLargest;

  /// No description provided for @groupLargestDescription.
  ///
  /// In en, this message translates to:
  /// **'The biggest files, 1 MB and up.'**
  String get groupLargestDescription;

  /// No description provided for @groupOldForwards.
  ///
  /// In en, this message translates to:
  /// **'Old forwards and memes'**
  String get groupOldForwards;

  /// No description provided for @groupOldForwardsDescription.
  ///
  /// In en, this message translates to:
  /// **'Received photos, GIFs and short videos older than {months, plural, =1{1 month} other{{months} months}}.'**
  String groupOldForwardsDescription(int months);

  /// No description provided for @groupSentCopies.
  ///
  /// In en, this message translates to:
  /// **'Sent media copies'**
  String get groupSentCopies;

  /// No description provided for @groupSentCopiesDescription.
  ///
  /// In en, this message translates to:
  /// **'Copies of media you sent. The originals usually stay in your gallery.'**
  String get groupSentCopiesDescription;

  /// No description provided for @groupEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get groupEmpty;

  /// No description provided for @typeVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get typeVideos;

  /// No description provided for @typeImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get typeImages;

  /// No description provided for @typeVoiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Voice notes'**
  String get typeVoiceNotes;

  /// No description provided for @typeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get typeAudio;

  /// No description provided for @typeDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get typeDocuments;

  /// No description provided for @typeStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get typeStickers;

  /// No description provided for @typeGifs.
  ///
  /// In en, this message translates to:
  /// **'GIFs'**
  String get typeGifs;

  /// No description provided for @typeStatuses.
  ///
  /// In en, this message translates to:
  /// **'Statuses'**
  String get typeStatuses;

  /// No description provided for @typeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get typeOther;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to select. Touch and hold to open.'**
  String get reviewHint;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing left here.'**
  String get reviewEmpty;

  /// No description provided for @previewHint.
  ///
  /// In en, this message translates to:
  /// **'preview'**
  String get previewHint;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @sortLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest first'**
  String get sortLargest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @selectedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{formatted} selected}} · {size}'**
  String selectedSummary(int count, String formatted, String size);

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @moveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Move {count, plural, =1{1 file} other{{formatted} files}} to the trash?'**
  String moveConfirmTitle(int count, String formatted);

  /// No description provided for @moveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{size} goes to the app\'s trash. You can restore anything from there for {days, plural, =1{1 day} other{{days} days}}. The space is freed when the trash is emptied.'**
  String moveConfirmBody(String size, int days);

  /// No description provided for @movingProgress.
  ///
  /// In en, this message translates to:
  /// **'Moving to the trash… {done} of {total}'**
  String movingProgress(int done, int total);

  /// No description provided for @moveFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The file couldn\'t be moved.} other{The files couldn\'t be moved.}} Try scanning again.'**
  String moveFailed(int count);

  /// No description provided for @movedTitle.
  ///
  /// In en, this message translates to:
  /// **'Moved {count, plural, =1{1 file} other{{formatted} files}} ({size}) to the trash'**
  String movedTitle(int count, String formatted, String size);

  /// No description provided for @movedBody.
  ///
  /// In en, this message translates to:
  /// **'Delete them now to free the space, or keep them in the trash for {days, plural, =1{1 day} other{{days} days}} in case you change your mind.'**
  String movedBody(int days);

  /// No description provided for @someNotMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file couldn\'t be moved and was left where it was.} other{{count} files couldn\'t be moved and were left where they were.}}'**
  String someNotMoved(int count);

  /// No description provided for @keepInTrash.
  ///
  /// In en, this message translates to:
  /// **'Keep for {days, plural, =1{1 day} other{{days} days}}'**
  String keepInTrash(int days);

  /// No description provided for @deleteNow.
  ///
  /// In en, this message translates to:
  /// **'Delete now'**
  String get deleteNow;

  /// No description provided for @freed.
  ///
  /// In en, this message translates to:
  /// **'Freed {size}'**
  String freed(String size);

  /// No description provided for @freedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Freed so far: {size}'**
  String freedSoFar(String size);

  /// No description provided for @detailFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get detailFolder;

  /// No description provided for @detailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get detailSize;

  /// No description provided for @detailDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get detailDate;

  /// No description provided for @detailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get detailType;

  /// No description provided for @openWith.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get openWith;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @noAppToOpen.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone can open this file.'**
  String get noAppToOpen;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get emptyTrash;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'The trash is empty'**
  String get trashEmpty;

  /// No description provided for @trashInfo.
  ///
  /// In en, this message translates to:
  /// **'Files here are deleted for good after {days, plural, =1{1 day} other{{days} days}}. Restore puts them back where they were.'**
  String trashInfo(int days);

  /// No description provided for @trashCardTitle.
  ///
  /// In en, this message translates to:
  /// **'In the trash: {size}'**
  String trashCardTitle(String size);

  /// No description provided for @trashCardBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{formatted} files}}, deleted for good after {days, plural, =1{1 day} other{{days} days}}'**
  String trashCardBody(int count, String formatted, int days);

  /// No description provided for @deletedForGoodIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Deleted for good today} =1{Deleted for good in 1 day} other{Deleted for good in {days} days}}'**
  String deletedForGoodIn(int days);

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get deleteForever;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count, plural, =1{1 file} other{{formatted} files}} for good?'**
  String deleteConfirmTitle(int count, String formatted);

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This frees {size}. You can\'t undo this.'**
  String deleteConfirmBody(String size);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file couldn\'t be deleted.} other{{count} files couldn\'t be deleted.}}'**
  String deleteFailed(int count);

  /// No description provided for @restoreCount.
  ///
  /// In en, this message translates to:
  /// **'Restore ({count})'**
  String restoreCount(int count);

  /// No description provided for @restored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 file.} other{Restored {count} files.}}'**
  String restored(int count);

  /// No description provided for @restoreFolderGone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file stayed in the trash because its folder no longer exists.} other{{count} files stayed in the trash because their folder no longer exists.}}'**
  String restoreFolderGone(int count);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file couldn\'t be restored.} other{{count} files couldn\'t be restored.}}'**
  String restoreFailed(int count);

  /// No description provided for @settingsTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get settingsTrash;

  /// No description provided for @trashDaysSetting.
  ///
  /// In en, this message translates to:
  /// **'Keep deleted files for'**
  String get trashDaysSetting;

  /// No description provided for @settingsGroups.
  ///
  /// In en, this message translates to:
  /// **'Smart groups'**
  String get settingsGroups;

  /// No description provided for @oldMonthsSetting.
  ///
  /// In en, this message translates to:
  /// **'Old means older than'**
  String get oldMonthsSetting;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String days(int count);

  /// No description provided for @months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String months(int count);

  /// No description provided for @settingsFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get settingsFolders;

  /// No description provided for @removeAccess.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get removeAccess;

  /// No description provided for @removeAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove access to {app}?'**
  String removeAccessTitle(String app);

  /// No description provided for @removeAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Files from this folder that are in the trash are deleted for good first. Nothing else is changed.'**
  String get removeAccessBody;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'No internet permission, no analytics, no ads. Everything happens on your phone.'**
  String get privacyBody;

  /// No description provided for @aboutAndLicenses.
  ///
  /// In en, this message translates to:
  /// **'About and licenses'**
  String get aboutAndLicenses;

  /// No description provided for @legalese.
  ///
  /// In en, this message translates to:
  /// **'Open source under the MIT license.'**
  String get legalese;

  /// No description provided for @chooseFolderAgain.
  ///
  /// In en, this message translates to:
  /// **'Choose folder again'**
  String get chooseFolderAgain;

  /// No description provided for @byTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get byTypeTitle;

  /// No description provided for @groupDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Exact duplicates'**
  String get groupDuplicates;

  /// No description provided for @groupDuplicatesDescription.
  ///
  /// In en, this message translates to:
  /// **'Extra copies of identical files. The oldest copy of each is kept and never listed here.'**
  String get groupDuplicatesDescription;

  /// No description provided for @trashTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Trash} =1{Trash, 1 file} other{Trash, {count} files}}'**
  String trashTooltip(int count);

  /// No description provided for @tabClean.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get tabClean;

  /// No description provided for @tabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get tabFiles;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @filesIntro.
  ///
  /// In en, this message translates to:
  /// **'Browse the folders you chose, open anything right here, and share, rename or delete files.'**
  String get filesIntro;

  /// No description provided for @chooseOtherFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get chooseOtherFolder;

  /// No description provided for @accessOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Other folders work too, for example Telegram, Download or Camera: tap Choose another folder and pick one.'**
  String get accessOtherHint;

  /// No description provided for @folderStats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{formatted} files}} · {size}'**
  String folderStats(int count, String formatted, String size);

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get folderEmpty;

  /// No description provided for @folderLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this folder. It may have been moved or deleted.'**
  String get folderLoadFailed;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in this folder'**
  String get searchHint;

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// No description provided for @searchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchClose;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing here matches \"{query}\".'**
  String searchNoResults(String query);

  /// No description provided for @viewAsGrid.
  ///
  /// In en, this message translates to:
  /// **'Show as grid'**
  String get viewAsGrid;

  /// No description provided for @viewAsList.
  ///
  /// In en, this message translates to:
  /// **'Show as list'**
  String get viewAsList;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortSmallest.
  ///
  /// In en, this message translates to:
  /// **'Smallest first'**
  String get sortSmallest;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{formatted} selected}}'**
  String selectedCount(int count, String formatted);

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @fileMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions for {name}'**
  String fileMenuTooltip(String name);

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get actionDetails;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @shareTooMany.
  ///
  /// In en, this message translates to:
  /// **'Share up to {max} files at a time.'**
  String shareTooMany(int max);

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename file'**
  String get renameTitle;

  /// No description provided for @renameLabel.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get renameLabel;

  /// No description provided for @renameWarning.
  ///
  /// In en, this message translates to:
  /// **'A chat app may no longer show a file after it is renamed.'**
  String get renameWarning;

  /// No description provided for @renameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type a name.'**
  String get renameEmpty;

  /// No description provided for @renameBadCharacter.
  ///
  /// In en, this message translates to:
  /// **'A name can\'t contain / \\ : * ? \" < > |'**
  String get renameBadCharacter;

  /// No description provided for @renameReserved.
  ///
  /// In en, this message translates to:
  /// **'That name can\'t be used.'**
  String get renameReserved;

  /// No description provided for @renameTooLong.
  ///
  /// In en, this message translates to:
  /// **'That name is too long.'**
  String get renameTooLong;

  /// No description provided for @renameTaken.
  ///
  /// In en, this message translates to:
  /// **'This folder already has a file with that name.'**
  String get renameTaken;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename the file.'**
  String get renameFailed;

  /// No description provided for @renamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed to {name}.'**
  String renamed(String name);

  /// No description provided for @detailName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get detailName;

  /// No description provided for @detailDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get detailDimensions;

  /// No description provided for @detailDuration.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get detailDuration;

  /// No description provided for @dimensions.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height}'**
  String dimensions(int width, int height);

  /// No description provided for @viewerPosition.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String viewerPosition(int index, int total);

  /// No description provided for @viewerNoPreview.
  ///
  /// In en, this message translates to:
  /// **'This kind of file can\'t be shown here.'**
  String get viewerNoPreview;

  /// No description provided for @viewerCantPlay.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be played here.'**
  String get viewerCantPlay;

  /// No description provided for @viewerCantShow.
  ///
  /// In en, this message translates to:
  /// **'This file couldn\'t be opened. It may be damaged.'**
  String get viewerCantShow;

  /// No description provided for @viewerPdfLocked.
  ///
  /// In en, this message translates to:
  /// **'This PDF needs a password. Open it with another app.'**
  String get viewerPdfLocked;

  /// No description provided for @viewerTextTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only the beginning of this file is shown.'**
  String get viewerTextTruncated;

  /// No description provided for @pdfPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pdfPage(int page, int total);

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerReplay.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playerReplay;

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerSpeed;

  /// No description provided for @playerSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerSpeedNormal;

  /// No description provided for @playerLoopOn.
  ///
  /// In en, this message translates to:
  /// **'Repeat is on'**
  String get playerLoopOn;

  /// No description provided for @playerLoopOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat is off'**
  String get playerLoopOff;

  /// No description provided for @playerFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get playerFullscreen;

  /// No description provided for @playerExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get playerExitFullscreen;

  /// No description provided for @playerBack.
  ///
  /// In en, this message translates to:
  /// **'Back {seconds} seconds'**
  String playerBack(int seconds);

  /// No description provided for @playerForward.
  ///
  /// In en, this message translates to:
  /// **'Forward {seconds} seconds'**
  String playerForward(int seconds);

  /// No description provided for @playerSkipped.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String playerSkipped(int seconds);

  /// No description provided for @playerPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get playerPosition;

  /// No description provided for @openHint.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get openHint;

  /// No description provided for @browseHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to open. Touch and hold to select.'**
  String get browseHint;

  /// No description provided for @viewerToggleControls.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the controls'**
  String get viewerToggleControls;

  /// No description provided for @playerLock.
  ///
  /// In en, this message translates to:
  /// **'Lock the controls'**
  String get playerLock;

  /// No description provided for @playerUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get playerUnlock;

  /// No description provided for @playerLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get playerLocked;

  /// No description provided for @playerFitFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to screen'**
  String get playerFitFit;

  /// No description provided for @playerFitCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop to fill'**
  String get playerFitCrop;

  /// No description provided for @playerFitStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get playerFitStretch;

  /// No description provided for @playerAspect.
  ///
  /// In en, this message translates to:
  /// **'Picture size: {mode}'**
  String playerAspect(String mode);

  /// No description provided for @playerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous file'**
  String get playerPrevious;

  /// No description provided for @playerNext.
  ///
  /// In en, this message translates to:
  /// **'Next file'**
  String get playerNext;

  /// No description provided for @playerRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get playerRepeat;

  /// No description provided for @playerSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get playerSleepTimer;

  /// No description provided for @playerSleepTimerSet.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer · {minutes} min'**
  String playerSleepTimerSet(int minutes);

  /// No description provided for @sleepOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sleepOff;

  /// No description provided for @sleepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String sleepMinutes(int minutes);

  /// No description provided for @sleepIn.
  ///
  /// In en, this message translates to:
  /// **'Pauses in {minutes} min'**
  String sleepIn(int minutes);

  /// No description provided for @sleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer off'**
  String get sleepTimerOff;

  /// No description provided for @playerSaveFrame.
  ///
  /// In en, this message translates to:
  /// **'Save this frame as a photo'**
  String get playerSaveFrame;

  /// No description provided for @frameSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String frameSaved(String name);

  /// No description provided for @frameSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this frame'**
  String get frameSaveFailed;

  /// No description provided for @resumedFrom.
  ///
  /// In en, this message translates to:
  /// **'Carrying on from {time}'**
  String resumedFrom(String time);

  /// No description provided for @percent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percent(int value);
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
