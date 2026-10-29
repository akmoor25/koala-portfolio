import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_button.dart';
import '../components/portfolio_notice.dart';
import '../components/readable_width.dart';
import '../components/session_lost_dialog.dart';
import '../components/spacing.dart';
import '../data/app_services_scope.dart';
import '../l10n/l10n.dart';
import '../leaflets/leaflets_screen.dart';
import '../legal/legal_links.dart';
import 'launch_model.dart';

/// 起動直後の画面。アカウント登録なしで、匿名のまま Firebase へ進む。
class LaunchScreen extends StatelessWidget {
  /// [connect] を省くと Firebase に接続する。テストでは接続先を差し替える。
  const LaunchScreen({super.key, this.connect});

  /// 接続先を用意する処理。
  final Connector? connect;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LaunchModel>(
      create: (_) => LaunchModel(connect: connect),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.appName)),
        body: Consumer<LaunchModel>(
          builder: (context, model, child) {
            return SingleChildScrollView(
              padding: AppInsets.large,
              child: ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const VGap.large(),
                    // Column の stretch で幅が画面いっぱいに広げられ、角丸が画像の外側に
                    // かかってしまうため、Center で制約をゆるめて 96 の大きさに保つ。
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/app_icon/app_icon.png',
                          width: 96,
                          height: 96,
                        ),
                      ),
                    ),
                    const VGap.medium(),
                    Text(
                      context.l10n.launchTagline,
                      textAlign: TextAlign.center,
                    ),
                    const VGap.large(),
                    const PortfolioNotice(),
                    const VGap.medium(),
                    const LegalLinks(),
                    const VGap.medium(),
                    AppButton(
                      kind: AppButtonKind.primary,
                      expand: true,
                      busy: model.busy,
                      onPressed: () => _start(context, model),
                      icon: Icons.play_arrow,
                      label: context.l10n.start,
                    ),
                    const VGap.medium(),
                    Text(
                      context.l10n.launchAgreement,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (model.failed) ...[
                      const VGap.medium(),
                      Text(
                        context.l10n.connectFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, LaunchModel model) async {
    final session = context.session;
    final navigator = Navigator.of(context);
    final services = await model.start();
    if (services == null) {
      if (model.accountLost && context.mounted) {
        await showSessionLostDialog(context, onLaunch: true);
      }
      return;
    }
    session.start(services, connect: connect);
    await navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const LeafletsScreen()),
    );
  }
}
