import 'dart:async';
import 'dart:math' as math;

import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/act_icon.dart';
import '../components/app_badge.dart';
import '../components/app_button.dart';
import '../components/spacing.dart';
import '../entity/mark_entity.dart';
import '../helper/time_zones.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'mark_dialogs.dart';
import 'marks_model.dart';

/// 日付ヘッダと末尾の、大きな円の直径。
const _markSize = 80.0;

/// 大きな円の枠と、中の文字との余白（左右の合計）。文字が枠に触れないようにする。
const _markTextInset = 20.0;

/// タイムラインの縦の線と、円・丸の枠の太さ。
const _lineWidth = 4.0;

/// 日付ヘッダと末尾の円の、上下に付ける縦の線の長さ。
const _headerLineLength = 16.0;

/// 予定の丸の直径と、左右の余白。
const _pointSize = 16.0;
const _pointMargin = 4.0;

// 行の上端からの位置。時刻・丸・タイトルの 1 行目の高さが、見た目でそろうよう合わせた値。
const _startTimeTop = 7.0;
const _pointTop = 8.0;
const _titleTop = 6.0;

/// 交通手段のアイコンの、行の上端からの位置。丸の下、次の予定へ続く線の途中に置く。
const _actIconTop = 56.0;

/// 終了時刻の左の余白。時刻の列の幅を測るときにも足す。
const _endTimeLeftMargin = 2.0;

/// 標準の文字サイズでの、時刻の列の幅。これより狭くはしない。
const _baseTimeColumnWidth = 68.0;

/// 時刻の列の幅に足す余裕。フォントの読み込み前後の誤差で折り返されないようにする。
const _timeColumnSlack = 6.0;

/// 予定の行の、最低の高さ（編集モードでない）。標準の文字サイズでの、丸と線の長さ。
const _minRowHeight = 80.0;

/// 編集モードで、右端に重ねる 2 つのボタンの幅と、行の最低の高さ。
const _editButtonsWidth = 64.0;
const _editModeMinHeight = 128.0;

/// 時刻の右側の余白。
const _timeRightMargin = 12.0;

/// 時刻の列の右端から、タイムラインの線の中心までの距離（丸の左の余白＋丸の半径）。
const _lineCenterOffset = _pointMargin + _pointSize / 2;

TextStyle _startTimeStyle() => GoogleFonts.bizUDPGothic(
  fontSize: 14,
  fontWeight: FontWeight.bold,
  fontFeatures: const [
    FontFeature.tabularFigures(), // 数字を等幅（モノスペース）にする
  ],
);

TextStyle _endTimeStyle(Color color) =>
    TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12);

double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// 時刻の列の幅。文字サイズやフォントによらず時刻が折り返されないよう、実際の文字の幅から決める。
/// OS の非線形な文字拡大では、大きさごとに倍率が違うため、固定の倍率では足りない。
double _timeColumnWidth(BuildContext context) {
  final measured =
      math.max(
        _textWidth(context, '00:00', _startTimeStyle()) + _timeRightMargin,
        _textWidth(context, '～00:00', _endTimeStyle(Colors.black)) +
            _endTimeLeftMargin,
      ) +
      _timeColumnSlack;
  return math.max(_baseTimeColumnWidth, measured);
}

/// 日付ヘッダと末尾の円の左端。円の中心を、旅程のタイムラインの線に合わせる。
double _timelineCircleLeft(BuildContext context) => math.max(
  0.0,
  _timeColumnWidth(context) + _lineCenterOffset - _markSize / 2,
);

abstract class MarksListItem {
  Widget build(BuildContext context, MarksModel model);
  DateTime date();
}

extension MarksListItemExtension on MarksListItem {
  Widget editModelDivider(MarksModel model) {
    return model.isEditMode
        ? Builder(
            builder: (context) =>
                Divider(height: 6, color: Theme.of(context).subtleColor),
          )
        : const SizedBox.shrink();
  }
}

