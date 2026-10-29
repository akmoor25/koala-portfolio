import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../components/app_button.dart';
import '../components/notice_banner.dart';
import '../components/readable_width.dart';
import '../components/spacing.dart';
import '../helper/nickname_policy.dart';
import '../l10n/l10n.dart';
import '../leaflets/leaflets_model.dart';
import 'leaflet_id_field.dart';
import 'nickname_field.dart';
import 'share_code.dart';

Widget _defaultScanScreen(BuildContext context) => const ScanScreen();

/// 共同編集のしおりに参加する画面。QR の読み取りか、ID とあいことばの入力で参加する。
class JoinScreen extends StatefulWidget {
  /// 参加の処理を [model] に任せる。
  const JoinScreen({
    super.key,
    required this.model,
    this.scanBuilder = _defaultScanScreen,
  });

  /// しおり一覧の状態。
  final LeafletsModel model;

  /// QR コードの読み取り画面を作る。テストでは、カメラを使わない画面に差し替える。
  final WidgetBuilder scanBuilder;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _idController = LeafletIdController();
  final _passphraseController = TextEditingController();
  final _nicknameController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNickname());
  }

  /// ニックネームの初期値（保存済みか、端末の機種名）を入れる。
  Future<void> _loadNickname() async {
    final suggested = await widget.model.suggestedNickname();
    if (!mounted || _nicknameController.text.isNotEmpty) return;
    _nicknameController.text = suggested;
  }

  @override
  void dispose() {
    _idController.dispose();
    _passphraseController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final credentials = await Navigator.push<JoinCredentials>(
      context,
      MaterialPageRoute(builder: widget.scanBuilder),
    );
    if (credentials == null || !mounted) return;
    // 読み取っても、参加はしない。ニックネームを確かめてから、「参加する」で参加する。
    _idController.value = credentials.leafletId;
    _passphraseController.text = credentials.passphrase;
    setState(() {
      _scanned = true;
      _error = null;
    });
  }

  bool get _canJoin =>
      _idController.isComplete &&
      isValidPassphrase(_passphraseController.text) &&
      isValidNickname(_nicknameController.text);

  Future<void> _join() async {
    if (_idController.hasInvalidCharacters) {
      setState(() => _error = context.l10n.joinIdCheck);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.model.joinLeaflet(
      _idController.value,
      _passphraseController.text,
      nickname: _nicknameController.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.joinTrip)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _idController,
          _passphraseController,
          _nicknameController,
        ]),
        builder: (context, child) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: AppInsets.medium,
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.joinIntro),
              const VGap.medium(),
              AppButton(
                kind: AppButtonKind.secondary,
                expand: true,
                onPressed: _busy ? null : () => unawaited(_scan()),
                icon: Icons.qr_code_scanner,
                label: context.l10n.scanQr,
              ),
              const VGap.large(),
              LeafletIdField(controller: _idController, enabled: !_busy),
              const VGap.medium(),
              TextField(
                controller: _passphraseController,
                enabled: !_busy,
                autocorrect: false,
                decoration: InputDecoration(labelText: context.l10n.passphrase),
              ),
              const VGap.medium(),
              NicknameField(controller: _nicknameController, enabled: !_busy),
              if (_scanned && _error == null) ...[
                const VGap.small(),
                Text(
                  context.l10n.qrFilled,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_error case final error?) ...[
                const VGap.medium(),
                NoticeBanner(kind: NoticeKind.danger, message: error),
              ],
              const VGap.medium(),
              AppButton(
                kind: AppButtonKind.accent,
                expand: true,
                busy: _busy,
                onPressed: _canJoin ? () => unawaited(_join()) : null,
                label: context.l10n.join,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// カメラで QR コードを読み取り、参加に必要な情報を返す画面。
class ScanScreen extends StatefulWidget {
  /// 何も受け取らない。
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  bool _unrecognized = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      final credentials = value == null ? null : parseJoinLink(value);
      if (credentials == null) continue;
      _done = true;
      Navigator.pop(context, credentials);
      return;
    }
    if (!_unrecognized) setState(() => _unrecognized = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.scanQr)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: AppInsets.large,
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? context.l10n.cameraDenied
                      : context.l10n.cameraFailed,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (_unrecognized)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: AppInsets.large,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(context.l10n.notOurQr),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
