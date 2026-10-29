import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/act_icon.dart';
import '../components/app_button.dart';
import '../components/confirm_delete_dialog.dart';
import '../components/notice_banner.dart';
import '../components/spacing.dart';
import '../entity/mark_entity.dart';
import '../extension/extension.dart';
import '../helper/act_type.dart';
import '../helper/time_zones.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'marks_model.dart';
import 'time_zone_picker.dart';

/// データベースのルールが許す文字数。超えると保存が拒否されるため、
/// database.rules.json の marks の title・remark・link の上限と合わせる。
const _maxTitleLength = 200;
const _maxRemarkLength = 2000;
const _maxLinkLength = 2048;

/// アイコンの選択肢の下の線の大きさ。線の幅は、押せる最小の大きさに合わせる。
const double _tileUnderlineWidth = kMinInteractiveDimension;
const double _tileUnderlineHeight = 4;

/// アイコンを選ぶダイアログの、格子の大きさと列の数。
/// 「なし」を含む 14 の選択肢が、スクロールせずに 4 列 × 4 行で収まる。
const double _pickerSize = 300;
const _pickerColumns = 4;

/// 旅程の追加・編集ダイアログを出す。
///
/// [mark] を渡すと編集、渡さないと追加になる。追加のときの開始は、現地の日時
/// [initialWall]（無ければ、端末のタイムゾーンでの現在）。タイムゾーンの既定値は、
/// 一つ前の旅程の終了側のタイムゾーン、無ければ端末のタイムゾーン。[zoneHint] は、
/// 「一つ前」を探すための、[initialWall] が属するタイムゾーン。
/// 編集中は複製を扱い、OK を押すまで元の旅程は変わらない。
Future<void> showMarkInputDialog(
  BuildContext context,
  MarksModel model, {
  MarkEntity? mark,
  DateTime? initialWall,
  String? zoneHint,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _MarkInputDialog(
      model: model,
      mark: mark,
      initialWall: initialWall,
      zoneHint: zoneHint,
    ),
  );
}

class _MarkInputDialog extends StatefulWidget {
  const _MarkInputDialog({
    required this.model,
    required this.mark,
    required this.initialWall,
    required this.zoneHint,
  });

  final MarksModel model;
  final MarkEntity? mark;
  final DateTime? initialWall;
  final String? zoneHint;

  @override
  State<_MarkInputDialog> createState() => _MarkInputDialogState();
}

class _MarkInputDialogState extends State<_MarkInputDialog> {
  /// 追加のときの、起点の絶対時刻。
  final DateTime _now = DateTime.now();

  late final MarkEntity _input =
      widget.mark?.copy() ??
      MarkEntity('', false, null, '', '', '', '', _now, null);

  // 日時は、現地の日時（年月日時分）とタイムゾーンで持ち、保存するときに絶対時刻にする。
  late DateTime _startWall;
  late String _startZone;
  DateTime? _endWall;

  /// 終了のタイムゾーン。null なら開始と同じ。
  String? _endZone;

  /// ユーザーがタイムゾーンを選んだか。選ぶまでは、開始日時に合わせて既定値を選び直す。
  bool _zoneChosen = false;

