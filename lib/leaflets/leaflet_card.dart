import 'package:flutter/material.dart';

import '../components/emoji_wallpaper.dart';
import '../components/outlined_text.dart';
import '../components/pressable_scale.dart';
import '../components/spacing.dart';
import '../entity/leaflet_entity.dart';
import '../helper/time_zones.dart';
import '../theme/app_theme.dart';

/// しおりの期間を `M/d～M/d` の形にする。期間が無ければ null。
///
/// 日付は、[firstZoneId]・[lastZoneId] の現地の日付（無ければ端末のタイムゾーン）。
/// 開始と終了が同じ日なら、日付を 1 つだけにする。
String? dateRangeText(
  DateTime? first,
  DateTime? last, {
  String? firstZoneId,
  String? lastZoneId,
}) {
  if (first == null) return null;
  final start = formatInZone(first, firstZoneId ?? '', 'M/d');
  final end = last == null ? null : formatInZone(last, lastZoneId ?? '', 'M/d');
  return end == null || end == start ? start : '$start～$end';
}

/// 期間のタブの、文字の行の高さ（標準の文字サイズで 14 pt の文字が収まる高さ）。
const double _tabLineHeight = 20;

/// 期間のタブの、文字の上下の余白。
const double _tabTextPadding = 2;

/// 期間のタブのうち、カードの裏に隠れる下の部分の高さ。タブがカードから生えて見えるようにする。
const double _tabHiddenHeight = 16;

/// 一覧に並べる、しおり 1 冊分のカード。
class LeafletCard extends StatelessWidget {
  /// [leaflet] を表示する。[onTap] で開き、[onLongPress] でメニューを出す。
  const LeafletCard({
    super.key,
    required this.leaflet,
    this.showsSharedBadge = false,
    this.onTap,
    this.onLongPress,
  });

  /// 表示するしおり。
  final LeafletEntity leaflet;

  /// 共同編集のしおりであることを示すバッジを出すか。
  final bool showsSharedBadge;

  /// タップしたとき。
  final VoidCallback? onTap;

  /// 長押ししたとき。
  final VoidCallback? onLongPress;

  static const _defaultAccent = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    final dateText = dateRangeText(
      leaflet.firstDate,
      leaflet.lastDate,
      firstZoneId: leaflet.firstTimeZoneId,
      lastZoneId: leaflet.lastTimeZoneId,
    );
    final coverColor = leaflet.coverColor;
    final accentColor = coverColor != null ? Color(coverColor) : _defaultAccent;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDateTab(context, dateText, accentColor),
        PressableScale(
          enabled: onTap != null,
          child: AspectRatio(
            aspectRatio: 1,
            child: Card(
              semanticContainer: true,
              color: theme.isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : Colors.white,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EmojiWallpaper(
                    emoji: leaflet.coverEmoji,
                    backgroundColor: accentColor.withValues(
                      alpha: theme.isDark ? 0.25 : 0.1,
                    ),
                  ),
                  if (showsSharedBadge)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.koala.brandSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.koala.brandDeep.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Padding(
                          padding: AppInsets.xsmall,
                          child: Icon(
                            Icons.group,
                            size: 16,
                            color: theme.koala.brandDeep,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    child: OutlinedAutoSizeText(
                      leaflet.title,
                      // 内側から、表紙の色・白・表紙の色の 3 重の縁取り。どの絵文字の上でも、
                      // ステッカーのように白い文字を読めるようにする。
                      outlines: [
                        OutlineStyle(color: accentColor, strokeWidth: 8),
                        const OutlineStyle(
                          color: Colors.white,
                          strokeWidth: 16,
                        ),
                        OutlineStyle(color: accentColor, strokeWidth: 20),
                      ],
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      onLongPress: onLongPress,
                      focusColor: theme.koala.focusRing.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// カードの上にはみ出す、期間のタブ。
  ///
  /// 期間の文字は、文字サイズを大きくしても 1.3 倍までにし、カードの幅に収まらないときは縮める。
  Widget _buildDateTab(
    BuildContext context,
    String? dateText,
    Color accentColor,
  ) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Builder(
        builder: (context) {
          // タブの文字が収まる高さ。カードの陰に隠れないよう、文字と一緒に広げる。
          final tabHeight =
              _tabTextPadding * 2 +
              MediaQuery.textScalerOf(context).scale(_tabLineHeight);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(height: tabHeight, width: double.infinity),
              if (dateText != null)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      // 下の部分はカードの陰に隠れる。見える部分（tabHeight）の中央に文字を置く。
                      height: tabHeight + _tabHiddenHeight,
                      padding: const EdgeInsets.only(
                        top: _tabTextPadding,
                        bottom: _tabHiddenHeight + _tabTextPadding,
                        left: 12,
                        right: 12,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: OutlinedAutoSizeText(
                            dateText,
                            outlines: const [
                              OutlineStyle(color: Colors.white, strokeWidth: 4),
                            ],
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: accentColor,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
