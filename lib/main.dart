import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import 'data/app_session.dart';
import 'error_handlers.dart';
import 'helper/device_zone_watcher.dart';
import 'helper/time_zones.dart';
import 'l10n/l10n.dart';
import 'launch/launch_model.dart';
import 'launch/launch_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  await initTimeZones();
  // google_fonts は実行時にフォントを取得するため、ライセンスが自動では登録されない。
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/BIZ_UDGothic_OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['BIZ UDPGothic'], text);
  });
  runApp(
    ChangeNotifierProvider<AppSession>(
      create: (_) => AppSession(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  /// [connect] を省くと、起動画面から Firebase に匿名で接続する。
  /// 統合テストでは、通信しない接続先に差し替える。
  const MyApp({super.key, this.connect, this.locale});

  /// 接続先を用意する処理。
  final Connector? connect;

  /// 言語を固定する。統合テストで、端末の言語に依らず、日本語と英語の画面を撮るために使う。
  /// 省くと、端末の言語に従う。
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appName,
      // デバッグビルドでも、右上の「DEBUG」の帯を出さない。
      // main() を通らない統合テストの撮影でも効くよう、ここで決める。
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) =>
          DeviceZoneWatcher(child: child ?? const SizedBox.shrink()),
      locale: locale,
      home: LaunchScreen(connect: connect),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: supportedAppLocales,
      // 端末の言語が日本語なら日本語、それ以外は英語。
      localeListResolutionCallback: resolveAppLocale,
    );
  }
}