  late final _title = TextEditingController(text: _input.title);
  late final _remark = TextEditingController(text: _input.remark);
  late final _link = TextEditingController(text: _input.link);
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.mark;
    if (existing != null) {
      _startZone = existing.startZoneId;
      _startWall = wallOf(_startZone, existing.startDate);
      final end = existing.endDate;
      if (end != null) {
        _endWall = wallOf(existing.endZoneId, end);
        if (existing.endZoneId != _startZone) _endZone = existing.endZoneId;
      }
      _zoneChosen = true;
    } else {
      _startWall = widget.initialWall ?? wallOf(deviceZoneId, _now);
      _startZone = _defaultZone(_startWall);
    }
  }

  /// [wall] を起点にした、タイムゾーンの既定値。
  String _defaultZone(DateTime wall) {
    final hint = widget.zoneHint ?? deviceZoneId;
    return defaultZoneIdFor(widget.model.marks, instantOf(hint, wall));
  }

  void _onStartChanged(DateTime wall) {
    setState(() {
      _startWall = wall;
      if (!_zoneChosen && widget.mark == null) _startZone = _defaultZone(wall);
      _error = null;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _remark.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickStartZone() async {
    final picked = await showTimeZonePicker(
      context,
      selected: _startZone,
      instant: instantOf(_startZone, _startWall),
    );
    if (picked == null) return;
    // 現地の時刻を保ち、絶対時刻を変える。
    setState(() {
      _startZone = picked;
      _zoneChosen = true;
      if (_endZone == picked) _endZone = null;
      _error = null;
    });
  }

  Future<void> _pickEndZone() async {
    final endWall = _endWall;
    if (endWall == null) return;
    final current = _endZone ?? _startZone;
    final picked = await showTimeZonePicker(
      context,
      selected: current,
      instant: instantOf(current, endWall),
    );
    if (picked == null) return;
    setState(() {
      _endZone = picked == _startZone ? null : picked;
      _error = null;
    });
  }

  void _save() {
    final start = instantOf(_startZone, _startWall);
    final endWall = _endWall;
    final endZone = _endZone ?? _startZone;
    final end = endWall == null ? null : instantOf(endZone, endWall);
    if (end != null && end.isBefore(start)) {
      setState(() => _error = context.l10n.endBeforeStart);
      return;
    }
    _input
      ..title = _title.text
      ..remark = _remark.text
      ..link = _link.text
      ..startDate = start
      ..endDate = end
      ..timeZoneId = _startZone
      ..endTimeZoneId = end == null || endZone == _startZone ? '' : endZone;
    if (widget.mark != null) {
      unawaited(widget.model.updateMark(_input));
    } else {
      unawaited(widget.model.addMark(_input));
    }
    Navigator.pop(context);
  }

  Future<void> _delete(MarkEntity existing) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: context.l10n.deleteQuestion(existing.title),
    );
    if (!confirmed || !mounted) return;
    unawaited(widget.model.deleteMark(existing));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.mark;
    return SimpleDialog(
      contentPadding: AppInsets.medium,
      children: [
        _DateTimeRow(
          label: context.l10n.startLabel,
          wall: _startWall,
          onChanged: _onStartChanged,
        ),
        _ZoneRow(
          label: context.l10n.timeZone,
          zoneId: _startZone,
          instant: instantOf(_startZone, _startWall),
          onPressed: () => unawaited(_pickStartZone()),
        ),
        _DateTimeRow(
          label: context.l10n.endLabel,
          wall: _endWall,
          onToggled: (isOn) => setState(() {
            _endWall = isOn ? _startWall : null;
            _endZone = null;
            _error = null;
          }),
          onChanged: (value) => setState(() {
            _endWall = value;
            _error = null;
          }),
        ),
        if (_endWall case final endWall?)
          _ZoneRow(
            label: context.l10n.timeZone,
            zoneId: _endZone ?? _startZone,
            instant: instantOf(_endZone ?? _startZone, endWall),
            onPressed: () => unawaited(_pickEndZone()),
          ),
        Row(
          children: [
            Checkbox(
              value: _input.isAbout,
              onChanged: (isOn) =>
                  setState(() => _input.isAbout = isOn ?? false),
            ),
            Text(
              context.l10n.approxLabel,
              style: TextStyle(color: Theme.of(context).subtleColor),
            ),
          ],
        ),
        _ActTypeRow(
          type: _input.actType,
          onSelected: (type) => setState(() => _input.actType = type),
        ),
        const VGap.small(),
        TextField(
          controller: _title,
          decoration: InputDecoration(labelText: context.l10n.titleLabel),
          keyboardType: TextInputType.multiline,
          inputFormatters: [LengthLimitingTextInputFormatter(_maxTitleLength)],
          maxLines: null,
        ),
        const VGap.small(),
        TextField(
          controller: _remark,
          decoration: InputDecoration(labelText: context.l10n.remarkLabel),
          keyboardType: TextInputType.multiline,
          inputFormatters: [LengthLimitingTextInputFormatter(_maxRemarkLength)],
          maxLines: null,
        ),
        const VGap.small(),
        TextField(
          controller: _link,
          decoration: InputDecoration(labelText: context.l10n.linkLabel),
          keyboardType: TextInputType.url,
          inputFormatters: [LengthLimitingTextInputFormatter(_maxLinkLength)],
          maxLines: null,
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.small),
            child: NoticeBanner(kind: NoticeKind.danger, message: error),
          ),
        const VGap.small(),
        // 文字が大きい小さな画面でも収まるよう、入らなければ折り返す。
        Wrap(
          alignment: WrapAlignment.spaceAround,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (existing != null)
              AppButton(
                kind: AppButtonKind.dangerText,
                onPressed: () => unawaited(_delete(existing)),
                label: context.l10n.delete,
              ),
            AppButton(onPressed: _save, label: context.l10n.ok),
          ],
        ),
      ],
    );
  }
}

