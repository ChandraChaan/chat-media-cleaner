// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chat Media Cleaner';

  @override
  String get appWhatsApp => 'WhatsApp';

  @override
  String get appWhatsAppBusiness => 'WhatsApp Business';

  @override
  String get appOtherFolder => 'Chat media folder';

  @override
  String get accessTitle => 'Choose your chat media folder';

  @override
  String get accessBody =>
      'Android keeps WhatsApp photos, videos and voice notes in a folder that other apps can only open if you choose it. Choose it once, and Chat Media Cleaner can show you what\'s taking up space.';

  @override
  String get accessStep1 => 'Tap Choose WhatsApp folder below.';

  @override
  String get accessStep2 =>
      'Android\'s file picker opens at Android › media › com.whatsapp › WhatsApp › Media.';

  @override
  String get accessStep3 => 'Tap Use this folder, then Allow.';

  @override
  String get promiseOnlyFolder =>
      'Only the folder you choose. Nothing else on your phone.';

  @override
  String get promiseOffline =>
      'No internet permission: nothing ever leaves your phone.';

  @override
  String get promiseReview =>
      'Nothing is deleted until you select files and confirm.';

  @override
  String get promiseTrash =>
      'Deleted files wait in the app\'s trash first, so you can restore them.';

  @override
  String get chooseWhatsAppFolder => 'Choose WhatsApp folder';

  @override
  String get chooseBusinessFolder => 'Choose WhatsApp Business folder';

  @override
  String get accessLegacyHint =>
      'On Android 10 or older, the folder is WhatsApp › Media at the top of your phone\'s storage.';

  @override
  String get notAffiliatedTitle => 'Not affiliated';

  @override
  String get notAffiliated =>
      'Chat Media Cleaner is an independent app. It is not made by, affiliated with or endorsed by WhatsApp or Meta.';

  @override
  String get addFolderTitle => 'Add a folder';

  @override
  String get addFolder => 'Add folder';

  @override
  String folderAdded(String names) {
    return 'Added $names.';
  }

  @override
  String get folderNotChatMedia =>
      'That folder doesn\'t contain WhatsApp media. Choose the Media folder inside WhatsApp.';

  @override
  String get folderPickFailed =>
      'Couldn\'t open the folder picker. Please try again.';

  @override
  String get trashTitle => 'Trash';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get scanPromptTitle => 'Find what\'s taking up space';

  @override
  String get scanPromptBody =>
      'Scanning reads file names, sizes and dates. Nothing is opened, changed or uploaded.';

  @override
  String get scanNow => 'Scan now';

  @override
  String get rescan => 'Scan again';

  @override
  String get scanListing => 'Looking through your media…';

  @override
  String scanHashing(int done, int total) {
    return 'Comparing files… $done of $total';
  }

  @override
  String scanFound(int count, String formattedCount, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount files',
      one: '1 file',
    );
    return '$_temp0 · $size so far';
  }

  @override
  String get scanNoAccess =>
      'Can\'t open the folder any more. Access may have been removed in system settings, or WhatsApp moved its files. Choose the folder again.';

  @override
  String get scanFailed => 'The scan didn\'t finish. Please try again.';

  @override
  String get scanPartial =>
      'Some folders couldn\'t be read and are not included.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Try again';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String totalFiles(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted files',
      one: '1 file',
    );
    return 'in $_temp0';
  }

  @override
  String fileCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get cleanUpTitle => 'Clean up';

  @override
  String get groupLargest => 'Largest files';

  @override
  String get groupLargestDescription => 'The biggest files, 1 MB and up.';

  @override
  String get groupOldForwards => 'Old forwards and memes';

  @override
  String groupOldForwardsDescription(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return 'Received photos, GIFs and short videos older than $_temp0.';
  }

  @override
  String get groupSentCopies => 'Sent media copies';

  @override
  String get groupSentCopiesDescription =>
      'Copies of media you sent. The originals usually stay in your gallery.';

  @override
  String get groupEmpty => 'Nothing here';

  @override
  String get typeVideos => 'Videos';

  @override
  String get typeImages => 'Images';

  @override
  String get typeVoiceNotes => 'Voice notes';

  @override
  String get typeAudio => 'Audio';

  @override
  String get typeDocuments => 'Documents';

  @override
  String get typeStickers => 'Stickers';

  @override
  String get typeGifs => 'GIFs';

  @override
  String get typeStatuses => 'Statuses';

  @override
  String get typeOther => 'Other';

  @override
  String get reviewHint => 'Tap to select. Touch and hold to preview.';

  @override
  String get reviewEmpty => 'Nothing left here.';

  @override
  String get previewHint => 'preview';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortLargest => 'Largest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortNewest => 'Newest first';

  @override
  String selectedSummary(int count, String formatted, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted selected',
      one: '1 selected',
    );
    return '$_temp0 · $size';
  }

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String moveConfirmTitle(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted files',
      one: '1 file',
    );
    return 'Move $_temp0 to the trash?';
  }

  @override
  String moveConfirmBody(String size, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$size goes to the app\'s trash. You can restore anything from there for $_temp0. The space is freed when the trash is emptied.';
  }

  @override
  String movingProgress(int done, int total) {
    return 'Moving to the trash… $done of $total';
  }

  @override
  String moveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The files couldn\'t be moved.',
      one: 'The file couldn\'t be moved.',
    );
    return '$_temp0 Try scanning again.';
  }

  @override
  String movedTitle(int count, String formatted, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted files',
      one: '1 file',
    );
    return 'Moved $_temp0 ($size) to the trash';
  }

  @override
  String movedBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Delete them now to free the space, or keep them in the trash for $_temp0 in case you change your mind.';
  }

  @override
  String someNotMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files couldn\'t be moved and were left where they were.',
      one: '1 file couldn\'t be moved and was left where it was.',
    );
    return '$_temp0';
  }

  @override
  String keepInTrash(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Keep for $_temp0';
  }

  @override
  String get deleteNow => 'Delete now';

  @override
  String freed(String size) {
    return 'Freed $size';
  }

  @override
  String freedSoFar(String size) {
    return 'Freed so far: $size';
  }

  @override
  String get detailFolder => 'Folder';

  @override
  String get detailSize => 'Size';

  @override
  String get detailDate => 'Date';

  @override
  String get detailType => 'Type';

  @override
  String get openWith => 'Open with…';

  @override
  String get select => 'Select';

  @override
  String get selected => 'Selected';

  @override
  String get noAppToOpen => 'No app on this phone can open this file.';

  @override
  String get emptyTrash => 'Empty trash';

  @override
  String get trashEmpty => 'The trash is empty';

  @override
  String trashInfo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Files here are deleted for good after $_temp0. Restore puts them back where they were.';
  }

  @override
  String trashCardTitle(String size) {
    return 'In the trash: $size';
  }

  @override
  String trashCardBody(int count, String formatted, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted files',
      one: '1 file',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0, deleted for good after $_temp1';
  }

  @override
  String deletedForGoodIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Deleted for good in $days days',
      one: 'Deleted for good in 1 day',
      zero: 'Deleted for good today',
    );
    return '$_temp0';
  }

  @override
  String get deleteForever => 'Delete for good';

  @override
  String deleteConfirmTitle(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted files',
      one: '1 file',
    );
    return 'Delete $_temp0 for good?';
  }

  @override
  String deleteConfirmBody(String size) {
    return 'This frees $size. You can\'t undo this.';
  }

  @override
  String deleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files couldn\'t be deleted.',
      one: '1 file couldn\'t be deleted.',
    );
    return '$_temp0';
  }

  @override
  String restoreCount(int count) {
    return 'Restore ($count)';
  }

  @override
  String restored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count files.',
      one: 'Restored 1 file.',
    );
    return '$_temp0';
  }

  @override
  String restoreFolderGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count files stayed in the trash because their folder no longer exists.',
      one: '1 file stayed in the trash because its folder no longer exists.',
    );
    return '$_temp0';
  }

  @override
  String restoreFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files couldn\'t be restored.',
      one: '1 file couldn\'t be restored.',
    );
    return '$_temp0';
  }

  @override
  String get settingsTrash => 'Trash';

  @override
  String get trashDaysSetting => 'Keep deleted files for';

  @override
  String get settingsGroups => 'Smart groups';

  @override
  String get oldMonthsSetting => 'Old means older than';

  @override
  String days(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String months(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get settingsFolders => 'Folders';

  @override
  String get removeAccess => 'Remove access';

  @override
  String removeAccessTitle(String app) {
    return 'Remove access to $app?';
  }

  @override
  String get removeAccessBody =>
      'Files from this folder that are in the trash are deleted for good first. Nothing else is changed.';

  @override
  String get settingsAbout => 'About';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyBody =>
      'No internet permission, no analytics, no ads. Everything happens on your phone.';

  @override
  String get aboutAndLicenses => 'About and licenses';

  @override
  String get legalese => 'Open source under the MIT license.';

  @override
  String get chooseFolderAgain => 'Choose folder again';

  @override
  String get byTypeTitle => 'By type';
}
