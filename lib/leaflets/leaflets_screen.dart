import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_button.dart';
import '../components/session_lost_dialog.dart';
import '../components/spacing.dart';
import '../data/app_services_scope.dart';
import '../data/sample_leaflets.dart';
import '../entity/leaflet_entity.dart';
import '../l10n/l10n.dart';
import '../launch/launch_screen.dart';
import '../marks/marks_screen.dart';
import '../notifications/push_message.dart';
import '../sharing/join_screen.dart';
import '../theme/app_theme.dart';
import 'leaflet_card.dart';
import 'leaflets_dialogs.dart';
import 'leaflets_model.dart';

/// カードの間隔（横と縦）。
const _gridSpacing = 12.0;

/// 文字サイズの設定による倍率を測る、基準の文字の大きさ（Material の本文の標準）。
const _cardTextSize = 14.0;

/// 一覧に並べるカードの列数。
///
/// 画面の横幅（[width]）に合わせて増やす。カードの文字は文字サイズ（[textFactor]）で大きくなるため、
/// 文字が大きいほどカードの最小の幅を広げて、列を減らす。
int leafletGridColumns(double width, {double textFactor = 1}) {
  const minCardWidth = 120.0;
  const maxColumns = 6;
  final minWidth = minCardWidth * textFactor.clamp(1.0, 2.0);
  final columns = ((width + _gridSpacing) / (minWidth + _gridSpacing)).floor();
  return columns.clamp(1, maxColumns);
}

/// しおりの一覧。年ごとにグループ化して表示する。
class LeafletsScreen extends StatefulWidget {
  /// 何も受け取らない。
  const LeafletsScreen({super.key});

  @override
  State<LeafletsScreen> createState() => _LeafletsScreenState();
}