/// 日付と時刻を選ぶ 1 行。[onToggled] を渡すと、値の有無を切り替えられる。
class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.wall,
    required this.onChanged,
    this.onToggled,
  });

  final String label;

  /// 現地の日時（年月日時分）。
  final DateTime? wall;
  final ValueChanged<DateTime> onChanged;
  final ValueChanged<bool>? onToggled;

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2, current.month, current.day),
      lastDate: DateTime(current.year + 2, current.month, current.day),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    onChanged(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, DateTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    onChanged(
      DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = wall;
    final toggled = onToggled;
    return Row(
      children: [
        if (toggled != null)
          Checkbox(
            value: current != null,
            onChanged: (isOn) => toggled(isOn ?? false),
          )
        else
          // チェックボックスと同じ幅を空け、ラベルの位置を他の行とそろえる。
          const SizedBox.square(dimension: kMinInteractiveDimension),
        Text(label, style: TextStyle(color: Theme.of(context).subtleColor)),
        // 幅が足りないときは、日付と時刻を縮めて 1 行に収める。
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerRight,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: current == null
                      ? null
                      : () => unawaited(_pickDate(context, current)),
                  child: Text(
                    current != null ? formatWall(current, 'yyyy/MM/dd') : '',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                TextButton(
                  onPressed: current == null
                      ? null
                      : () => unawaited(_pickTime(context, current)),
                  child: Text(
                    current != null ? formatWall(current, 'HH:mm') : '',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// タイムゾーンを選ぶ 1 行。押すと選択のダイアログを開く。
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.label,
    required this.zoneId,
    required this.instant,
    required this.onPressed,
  });

  final String label;
  final String zoneId;

  /// 時差の表示に使う、その日時の絶対時刻。
  final DateTime instant;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).subtleColor)),
        const HGap.small(),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: onPressed,
              label: Text(
                zoneLabel(zoneId, instant, context.languageCode),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 移動手段のアイコンを選ぶ 1 行。
class _ActTypeRow extends StatelessWidget {
  const _ActTypeRow({required this.type, required this.onSelected});

  final ActType? type;
  final ValueChanged<ActType?> onSelected;

  Future<void> _pick(BuildContext context) async {
    final picked = await showActIconPicker(context);
    if (picked != null) onSelected(picked.type);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.iconLabel,
          style: TextStyle(color: Theme.of(context).subtleColor),
        ),
        const HGap.medium(),
        SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: AppInsets.xsmall),
            onPressed: () => unawaited(_pick(context)),
            child: _ActIconTile(type: type),
          ),
        ),
      ],
    );
  }
}

class _ActIconTile extends StatelessWidget {
  const _ActIconTile({required this.type});

  final ActType? type;

  @override
  Widget build(BuildContext context) {
    final type = this.type;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (type != null)
          ActIcon(type)
        else
          const SizedBox.square(dimension: ActIcon.defaultSize),
        // アイコンの下の線。アイコンの無い「なし」も、選べる枠だと分かるようにする。
        Container(
          width: _tileUnderlineWidth,
          height: _tileUnderlineHeight,
          color: Theme.of(context).accentTextColor,
        ),
      ],
    );
  }
}

/// 移動手段のアイコンを選ぶダイアログ。
///
/// 選ばれたら、そのアイコンを `type` に持つ値を返す。先頭の空欄は「なし」で、
/// `type` が null になる。選ばずに閉じたときは null を返すので、
/// 「なし」を選んだ場合と区別できる。
Future<({ActType? type})?> showActIconPicker(BuildContext context) {
  return showDialog<({ActType? type})>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.l10n.iconLabel),
        content: SizedBox.fromSize(
          size: const Size.square(_pickerSize),
          child: GridView.count(
            crossAxisCount: _pickerColumns,
            children: List.generate(ActType.values.length + 1, (index) {
              final type = ActType.values.tryGet(index - 1);
              return Card(
                child: InkWell(
                  onTap: () => Navigator.pop(context, (type: type)),
                  borderRadius: BorderRadius.circular(16),
                  child: _ActIconTile(type: type),
                ),
              );
            }),
          ),
        ),
      );
    },
  );
}
