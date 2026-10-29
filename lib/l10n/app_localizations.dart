import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Trip Itinerary'**
  String get appName;

  /// No description provided for @launchTagline.
  ///
  /// In en, this message translates to:
  /// **'Plan trips together with family and friends'**
  String get launchTagline;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get start;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your connection and try again.'**
  String get connectFailed;

  /// No description provided for @portfolioNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'This app is for a portfolio only'**
  String get portfolioNoticeTitle;

  /// No description provided for @portfolioNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'This app is published as the developer\'s portfolio and is not a service for the general public. Features may change or stop, and data may be deleted, without notice, so the app may become unavailable. Please don\'t enter anything important.'**
  String get portfolioNoticeBody;

  /// No description provided for @crashTestSent.
  ///
  /// In en, this message translates to:
  /// **'Sent a test error to Crashlytics'**
  String get crashTestSent;

  /// No description provided for @launchAgreement.
  ///
  /// In en, this message translates to:
  /// **'By getting started, you agree to the Terms of Use and the Privacy Policy.'**
  String get launchAgreement;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @legalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the document. Please check your network.'**
  String get legalOpenFailed;

  /// No description provided for @legalCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get legalCopyUrl;

  /// No description provided for @legalUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied the URL'**
  String get legalUrlCopied;

  /// No description provided for @crashTestUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Crashlytics is not connected'**
  String get crashTestUnavailable;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @editMode.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMode;

  /// No description provided for @doneEditing.
  ///
  /// In en, this message translates to:
  /// **'Done editing'**
  String get doneEditing;

  /// No description provided for @editMark.
  ///
  /// In en, this message translates to:
  /// **'Edit this plan'**
  String get editMark;

  /// No description provided for @addToDay.
  ///
  /// In en, this message translates to:
  /// **'Add a plan on this day'**
  String get addToDay;

  /// No description provided for @addAfterMark.
  ///
  /// In en, this message translates to:
  /// **'Add a plan after this one'**
  String get addAfterMark;

  /// No description provided for @openNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get openNote;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleted items can\'t be restored.'**
  String get deleteWarning;

  /// No description provided for @deleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String deleteQuestion(String title);

  /// No description provided for @joinTrip.
  ///
  /// In en, this message translates to:
  /// **'Join a trip'**
  String get joinTrip;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @emptyTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips yet.\nCreate one with ＋ at the top right, or add the samples to try the app.'**
  String get emptyTrips;

  /// No description provided for @addSamples.
  ///
  /// In en, this message translates to:
  /// **'Add sample trips'**
  String get addSamples;

  /// No description provided for @samplesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'3 Japan trips + 5 regional trips'**
  String get samplesSubtitle;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get nicknameNotSet;

  /// No description provided for @nicknameHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown to other people as your name, and in notifications (up to {max} characters)'**
  String nicknameHelper(int max);

  /// No description provided for @nicknameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname of 1 to {max} characters'**
  String nicknameInvalid(int max);

  /// No description provided for @qrFilled.
  ///
  /// In en, this message translates to:
  /// **'Scanned. Check your nickname, then tap Join.'**
  String get qrFilled;

  /// No description provided for @notifJoinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone joined'**
  String get notifJoinedTitle;

  /// No description provided for @notifJoinedBody.
  ///
  /// In en, this message translates to:
  /// **'{nickname} joined \"{title}\"'**
  String notifJoinedBody(String title, String nickname);

  /// No description provided for @notifJoinedBodyAnonymous.
  ///
  /// In en, this message translates to:
  /// **'A friend joined \"{title}\"'**
  String notifJoinedBodyAnonymous(String title);

  /// No description provided for @notifLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone left'**
  String get notifLeftTitle;

  /// No description provided for @notifLeftBody.
  ///
  /// In en, this message translates to:
  /// **'{nickname} left \"{title}\"'**
  String notifLeftBody(String title, String nickname);

  /// No description provided for @notifLeftBodyAnonymous.
  ///
  /// In en, this message translates to:
  /// **'A friend left \"{title}\"'**
  String notifLeftBodyAnonymous(String title);

  /// No description provided for @notifUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'You can no longer access the trip'**
  String get notifUnavailableTitle;

  /// No description provided for @notifDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'{owner} deleted \"{title}\"'**
  String notifDeletedBody(String owner, String title);

  /// No description provided for @notifDeletedBodyAnonymous.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" was deleted'**
  String notifDeletedBodyAnonymous(String title);

  /// No description provided for @notifStoppedBody.
  ///
  /// In en, this message translates to:
  /// **'{owner} stopped shared editing of \"{title}\"'**
  String notifStoppedBody(String owner, String title);

  /// No description provided for @notifStoppedBodyAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Shared editing of \"{title}\" was stopped'**
  String notifStoppedBodyAnonymous(String title);

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get aboutApp;

  /// No description provided for @joinedTrip.
  ///
  /// In en, this message translates to:
  /// **'Joined the trip'**
  String get joinedTrip;

  /// No description provided for @samplesAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 sample trip} other{Added {count} sample trips}}'**
  String samplesAdded(int count);

  /// No description provided for @addingSamplesProgress.
  ///
  /// In en, this message translates to:
  /// **'Writing {completed} / {total} items'**
  String addingSamplesProgress(int completed, int total);

  /// No description provided for @buildLabel.
  ///
  /// In en, this message translates to:
  /// **'Build: {commit}'**
  String buildLabel(String commit);

  /// No description provided for @newTripDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTripDialogTitle;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @changeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the title'**
  String get changeTitle;

  /// No description provided for @changeCover.
  ///
  /// In en, this message translates to:
  /// **'Change the cover (emoji)'**
  String get changeCover;

  /// No description provided for @sharedEditingSettings.
  ///
  /// In en, this message translates to:
  /// **'Shared editing settings (on)'**
  String get sharedEditingSettings;

  /// No description provided for @startSharedEditing.
  ///
  /// In en, this message translates to:
  /// **'Share for editing'**
  String get startSharedEditing;

  /// No description provided for @deleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Delete this trip'**
  String get deleteTrip;

  /// No description provided for @leaveTrip.
  ///
  /// In en, this message translates to:
  /// **'Leave this trip'**
  String get leaveTrip;

  /// No description provided for @coverDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cover emoji and color'**
  String get coverDialogTitle;

  /// No description provided for @emojiLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter an emoji'**
  String get emojiLabel;

  /// No description provided for @leaveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Leave “{title}”?'**
  String leaveQuestion(String title);

  /// No description provided for @leaveBody.
  ///
  /// In en, this message translates to:
  /// **'It will disappear from your list. The trip itself stays, and you can join again with its ID and passphrase.'**
  String get leaveBody;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @taskSaveNickname.
  ///
  /// In en, this message translates to:
  /// **'Saving the nickname'**
  String get taskSaveNickname;

  /// No description provided for @taskCreateTrip.
  ///
  /// In en, this message translates to:
  /// **'Creating the trip'**
  String get taskCreateTrip;

  /// No description provided for @taskAddSamples.
  ///
  /// In en, this message translates to:
  /// **'Adding the samples'**
  String get taskAddSamples;

  /// No description provided for @taskUpdateTrip.
  ///
  /// In en, this message translates to:
  /// **'Updating the trip'**
  String get taskUpdateTrip;

  /// No description provided for @taskDeleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Deleting the trip'**
  String get taskDeleteTrip;

  /// No description provided for @taskEnableSharing.
  ///
  /// In en, this message translates to:
  /// **'Turning on shared editing'**
  String get taskEnableSharing;

  /// No description provided for @taskDisableSharing.
  ///
  /// In en, this message translates to:
  /// **'Stopping shared editing'**
  String get taskDisableSharing;

  /// No description provided for @taskLeaveTrip.
  ///
  /// In en, this message translates to:
  /// **'Leaving the trip'**
  String get taskLeaveTrip;

  /// No description provided for @taskUpdatePeriod.
  ///
  /// In en, this message translates to:
  /// **'Updating the trip dates'**
  String get taskUpdatePeriod;

  /// No description provided for @taskAddPlan.
  ///
  /// In en, this message translates to:
  /// **'Adding the plan'**
  String get taskAddPlan;

  /// No description provided for @taskUpdatePlan.
  ///
  /// In en, this message translates to:
  /// **'Updating the plan'**
  String get taskUpdatePlan;

  /// No description provided for @taskDeletePlan.
  ///
  /// In en, this message translates to:
  /// **'Deleting the plan'**
  String get taskDeletePlan;

  /// No description provided for @taskDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting the account and data'**
  String get taskDeleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account and data'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes this device\'s anonymous account and your data on the server'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and data?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All trips you own will be deleted (participants will lose access, too). You will leave the trips you joined. Your notification registration, anonymous user ID and nickname are deleted as well. This can\'t be undone.\n\nSteps and notes you wrote in other people\'s trips stay in those trips.\n\nThe cache on this device is removed when you uninstall the app.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountProgress.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get deleteAccountProgress;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Your account and data were deleted.'**
  String get deleteAccountDone;

  /// No description provided for @deleteAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted or your session is no longer valid, so you have been signed out. Deletion of data on the server has not been confirmed.'**
  String get deleteAccountUnavailable;

  /// No description provided for @sessionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out'**
  String get sessionLostTitle;

  /// No description provided for @sessionLostBody.
  ///
  /// In en, this message translates to:
  /// **'This account was deleted or your session is no longer valid. You\'ll return to the start screen. Tap Get started to begin as a new anonymous user.'**
  String get sessionLostBody;

  /// No description provided for @sessionLostOnLaunchBody.
  ///
  /// In en, this message translates to:
  /// **'This account was deleted or your session is no longer valid. Tap Get started to begin as a new anonymous user.'**
  String get sessionLostOnLaunchBody;

  /// No description provided for @taskFailed.
  ///
  /// In en, this message translates to:
  /// **'{task} failed. Check your connection.'**
  String taskFailed(String task);

  /// No description provided for @taskUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'{task}: the result couldn\'t be confirmed. It may be applied when the connection returns.'**
  String taskUnconfirmed(String task);

  /// No description provided for @noteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the note. Check your connection.'**
  String get noteSaveFailed;

  /// No description provided for @noteResetUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm whether the note was reset. It may be applied when the connection returns.'**
  String get noteResetUnconfirmed;

  /// No description provided for @noteLimit.
  ///
  /// In en, this message translates to:
  /// **'Use up to 1000 characters per paragraph and 500 paragraphs. The change was not applied.'**
  String get noteLimit;

  /// No description provided for @noteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only text and text formatting are supported.'**
  String get noteUnsupported;

  /// No description provided for @noteReceivedLimit.
  ///
  /// In en, this message translates to:
  /// **'The received note exceeds the limits. Its contents are preserved. Reduce it to 1000 characters per paragraph and 500 paragraphs.'**
  String get noteReceivedLimit;

  /// No description provided for @noteResetRemotely.
  ///
  /// In en, this message translates to:
  /// **'Another member reset this note.'**
  String get noteResetRemotely;

  /// No description provided for @noteLineDeleted.
  ///
  /// In en, this message translates to:
  /// **'Another member deleted a paragraph you were editing.'**
  String get noteLineDeleted;

  /// No description provided for @noteUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This note cannot be read in the current format. Discard it and start an empty note? This cannot be undone.'**
  String get noteUnreadable;

  /// No description provided for @noteDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard note'**
  String get noteDiscard;

  /// No description provided for @noteRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get noteRetry;

  /// No description provided for @noteKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get noteKeepEditing;

  /// No description provided for @noteLeaveUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Leave without waiting for save'**
  String get noteLeaveUnsaved;

  /// No description provided for @noteReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the note. Check your connection.'**
  String get noteReadFailed;

  /// No description provided for @noteColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get noteColorTitle;

  /// No description provided for @noteColorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default color'**
  String get noteColorDefault;

  /// No description provided for @noteColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get noteColorRed;

  /// No description provided for @noteColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get noteColorOrange;

  /// No description provided for @noteColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get noteColorGreen;

  /// No description provided for @noteColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get noteColorTeal;

  /// No description provided for @noteColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get noteColorBlue;

  /// No description provided for @noteColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get noteColorPurple;

  /// No description provided for @noteColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get noteColorPink;

  /// No description provided for @noteColorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get noteColorBrown;

  /// No description provided for @tripIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'A trip ID has 12 characters. Check what you entered.'**
  String get tripIdInvalid;

  /// No description provided for @passphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Enter a passphrase of at least {min} characters.'**
  String passphraseTooShort(int min);

  /// No description provided for @joinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check what you entered.'**
  String get joinInvalid;

  /// No description provided for @joinRejected.
  ///
  /// In en, this message translates to:
  /// **'The trip ID or the passphrase is wrong, or shared editing has been stopped.'**
  String get joinRejected;

  /// No description provided for @joinAlready.
  ///
  /// In en, this message translates to:
  /// **'You have already joined this trip.'**
  String get joinAlready;

  /// No description provided for @joinNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t communicate. Check your connection.'**
  String get joinNetwork;

  /// No description provided for @joinUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm whether you joined. It may be applied when the connection returns.'**
  String get joinUnconfirmed;

  /// No description provided for @joinIdCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the public trip ID you entered.'**
  String get joinIdCheck;

  /// No description provided for @joinIntro.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code your friend showed you, or enter the public trip ID and the passphrase. You join when you tap Join.'**
  String get joinIntro;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get scanQr;

  /// No description provided for @passphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get passphrase;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access isn\'t allowed. Allow it in Settings, or go back and enter the ID and the passphrase.'**
  String get cameraDenied;

  /// No description provided for @cameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use the camera. Go back and enter the ID and the passphrase.'**
  String get cameraFailed;

  /// No description provided for @notOurQr.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a QR code for shared editing in this app'**
  String get notOurQr;

  /// No description provided for @tripId.
  ///
  /// In en, this message translates to:
  /// **'Public trip ID'**
  String get tripId;

  /// No description provided for @tripIdCheckInput.
  ///
  /// In en, this message translates to:
  /// **'Check what you entered (characters in red can\'t be used)'**
  String get tripIdCheckInput;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @stopSharingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Stop shared editing?'**
  String get stopSharingQuestion;

  /// No description provided for @stopSharingBody.
  ///
  /// In en, this message translates to:
  /// **'No one can join, and everyone else is removed from this trip and can no longer see it. If you turn shared editing on again, they need to join again.'**
  String get stopSharingBody;

  /// No description provided for @tripNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer available. Shared editing may have been stopped.'**
  String get tripNoLongerAvailable;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @sharedEditing.
  ///
  /// In en, this message translates to:
  /// **'Shared editing'**
  String get sharedEditing;

  /// No description provided for @changePassphraseIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a new passphrase. People who have already joined can keep editing.'**
  String get changePassphraseIntro;

  /// No description provided for @enableSharingIntro.
  ///
  /// In en, this message translates to:
  /// **'Once shared editing is on, anyone who knows the public trip ID and the passphrase can join this trip and edit it together.'**
  String get enableSharingIntro;

  /// No description provided for @passphraseMinHelper.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String passphraseMinHelper(int min);

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @changePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Change the passphrase'**
  String get changePassphrase;

  /// No description provided for @enableSharing.
  ///
  /// In en, this message translates to:
  /// **'Turn on shared editing'**
  String get enableSharing;

  /// No description provided for @friendHint.
  ///
  /// In en, this message translates to:
  /// **'Your friends can join by scanning this QR code, or by entering the ID and the passphrase above.'**
  String get friendHint;

  /// No description provided for @qrWarning.
  ///
  /// In en, this message translates to:
  /// **'The QR code contains the passphrase. Show it only to people you trust.'**
  String get qrWarning;

  /// No description provided for @passphraseNotSaved.
  ///
  /// In en, this message translates to:
  /// **'The passphrase is saved only on the device that set it. It isn\'t saved on this device, so the ID and the passphrase can\'t be shown again. Set a new passphrase.'**
  String get passphraseNotSaved;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop shared editing'**
  String get stopSharing;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start'**
  String get endBeforeStart;

  /// No description provided for @startLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// No description provided for @endLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endLabel;

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timeZone;

  /// No description provided for @approxLabel.
  ///
  /// In en, this message translates to:
  /// **'Approx.'**
  String get approxLabel;

  /// No description provided for @approxMark.
  ///
  /// In en, this message translates to:
  /// **'≈'**
  String get approxMark;

  /// No description provided for @remarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech bubble note'**
  String get remarkLabel;

  /// No description provided for @linkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkLabel;

  /// No description provided for @iconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get iconLabel;

  /// No description provided for @zoneSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by city'**
  String get zoneSearchHint;

  /// No description provided for @deviceZone.
  ///
  /// In en, this message translates to:
  /// **'{id} (this device)'**
  String deviceZone(String id);

  /// No description provided for @othersEditing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other member is editing} other{{count} other members are editing}}'**
  String othersEditing(int count);
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
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
