import 'package:flutter/material.dart';

import '../features/media/domain/media_report.dart';
import '../features/media/domain/media_source.dart';
import '../features/media/domain/media_type.dart';
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
    SmartGroup.oldForwards => l10n.groupOldForwards,
    SmartGroup.sentCopies => l10n.groupSentCopies,
  };

  String description(AppLocalizations l10n, {required int oldAfterMonths}) =>
      switch (this) {
        SmartGroup.largest => l10n.groupLargestDescription,
        SmartGroup.oldForwards => l10n.groupOldForwardsDescription(
          oldAfterMonths,
        ),
        SmartGroup.sentCopies => l10n.groupSentCopiesDescription,
      };

  IconData get icon => switch (this) {
    SmartGroup.largest => Icons.straighten,
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