class DayHeaderItem implements MarksListItem {
  /// 旅程の先頭の日付ヘッダかどうか。先頭では上に線を引かない。
  final bool isTop;

  /// 日付（年月日だけを持つ現地の日付）。旅程がまだ無いときは null。
  final DateTime? startDate;

  /// [startDate] の日を表すタイムゾーン ID。旅程がまだ無いときは null。
  final String? zoneId;

  /// 日付ヘッダを作る。
  DayHeaderItem({
    required this.isTop,
    required this.startDate,
    required this.zoneId,
  });

  @override
  Widget build(BuildContext context, MarksModel model) {
    final circleLeft = _timelineCircleLeft(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(left: circleLeft),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(
                      left: _markSize / 2 - _lineWidth / 2,
                    ),
                    child: Container(
                      color: isTop
                          ? Colors.transparent
                          : Theme.of(context).primaryColor,
                      width: _lineWidth,
                      height: _headerLineLength,
                    ), // ヘッダーに付ける縦の青線
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: _markSize,
                        width: _markSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: _lineWidth,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // 円の中に収まるよう、文字が大きいときは縮める。
                      SizedBox.square(
                        dimension: _markSize - _markTextInset,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            switch (startDate) {
                              final date? => formatWall(date, "MM/dd\nEEE"),
                              null => "Day1",
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(
                      left: _markSize / 2 - _lineWidth / 2,
                    ),
                    child: Container(
                      color: Theme.of(context).primaryColor,
                      width: _lineWidth,
                      height: _headerLineLength,
                    ), // ヘッダーに付ける縦の青線
                  ),
                ],
              ),
              const Expanded(child: SizedBox.shrink()),
              editModelButtons(context, model),
            ],
          ),
        ),
        editModelDivider(model),
      ],
    );
  }

  @override
  DateTime date() => startDate ?? DateTime.now();

  Widget editModelButtons(BuildContext context, MarksModel model) {
    return model.isEditMode
        ? Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.small),
                child: AppIconButton(
                  tooltip: context.l10n.addToDay,
                  kind: AppIconButtonKind.tonal,
                  onPressed: () {
                    unawaited(
                      showMarkInputDialog(
                        context,
                        model,
                        initialWall: startDate,
                        zoneHint: zoneId,
                      ),
                    );
                  },
                  icon: Icons.add,
                ),
              ),
            ],
          )
        : const SizedBox.shrink();
  }
}

class ActionItem implements MarksListItem {
  final MarkEntity _mark;
  bool isNow = false;
  bool isNext = false;
  ActionItem(this._mark);

  /// この項目が表す旅程。
  MarkEntity get mark => _mark;

