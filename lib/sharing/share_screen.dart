import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../components/app_button.dart';
import '../components/readable_width.dart';
import '../components/spacing.dart';
import '../entity/leaflet_entity.dart';
import '../helper/nickname_policy.dart';
import '../l10n/l10n.dart';
import '../leaflets/leaflets_model.dart';
import 'leaflet_id_field.dart';
import 'nickname_field.dart';
import 'share_code.dart';

/// しおりの共同編集を設定する画面。オーナーだけが開く。
///
/// あいことばを決めると、公開用しおり ID・あいことば・QR コードが表示される。
class ShareScreen extends StatefulWidget {
  /// [leafletKey] のしおりを [model] 経由で設定する。
  const ShareScreen({super.key, required this.model, required this.leafletKey});

  /// しおり一覧の状態。
  final LeafletsModel model;

  /// 設定するしおりのキー（公開用しおり ID）。
  final String leafletKey;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _passphraseController = TextEditingController(
    text: generatePassphrase(),
  );
  final _nicknameController = TextEditingController();
  final _scrollController = ScrollController();
  String? _savedPassphrase;
  bool _loaded = false;
  bool _editing = false;
  bool _busy = false;

  LeafletsModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedPassphrase());
    unawaited(_loadNickname());
  }

  /// ニックネームの初期値（保存済みか、端末の機種名）を入れる。
  Future<void> _loadNickname() async {
    final suggested = await _model.suggestedNickname();
    if (!mounted || _nicknameController.text.isNotEmpty) return;
    _nicknameController.text = suggested;
  }

  Future<void> _loadSavedPassphrase() async {
    final leaflet = _model.leafletByKey(widget.leafletKey);
    final saved = leaflet == null
        ? null
        : await _model.savedPassphrase(leaflet);
    if (!mounted) return;
    setState(() {
      _savedPassphrase = saved;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _nicknameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.copied)));
  }

  Future<void> _enable(LeafletEntity leaflet) async {
    final passphrase = _passphraseController.text;
    final nickname = _nicknameFor(leaflet);
    if (!isValidPassphrase(passphrase) || !isValidNickname(nickname)) return;
    setState(() => _busy = true);
    final ok = await _model.enableSharing(
      leaflet,
      passphrase,
      nickname: nickname,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _savedPassphrase = passphrase;
        _editing = false;
      }
    });
    if (ok) _scrollToTop();
  }

  /// 設定が終わると、入力欄から、ID と QR コードの表示に変わる。先頭から見えるようにする。
  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  /// 入力欄を出すか。共同編集を有効にするときと、ニックネームがまだ無いときに出す。
  bool _asksNickname(LeafletEntity leaflet) =>
      !leaflet.shared || !isValidNickname(_model.nickname ?? '');

  /// 使うニックネーム。入力欄が無いときは、保存済みのもの。
  String _nicknameFor(LeafletEntity leaflet) =>
      _asksNickname(leaflet) ? _nicknameController.text : _model.nickname ?? '';

  Future<void> _disable(LeafletEntity leaflet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.stopSharingQuestion),
        content: Text(context.l10n.stopSharingBody),
        actions: [
          AppButton(
            kind: AppButtonKind.text,
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.cancel,
          ),
          AppButton(
            kind: AppButtonKind.danger,
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.stop,
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await _model.disableSharing(leaflet);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _savedPassphrase = null;
        _editing = false;
        _passphraseController.text = generatePassphrase();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sharedEditing)),
      body: ListenableBuilder(
        listenable: _model,
        builder: (context, child) {
          final leaflet = _model.leafletByKey(widget.leafletKey);
          if (leaflet == null || !_loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final showEditor = !leaflet.shared || _editing;
          return ListView(
            controller: _scrollController,
            padding: AppInsets.medium,
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      leaflet.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const VGap.medium(),
                    if (showEditor)
                      _buildEditor(leaflet)
                    else
                      ..._buildSharingInfo(leaflet),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditor(LeafletEntity leaflet) {
    final changing = leaflet.shared;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _passphraseController,
        _nicknameController,
      ]),
      builder: (context, child) {
        final passphraseValid = isValidPassphrase(_passphraseController.text);
        final valid = passphraseValid && isValidNickname(_nicknameFor(leaflet));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              changing
                  ? context.l10n.changePassphraseIntro
                  : context.l10n.enableSharingIntro,
            ),
            const VGap.medium(),
            TextField(
              controller: _passphraseController,
              decoration: InputDecoration(
                labelText: context.l10n.passphrase,
                helperText: context.l10n.passphraseMinHelper(
                  passphraseMinLength,
                ),
                errorText: passphraseValid
                    ? null
                    : context.l10n.passphraseTooShort(passphraseMinLength),
                suffixIcon: AppIconButton(
                  tooltip: context.l10n.generate,
                  icon: Icons.casino_outlined,
                  onPressed: () =>
                      _passphraseController.text = generatePassphrase(),
                ),
              ),
              maxLength: passphraseMaxLength,
            ),
            if (_asksNickname(leaflet)) ...[
              const VGap.small(),
              NicknameField(controller: _nicknameController, enabled: !_busy),
            ],
            const VGap.small(),
            AppButton(
              kind: AppButtonKind.accent,
              expand: true,
              busy: _busy,
              onPressed: valid ? () => unawaited(_enable(leaflet)) : null,
              label: changing
                  ? context.l10n.changePassphrase
                  : context.l10n.enableSharing,
            ),
            if (changing)
              AppButton(
                kind: AppButtonKind.text,
                onPressed: _busy
                    ? null
                    : () => setState(() => _editing = false),
                label: context.l10n.cancel,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSharingInfo(LeafletEntity leaflet) {
    final passphrase = _savedPassphrase;
    final id = _formatId(leaflet.key);
    return [
      _copyRow(context.l10n.tripId, id, leaflet.key),
      const VGap.small(),
      if (passphrase != null) ...[
        _copyRow(context.l10n.passphrase, passphrase, passphrase),
        const VGap.large(),
        Text(context.l10n.friendHint),
        const VGap.medium(),
        Center(
          child: QrImageView(
            data: buildJoinLink(leaflet.key, passphrase),
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const VGap.medium(),
        Text(
          context.l10n.qrWarning,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ] else ...[
        Text(context.l10n.passphraseNotSaved),
      ],
      const VGap.large(),
      AppButton(
        kind: AppButtonKind.secondary,
        expand: true,
        onPressed: _busy ? null : () => setState(() => _editing = true),
        label: context.l10n.changePassphrase,
      ),
      const VGap.small(),
      AppButton(
        kind: AppButtonKind.danger,
        expand: true,
        onPressed: _busy ? null : () => unawaited(_disable(leaflet)),
        label: context.l10n.stopSharing,
      ),
    ];
  }

  Widget _copyRow(String label, String shown, String copied) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              SelectableText(
                shown,
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        AppIconButton(
          tooltip: context.l10n.copy,
          icon: Icons.copy,
          onPressed: () => unawaited(_copy(copied)),
        ),
      ],
    );
  }

  /// 入力欄の区画（[LeafletIdController.segmentLength] 文字）と同じ位置で、ハイフンで区切る。
  String _formatId(String id) {
    const size = LeafletIdController.segmentLength;
    return [
      for (var i = 0; i < id.length; i += size)
        id.substring(i, math.min(i + size, id.length)),
    ].join('-');
  }
}
