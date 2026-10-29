// FlutterFire CLI で生成したファイル。
// ignore_for_file: lines_longer_than_80_chars
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase アプリで使う既定の [FirebaseOptions]。
///
/// 使用例:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    // ignore: missing_enum_constant_in_switch
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for fuchsia - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD2UqDOZYb6RZKdwX5iMomx1-pOQWhcTkg',
    appId: '1:893674346151:android:93299de69466c41d036d82',
    messagingSenderId: '893674346151',
    projectId: 'koala-portfolio',
    databaseURL: 'https://koala-portfolio-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'koala-portfolio.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAdArzEjwfdmYd0h5ONSn4bsTCX27NBEkw',
    appId: '1:893674346151:ios:55ebc651617a3b34036d82',
    messagingSenderId: '893674346151',
    projectId: 'koala-portfolio',
    databaseURL: 'https://koala-portfolio-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'koala-portfolio.firebasestorage.app',
    iosBundleId: 'io.akmoor25.koala-portfolio',
  );
}
