import 'package:flutter/material.dart';

import '../features/browse/domain/browse_entry.dart';
import '../features/media/domain/media_report.dart';
import '../features/media/domain/media_source.dart';
import '../features/media/domain/media_type.dart';
import '../features/viewer/domain/view_kind.dart';
import '../l10n/app_localizations.dart';

/// Display names and icons for domain enums.
extension MediaTypeLabels on MediaType {
  String label(AppLocalizations l10n) => switch (this) {
    MediaType.video => l10n.typeVideos,
    MediaType.image => l10n.typeImages,
    MediaType.voiceNote => l10n.typeVoiceNotes,
    MediaType.audio => l10n.typeAudio,
    MediaType.document => l10n.typeDocuments,
    MediaType.sticker => l10n.typeStickers,
    MediaType.gif => l10n.typeGifs,
    MediaType.status => l10n.typeStatuses,
    MediaType.other => l10n.typeOther,
  };

  IconData get icon => switch (this) {
    MediaType.video => Icons.videocam_outlined,
    MediaType.image => Icons.image_outlined,
    MediaType.voiceNote => Icons.mic_none,
    MediaType.audio => Icons.music_note_outlined,
    MediaType.document => Icons.description_outlined,
    MediaType.sticker => Icons.emoji_emotions_outlined,
    MediaType.gif => Icons.gif_box_outlined,
    MediaType.status => Icons.donut_large,
    MediaType.other => Icons.insert_drive_file_outlined,
  };
}

extension SmartGroupLabels on SmartGroup {
  String title(AppLocalizations l10n) => switch (this) {
    SmartGroup.largest => l10n.groupLargest,
    SmartGroup.duplicates => l10n.groupDuplicates,
    SmartGroup.oldForwards => l10n.groupOldForwards,
    SmartGroup.sentCopies => l10n.groupSentCopies,
  };

  String description(AppLocalizations l10n, {required int oldAfterMonths}) =>
      switch (this) {
        SmartGroup.largest => l10n.groupLargestDescription,
        SmartGroup.duplicates => l10n.groupDuplicatesDescription,
        SmartGroup.oldForwards => l10n.groupOldForwardsDescription(
          oldAfterMonths,
        ),
        SmartGroup.sentCopies => l10n.groupSentCopiesDescription,
      };

  IconData get icon => switch (this) {
    SmartGroup.largest => Icons.straighten,
    SmartGroup.duplicates => Icons.content_copy,
    SmartGroup.oldForwards => Icons.history,
    SmartGroup.sentCopies => Icons.north_east,
  };
}

extension ChatAppLabels on ChatApp {
  String label(AppLocalizations l10n) => switch (this) {
    ChatApp.whatsapp => l10n.appWhatsApp,
    ChatApp.whatsappBusiness => l10n.appWhatsAppBusiness,
    ChatApp.other => l10n.appOtherFolder,
  };
}

extension MediaSourceLabels on MediaSource {
  /// The app's name, or the folder's own name for any other folder.
  String label(AppLocalizations l10n) {
    if (app != ChatApp.other) return app.label(l10n);
    final name = folderName;
    return name.isEmpty ? l10n.appOtherFolder : name;
  }
}

extension BrowseSortLabels on BrowseSort {
  String label(AppLocalizations l10n) => switch (this) {
    BrowseSort.name => l10n.sortName,
    BrowseSort.newest => l10n.sortNewest,
    BrowseSort.oldest => l10n.sortOldest,
    BrowseSort.largest => l10n.sortLargest,
    BrowseSort.smallest => l10n.sortSmallest,
  };
}

extension ViewKindIcons on ViewKind {
  IconData get icon => switch (this) {
    ViewKind.image => Icons.image_outlined,
    ViewKind.video => Icons.videocam_outlined,
    ViewKind.audio => Icons.graphic_eq,
    ViewKind.pdf => Icons.picture_as_pdf_outlined,
    ViewKind.text => Icons.article_outlined,
    ViewKind.other => Icons.insert_drive_file_outlined,
  };
}