  @override
  Widget build(BuildContext context, MarksModel model) {
    return Align(
      alignment: Alignment.topLeft,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 縦の青線は、行の高さを事前に測らず、行の高さいっぱいに重ねて描く。
              // （`IntrinsicHeight` は、折り返す文の高さを測り違えて、はみ出すことがあった。）
              Stack(
                children: [
                  Positioned(
                    left:
                        _timeColumnWidth(context) +
                        _lineCenterOffset -
                        _lineWidth / 2,
                    top: 0,
                    bottom: 0,
                    width: _lineWidth,
                    child: ColoredBox(color: Theme.of(context).primaryColor),
                  ), // 各予定に付ける縦の青線
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: model.isEditMode
                          ? _editModeMinHeight
                          : _minRowHeight + _labelSpace,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        startTimeWidget(context),
                        markPointWidget(context),
                        titleWidget(
                          context,
                          reserveEditButtons: model.isEditMode,
                        ),
                      ],
                    ),
                  ),
                  if (model.isEditMode) ...editModelButtons(context, model),
                ],
              ),
              editModelDivider(model),
            ],
          ),
          actIconWidget(context),
        ],
      ),
    );
  }

  @override
  DateTime date() => _mark.startDate;

  Widget actIconWidget(BuildContext context) {
    final actType = _mark.actType;
    return actType != null
        ? Align(
            alignment: Alignment.topLeft,
            child: Container(
              // アイコンの右端を、タイムラインの線の左端に合わせる。
              margin: EdgeInsets.only(
                top: _actIconTop + _labelSpace,
                left:
                    _timeColumnWidth(context) +
                    _lineCenterOffset -
                    _lineWidth / 2 -
                    ActIcon.defaultSize,
              ),
              // 左向きの画像を、時計回りに 270 度（3 回の 90 度）回し、次の予定がある下向きにする。
              child: RotatedBox(quarterTurns: 3, child: ActIcon(actType)),
            ),
          )
        : const SizedBox.shrink();
  }

  // 「いま／つぎ」の吹き出しが前の項目に重ならないよう、上に余白を確保する。
  double get _labelSpace => (isNow || isNext) ? AppSpace.xlarge : 0;

  /// 端末のタイムゾーンと違う旅程に出す、都市名。開始と終了で違うときは `A → B`。
  String? _zoneBadgeText(String languageCode) {
    final start = _mark.startZoneId;
    final end = _mark.endDate == null ? start : _mark.endZoneId;
    if (start == end) {
      return start == deviceZoneId ? null : cityNameOf(start, languageCode);
    }
    return '${cityNameOf(start, languageCode)} → '
        '${cityNameOf(end, languageCode)}';
  }

  Widget startTimeWidget(BuildContext context) {
    final timeStyle = _startTimeStyle();
    final endStyle = _endTimeStyle(Theme.of(context).accentTextColor);
    return SizedBox(
      width: _timeColumnWidth(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              Positioned(
                top: AppSpace.medium,
                right: _timeRightMargin,
                child: StepLabel(isNow: isNow, isNext: isNext),
              ),
              Container(
                alignment: Alignment.bottomRight,
                margin: EdgeInsets.only(
                  top: _startTimeTop + _labelSpace,
                  right: _timeRightMargin,
                ),
                child: Text(
                  formatInZone(_mark.startDate, _mark.startZoneId, 'HH:mm'),
                  style: timeStyle,
                ),
              ),
              Positioned(
                child: _mark.isAbout
                    ? Container(
                        alignment: Alignment.topRight,
                        margin: const EdgeInsets.only(bottom: 0),
                        child: Text(
                          context.l10n.approxMark,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (_mark.endDate case final endDate?)
            Container(
              alignment: Alignment.topRight,
              margin: const EdgeInsets.only(left: _endTimeLeftMargin),
              child: Text(
                "～${formatInZone(endDate, _mark.endZoneId, 'HH:mm')}",
                style: endStyle,
              ),
            ),
        ],
      ),
    );
  }

  /// 縦の青線の上に重ねる、予定の丸。中は、背景の色で塗って、線を隠す。
  Widget markPointWidget(BuildContext context) {
    return Container(
      height: _pointSize,
      width: _pointSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(
          width: _lineWidth,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      margin: EdgeInsets.only(
        left: _pointMargin,
        right: _pointMargin,
        top: _pointTop + _labelSpace,
      ),
    );
  }

  Widget titleWidget(BuildContext context, {required bool reserveEditButtons}) {
    return Flexible(
      child: Padding(
        // 編集のボタンは、右端に重ねて置くため、その分を空けておく。
        padding: EdgeInsets.only(
          right: reserveEditButtons ? _editButtonsWidth : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.only(
                left: AppSpace.xsmall,
                right: AppSpace.xsmall,
                bottom: AppSpace.xsmall,
                top: _titleTop + _labelSpace,
              ),
              child: Text(
                _mark.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_zoneBadgeText(context.languageCode) case final badge?)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpace.xsmall,
                  bottom: AppSpace.xsmall,
                ),
                child: AppBadge(label: badge, fontSize: 11),
              ),
            (_mark.remark.isEmpty)
                ? const SizedBox.shrink()
                : Bubble(
                    nip: BubbleNip.leftTop,
                    color: Theme.of(context).koala.brandSurface,
                    child: GestureDetector(
                      onTap: () {
                        if (_mark.link.isEmpty) return;
                        unawaited(
                          launchUrl(
                            Uri.parse(_mark.link),
                            mode: LaunchMode.externalApplication,
                          ),
                        );
                      },
                      // 長い文が折り返されても高さが正しく決まるよう、アイコンは文の中に置く
                      // （`Wrap` は、折り返したときの高さを事前に答えられず、はみ出した）。
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: _mark.remark),
                            if (_mark.link.isNotEmpty)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpace.small,
                                  ),
                                  child: Icon(
                                    Icons.open_in_new,
                                    color: Theme.of(context)
                                        .koala
                                        .onBrandSurface
                                        .withValues(alpha: 0.75),
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        style: TextStyle(
                          color: Theme.of(context).koala.onBrandSurface,
                        ),
                      ),
                    ),
                  ),
            const VGap.xlarge(),
          ],
        ),
      ),
    );
  }

  /// 編集モードのボタン。右上に「編集」、右下に「この後に追加」を重ねる。
  List<Widget> editModelButtons(BuildContext context, MarksModel model) {
    return [
      Positioned(
        right: AppSpace.small,
        top: AppSpace.small,
        child: AppIconButton(
          tooltip: context.l10n.editMark,
          onPressed: () {
            unawaited(showMarkInputDialog(context, model, mark: _mark));
          },
          icon: Icons.edit_outlined,
        ),
      ),
      Positioned(
        right: AppSpace.small,
        bottom: AppSpace.small,
        child: AppIconButton(
          tooltip: context.l10n.addAfterMark,
          kind: AppIconButtonKind.tonal,
          onPressed: () {
            // 終了がある旅程は、到着地の現地時刻から続ける。
            final end = _mark.endDate;
            final zone = end != null ? _mark.endZoneId : _mark.startZoneId;
            unawaited(
              showMarkInputDialog(
                context,
                model,
                initialWall: wallOf(zone, end ?? _mark.startDate),
                zoneHint: zone,
              ),
            );
          },
          icon: Icons.add,
        ),
      ),
    ];
  }
}

