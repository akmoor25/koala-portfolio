// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Trip Itinerary';

  @override
  String get launchTagline => 'Plan trips together with family and friends';

  @override
  String get start => 'Get started';

  @override
  String get connectFailed =>
      'Couldn\'t connect. Check your connection and try again.';

  @override
  String get portfolioNoticeTitle => 'This app is for a portfolio only';

  @override
  String get portfolioNoticeBody =>
      'This app is published as the developer\'s portfolio and is not a service for the general public. Features may change or stop, and data may be deleted, without notice, so the app may become unavailable. Please don\'t enter anything important.';

  @override
  String get crashTestSent => 'Sent a test error to Crashlytics';

  @override
  String get launchAgreement =>
      'By getting started, you agree to the Terms of Use and the Privacy Policy.';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get legalOpenFailed =>
      'Couldn\'t open the document. Please check your network.';

  @override
  String get legalCopyUrl => 'Copy URL';

  @override
  String get legalUrlCopied => 'Copied the URL';

  @override
  String get crashTestUnavailable => 'Crashlytics is not connected';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get editMode => 'Edit';

  @override
  String get doneEditing => 'Done editing';

  @override
  String get editMark => 'Edit this plan';

  @override
  String get addToDay => 'Add a plan on this day';

  @override
  String get addAfterMark => 'Add a plan after this one';

  @override
  String get openNote => 'Notes';

  @override
  String get copy => 'Copy';

  @override
  String get delete => 'Delete';

  @override
  String get keep => 'Keep';

  @override
  String get deleteWarning => 'Deleted items can\'t be restored.';

  @override
  String deleteQuestion(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get joinTrip => 'Join a trip';

  @override
  String get newTrip => 'New trip';

  @override
  String get emptyTrips =>
      'No trips yet.\nCreate one with ＋ at the top right, or add the samples to try the app.';

  @override
  String get addSamples => 'Add sample trips';

  @override
  String get samplesSubtitle => '3 Japan trips + 5 regional trips';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameNotSet => 'Not set';

  @override
  String nicknameHelper(int max) {
    return 'Shown to other people as your name, and in notifications (up to $max characters)';
  }

  @override
  String nicknameInvalid(int max) {
    return 'Enter a nickname of 1 to $max characters';
  }

  @override
  String get qrFilled => 'Scanned. Check your nickname, then tap Join.';

  @override
  String get notifJoinedTitle => 'Someone joined';

  @override
  String notifJoinedBody(String title, String nickname) {
    return '$nickname joined \"$title\"';
  }

  @override
  String notifJoinedBodyAnonymous(String title) {
    return 'A friend joined \"$title\"';
  }

  @override
  String get notifLeftTitle => 'Someone left';

  @override
  String notifLeftBody(String title, String nickname) {
    return '$nickname left \"$title\"';
  }

  @override
  String notifLeftBodyAnonymous(String title) {
    return 'A friend left \"$title\"';
  }

  @override
  String get notifUnavailableTitle => 'You can no longer access the trip';

  @override
  String notifDeletedBody(String owner, String title) {
    return '$owner deleted \"$title\"';
  }

  @override
  String notifDeletedBodyAnonymous(String title) {
    return '\"$title\" was deleted';
  }

  @override
  String notifStoppedBody(String owner, String title) {
    return '$owner stopped shared editing of \"$title\"';
  }

  @override
  String notifStoppedBodyAnonymous(String title) {
    return 'Shared editing of \"$title\" was stopped';
  }

  @override
  String get aboutApp => 'About this app';

  @override
  String get joinedTrip => 'Joined the trip';

  @override
  String samplesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count sample trips',
      one: 'Added 1 sample trip',
    );
    return '$_temp0';
  }

  @override
  String addingSamplesProgress(int completed, int total) {
    return 'Writing $completed / $total items';
  }

  @override
  String buildLabel(String commit) {
    return 'Build: $commit';
  }

  @override
  String get newTripDialogTitle => 'New trip';

  @override
  String get titleLabel => 'Title';

  @override
  String get create => 'Create';

  @override
  String get changeTitle => 'Change the title';

  @override
  String get changeCover => 'Change the cover (emoji)';

  @override
  String get sharedEditingSettings => 'Shared editing settings (on)';

  @override
  String get startSharedEditing => 'Share for editing';

  @override
  String get deleteTrip => 'Delete this trip';

  @override
  String get leaveTrip => 'Leave this trip';

  @override
  String get coverDialogTitle => 'Cover emoji and color';

  @override
  String get emojiLabel => 'Enter an emoji';

  @override
  String leaveQuestion(String title) {
    return 'Leave “$title”?';
  }

  @override
  String get leaveBody =>
      'It will disappear from your list. The trip itself stays, and you can join again with its ID and passphrase.';

  @override
  String get leave => 'Leave';

  @override
  String get taskSaveNickname => 'Saving the nickname';

  @override
  String get taskCreateTrip => 'Creating the trip';

  @override
  String get taskAddSamples => 'Adding the samples';

  @override
  String get taskUpdateTrip => 'Updating the trip';

  @override
  String get taskDeleteTrip => 'Deleting the trip';

  @override
  String get taskEnableSharing => 'Turning on shared editing';

  @override
  String get taskDisableSharing => 'Stopping shared editing';

  @override
  String get taskLeaveTrip => 'Leaving the trip';

  @override
  String get taskUpdatePeriod => 'Updating the trip dates';

  @override
  String get taskAddPlan => 'Adding the plan';

  @override
  String get taskUpdatePlan => 'Updating the plan';

  @override
  String get taskDeletePlan => 'Deleting the plan';

  @override
  String get taskDeleteAccount => 'Deleting the account and data';

  @override
  String get deleteAccountTitle => 'Delete account and data';

  @override
  String get deleteAccountSubtitle =>
      'Deletes this device\'s anonymous account and your data on the server';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account and data?';

  @override
  String get deleteAccountConfirmBody =>
      'All trips you own will be deleted (participants will lose access, too). You will leave the trips you joined. Your notification registration, anonymous user ID and nickname are deleted as well. This can\'t be undone.\n\nSteps and notes you wrote in other people\'s trips stay in those trips.\n\nThe cache on this device is removed when you uninstall the app.';

  @override
  String get deleteAccountProgress => 'Deleting…';

  @override
  String get deleteAccountDone => 'Your account and data were deleted.';

  @override
  String get deleteAccountUnavailable =>
      'Your account was deleted or your session is no longer valid, so you have been signed out. Deletion of data on the server has not been confirmed.';

  @override
  String get sessionLostTitle => 'You\'ve been signed out';

  @override
  String get sessionLostBody =>
      'This account was deleted or your session is no longer valid. You\'ll return to the start screen. Tap Get started to begin as a new anonymous user.';

  @override
  String get sessionLostOnLaunchBody =>
      'This account was deleted or your session is no longer valid. Tap Get started to begin as a new anonymous user.';

  @override
  String taskFailed(String task) {
    return '$task failed. Check your connection.';
  }

  @override
  String taskUnconfirmed(String task) {
    return '$task: the result couldn\'t be confirmed. It may be applied when the connection returns.';
  }

  @override
  String get noteSaveFailed =>
      'Couldn\'t save the note. Check your connection.';

  @override
  String get noteResetUnconfirmed =>
      'Couldn\'t confirm whether the note was reset. It may be applied when the connection returns.';

  @override
  String get noteLimit =>
      'Use up to 1000 characters per paragraph and 500 paragraphs. The change was not applied.';

  @override
  String get noteUnsupported => 'Only text and text formatting are supported.';

  @override
  String get noteReceivedLimit =>
      'The received note exceeds the limits. Its contents are preserved. Reduce it to 1000 characters per paragraph and 500 paragraphs.';

  @override
  String get noteResetRemotely => 'Another member reset this note.';

  @override
  String get noteLineDeleted =>
      'Another member deleted a paragraph you were editing.';

  @override
  String get noteUnreadable =>
      'This note cannot be read in the current format. Discard it and start an empty note? This cannot be undone.';

  @override
  String get noteDiscard => 'Discard note';

  @override
  String get noteRetry => 'Retry';

  @override
  String get noteKeepEditing => 'Keep editing';

  @override
  String get noteLeaveUnsaved => 'Leave without waiting for save';

  @override
  String get noteReadFailed =>
      'Couldn\'t load the note. Check your connection.';

  @override
  String get noteColorTitle => 'Text color';

  @override
  String get noteColorDefault => 'Default color';

  @override
  String get noteColorRed => 'Red';

  @override
  String get noteColorOrange => 'Orange';

  @override
  String get noteColorGreen => 'Green';

  @override
  String get noteColorTeal => 'Teal';

  @override
  String get noteColorBlue => 'Blue';

  @override
  String get noteColorPurple => 'Purple';

  @override
  String get noteColorPink => 'Pink';

  @override
  String get noteColorBrown => 'Brown';

  @override
  String get tripIdInvalid =>
      'A trip ID has 12 characters. Check what you entered.';

  @override
  String passphraseTooShort(int min) {
    return 'Enter a passphrase of at least $min characters.';
  }

  @override
  String get joinInvalid => 'Check what you entered.';

  @override
  String get joinRejected =>
      'The trip ID or the passphrase is wrong, or shared editing has been stopped.';

  @override
  String get joinAlready => 'You have already joined this trip.';

  @override
  String get joinNetwork => 'Couldn\'t communicate. Check your connection.';

  @override
  String get joinUnconfirmed =>
      'Couldn\'t confirm whether you joined. It may be applied when the connection returns.';

  @override
  String get joinIdCheck => 'Check the public trip ID you entered.';

  @override
  String get joinIntro =>
      'Scan the QR code your friend showed you, or enter the public trip ID and the passphrase. You join when you tap Join.';

  @override
  String get scanQr => 'Scan a QR code';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get join => 'Join';

  @override
  String get cameraDenied =>
      'Camera access isn\'t allowed. Allow it in Settings, or go back and enter the ID and the passphrase.';

  @override
  String get cameraFailed =>
      'Couldn\'t use the camera. Go back and enter the ID and the passphrase.';

  @override
  String get notOurQr => 'This isn\'t a QR code for shared editing in this app';

  @override
  String get tripId => 'Public trip ID';

  @override
  String get tripIdCheckInput =>
      'Check what you entered (characters in red can\'t be used)';

  @override
  String get copied => 'Copied';

  @override
  String get stopSharingQuestion => 'Stop shared editing?';

  @override
  String get stopSharingBody =>
      'No one can join, and everyone else is removed from this trip and can no longer see it. If you turn shared editing on again, they need to join again.';

  @override
  String get tripNoLongerAvailable =>
      'This trip is no longer available. Shared editing may have been stopped.';

  @override
  String get stop => 'Stop';

  @override
  String get sharedEditing => 'Shared editing';

  @override
  String get changePassphraseIntro =>
      'Choose a new passphrase. People who have already joined can keep editing.';

  @override
  String get enableSharingIntro =>
      'Once shared editing is on, anyone who knows the public trip ID and the passphrase can join this trip and edit it together.';

  @override
  String passphraseMinHelper(int min) {
    return 'At least $min characters';
  }

  @override
  String get generate => 'Generate';

  @override
  String get changePassphrase => 'Change the passphrase';

  @override
  String get enableSharing => 'Turn on shared editing';

  @override
  String get friendHint =>
      'Your friends can join by scanning this QR code, or by entering the ID and the passphrase above.';

  @override
  String get qrWarning =>
      'The QR code contains the passphrase. Show it only to people you trust.';

  @override
  String get passphraseNotSaved =>
      'The passphrase is saved only on the device that set it. It isn\'t saved on this device, so the ID and the passphrase can\'t be shown again. Set a new passphrase.';

  @override
  String get stopSharing => 'Stop shared editing';

  @override
  String get endBeforeStart => 'The end must be after the start';

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'End';

  @override
  String get timeZone => 'Time zone';

  @override
  String get approxLabel => 'Approx.';

  @override
  String get approxMark => '≈';

  @override
  String get remarkLabel => 'Speech bubble note';

  @override
  String get linkLabel => 'Link';

  @override
  String get iconLabel => 'Icon';

  @override
  String get zoneSearchHint => 'Search by city';

  @override
  String deviceZone(String id) {
    return '$id (this device)';
  }

  @override
  String othersEditing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other members are editing',
      one: '1 other member is editing',
    );
    return '$_temp0';
  }
}