class _LeafletsScreenState extends State<LeafletsScreen> {
  // didChangeDependencies で必ず作る。context が要るため initState では作れない。
  LeafletsModel? _model;
  LeafletsModel get model => _model!;
  SampleInstallProgress? _sampleProgress;
  bool _addingSamples = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final existing = _model;
    if (existing != null) {
      existing.l10n = context.l10n;
      return;
    }
    _model = LeafletsModel(context.services)
      ..l10n = context.l10n
      ..onWriteError = _showMessage
      ..addListener(_closeIfAccessLost)
      ..addListener(_openPending)
      ..addListener(_returnIfSessionLost)
      ..fetchLeafletsEntity();
    // 利用中にコンソールなどで削除されても、トークンの更新（約 1 時間ごと）まで気づけない。前面に戻るたびに確かめる。
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(model.checkAccount()),
    );
    _listenToNotifications();
  }

  AppLifecycleListener? _lifecycle;

  // 通知を、アプリが前面にあるときは、画面の中に出し、タップで開かれたときは、行き先へ移る。
  void _listenToNotifications() {
    final push = model.push;
    _notificationSubscriptions
      ..add(push.foregroundMessages.listen(_showBanner))
      ..add(push.openedMessages.listen(_open));
    unawaited(
      push.initialMessage().then((message) {
        if (message != null) _open(message);
      }),
    );
  }

  void _showBanner(PushMessage message) {
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${message.headline(l10n)}\n${message.body(l10n)}'),
        ),
      );
  }

  // しおりの一覧が届く前に開かれたときは、届いてから移る。
  PushMessage? _pending;

  void _open(PushMessage message) {
    _pending = message;
    _openPending();
  }

  void _openPending() {
    final message = _pending;
    if (message == null || !mounted || !model.hasLoaded || model.sessionLost) {
      return;
    }
    _pending = null;
    final leaflet = message.opensLeaflet
        ? model.leafletByKey(message.leafletId)
        : null;
    Navigator.popUntil(context, (route) => route.isFirst);
    if (leaflet != null) {
      unawaited(_openLeaflet(leaflet));
    } else {
      // 削除や停止で、しおりにアクセスできなくなった（参加の通知でも、すでに無いとき）。
      _showMessage(context.l10n.notifUnavailableTitle);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  final List<StreamSubscription<PushMessage>> _notificationSubscriptions = [];

  @override
  void dispose() {
    _lifecycle?.dispose();
    for (final subscription in _notificationSubscriptions) {
      unawaited(subscription.cancel());
    }
    _model?.dispose();
    super.dispose();
  }

  // 開いているしおりのキー。オーナーが共同編集を止めて外れたときに、一覧へ戻すために使う。
  String? _openedKey;

  void _closeIfAccessLost() {
    final key = _openedKey;
    if (key == null ||
        model.leafletByKey(key) != null ||
        model.sessionLost ||
        !mounted) {
      return;
    }
    _openedKey = null;
    Navigator.popUntil(context, (route) => route.isFirst);
    _showMessage(context.l10n.tripNoLongerAvailable);
  }

  bool _returningToLaunch = false;

  // 失効でサインアウトされたら、知らせてから起動画面へ戻す。旅程やノートを開いていても、すべて閉じる。
  void _returnIfSessionLost() {
    if (!model.sessionLost || _returningToLaunch || !mounted) return;
    _returningToLaunch = true;
    unawaited(_returnToLaunch());
  }

  Future<void> _returnToLaunch() async {
    final session = context.session;
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showSessionLostDialog(context);
    unawaited(
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (context) => LaunchScreen(connect: session.connect),
        ),
        (route) => false,
      ),
    );
  }

  Future<void> _openLeaflet(LeafletEntity leaflet) async {
    _openedKey = leaflet.key;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => MarksScreen(leaflet)),
    );
    _openedKey = null;
  }

  Future<void> _openJoin() async {
    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => JoinScreen(model: model)),
    );
    if (joined == true && mounted) _showMessage(context.l10n.joinedTrip);
  }

  Future<void> _addSamples() async {
    if (_addingSamples) return;
    setState(() => _addingSamples = true);
    try {
      final count = await model.addSampleLeaflets(
        onProgress: (progress) {
          if (mounted) setState(() => _sampleProgress = progress);
        },
      );
      if (count > 0 && mounted) _showMessage(context.l10n.samplesAdded(count));
    } finally {
      if (mounted) {
        setState(() {
          _addingSamples = false;
          _sampleProgress = null;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final session = context.session;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!await showDeleteAccountConfirmDialog(context)) return;
    if (!mounted) return;
    final closeProgress = showDeleteAccountProgress(context);
    final bool deleted;
    try {
      deleted = await model.deleteAccount();
    } finally {
      closeProgress();
    }
    if (!deleted || !mounted) return;
    final message = model.accountUnavailable
        ? l10n.deleteAccountUnavailable
        : l10n.deleteAccountDone;
    // 同じ uid には戻れないので、起動画面へ戻す。「はじめる」で、新しい匿名ユーザーになる。
    unawaited(
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (context) => LaunchScreen(connect: session.connect),
        ),
        (route) => false,
      ),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeafletsModel>.value(
      value: model,
      child: PopScope(
        canPop: !_addingSamples,
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.appName),
                actions: [
                  AppIconButton(
                    tooltip: context.l10n.joinTrip,
                    icon: Icons.group_add,
                    onPressed: () => unawaited(_openJoin()),
                  ),
                  AppIconButton(
                    tooltip: context.l10n.newTrip,
                    icon: Icons.add,
                    onPressed: () =>
                        unawaited(showLeafletCreationDialog(context, model)),
                  ),
                ],
              ),
              drawer: _buildDrawer(),
              body: Consumer<LeafletsModel>(
                builder: (context, model, child) {
                  final groupNames = model.getLeafletsGroupNames();
                  if (groupNames.isEmpty) return _buildEmptyState();
                  return ListView.builder(
                    itemCount: groupNames.length,
                    itemBuilder: (context, index) =>
                        _buildYearSection(groupNames[index]),
                  );
                },
              ),
            ),
            if (_addingSamples) _buildSampleProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleProgress() {
    final progress = _sampleProgress;
    final completed = progress?.completed ?? 0;
    final total = progress?.total ?? 1;
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Card(
            child: Padding(
              padding: AppInsets.large,
              child: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.taskAddSamples,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const VGap.small(),
                    if (progress != null)
                      Text(progress.title, textAlign: TextAlign.center),
                    const VGap.medium(),
                    LinearProgressIndicator(value: progress?.fraction ?? 0),
                    const VGap.small(),
                    Text(context.l10n.addingSamplesProgress(completed, total)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppInsets.large,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.emptyTrips, textAlign: TextAlign.center),
            const VGap.medium(),
            AppButton(
              kind: AppButtonKind.accent,
              onPressed: () => unawaited(_addSamples()),
              icon: Icons.auto_awesome,
              label: context.l10n.addSamples,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    // ライトテーマでは、ドロワーのアイコンを主色（0xff13b1f2）にそろえる。
    final iconColor = Theme.of(context).koala.brand;
    return Drawer(
      child: ListTileTheme(
        data: ListTileTheme.of(context).copyWith(iconColor: iconColor),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text(context.l10n.joinTrip),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_openJoin());
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(context.l10n.addSamples),
                subtitle: Text(context.l10n.samplesSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_addSamples());
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(context.l10n.nickname),
                subtitle: ListenableBuilder(
                  listenable: model,
                  builder: (context, child) =>
                      Text(model.nickname ?? context.l10n.nicknameNotSet),
                ),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(showNicknameDialog(context, model));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: Text(context.l10n.deleteAccountTitle),
                subtitle: Text(context.l10n.deleteAccountSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_deleteAccount());
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.aboutApp),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(showAppAboutDialog(context));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearSection(String groupName) {
    return Consumer<LeafletsModel>(
      builder: (context, model, child) {
        final leaflets = model.getLeafletsBy(groupName);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(
                left: AppSpace.large,
                top: AppSpace.medium,
                bottom: AppSpace.small,
              ),
              child: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(
                left: AppSpace.medium,
                right: AppSpace.medium,
              ),
              color: Theme.of(context).primaryColor,
              height: 4,
            ),
            Container(
              margin: AppInsets.medium,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // OS の非線形な文字拡大では、大きさごとに倍率が違うので、カードの文字の大きさで測る。
                  final crossAxisCount = leafletGridColumns(
                    constraints.maxWidth,
                    textFactor:
                        MediaQuery.textScalerOf(context).scale(_cardTextSize) /
                        _cardTextSize,
                  );
                  final width =
                      (constraints.maxWidth -
                          _gridSpacing * (crossAxisCount - 1)) /
                      crossAxisCount;
                  return Wrap(
                    spacing: _gridSpacing,
                    runSpacing: 16,
                    children: [
                      for (final leaflet in leaflets)
                        SizedBox(
                          width: width,
                          child: LeafletCard(
                            leaflet: leaflet,
                            showsSharedBadge:
                                leaflet.shared || !model.isOwner(leaflet),
                            onTap: () => unawaited(_openLeaflet(leaflet)),
                            onLongPress: () => unawaited(
                              showLeafletOptionDialog(context, model, leaflet),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