class StepLabel extends StatelessWidget {
  final bool isNow;
  final bool isNext;
  const StepLabel({super.key, required this.isNow, required this.isNext});

  @override
  Widget build(BuildContext context) {
    if (!isNow && !isNext) return const SizedBox.shrink();
    // 「いま」は珊瑚色、「つぎ」は黄色（[AppBadgeTone]）。吹き出しの形は変えない。
    // 縁は、「いま」は面と同じ色（実質なし）、「つぎ」は黄色の面の縁（インク）。
    final theme = Theme.of(context);
    final colors = AppBadgeColors.of(
      isNow ? AppBadgeTone.now : AppBadgeTone.next,
      theme,
    );
    return Row(
      children: [
        Bubble(
          nip: BubbleNip.rightBottom,
          nipWidth: 6,
          nipHeight: 6,
          nipOffset: 4,
          radius: const Radius.circular(4),
          elevation: 0,
          borderColor: colors.border,
          borderWidth: 0.5,
          padding: const BubbleEdges.symmetric(horizontal: 6, vertical: 2),
          color: colors.fill,
          child: Text(
            isNow ? 'now' : 'next',
            style: TextStyle(
              color: colors.content,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class EndItem implements MarksListItem {
  @override
  Widget build(BuildContext context, MarksModel model) {
    return Container(
      margin: EdgeInsets.only(
        left: _timelineCircleLeft(context),
        bottom: AppSpace.xlarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(left: _markSize / 2 - _lineWidth / 2),
            child: Container(
              color: Theme.of(context).primaryColor,
              width: _lineWidth,
              height: _headerLineLength,
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: _markSize,
                width: _markSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: _lineWidth,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              // 円の中に収まるよう、文字が大きいときは縮める。
              const SizedBox.square(
                dimension: _markSize - _markTextInset,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Where\nto\nNext?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  DateTime date() {
    throw UnimplementedError();
  }
}
