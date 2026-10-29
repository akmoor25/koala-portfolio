import 'package:flutter/material.dart';

import '../components/spacing.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'share_code.dart';

/// 1 区画（4 文字）の入力欄の内容。使えない文字を赤字にする。
class _SegmentController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(
      style: style,
      children: [
        for (final character in text.runes.map(String.fromCharCode))
          TextSpan(
            text: character,
            style: isLeafletIdCharacter(character)
                ? null
                : TextStyle(
                    color: Theme.of(context).koala.dangerText,
                    fontWeight: FontWeight.bold,
                  ),
          ),
      ],
    );
  }
}

/// 公開用しおり ID の入力欄（4 文字 × 3 区画）の状態。
///
/// 入力された文字は変換しない。使えない文字は赤字で示し、
/// 直すかどうかは利用者に任せる。
class LeafletIdController extends ChangeNotifier {
  /// 3 つの空の区画を作る。
  LeafletIdController() {
    for (final segment in _segments) {
      segment.addListener(notifyListeners);
    }
  }

  /// 1 区画の文字数。
  static const segmentLength = 4;

  /// 区画の数。
  static const segmentCount = leafletIdLength ~/ segmentLength;

  final List<_SegmentController> _segments = List.generate(
    segmentCount,
    (_) => _SegmentController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    segmentCount,
    (_) => FocusNode(),
  );

  /// 入力されている文字を、区切りなしでつないだもの。
  String get value => _segments.map((s) => s.text).join();

  /// ID を区画に分けて入れる。QR の読み取り結果や貼り付けに使う。
  set value(String id) => _fill(0, id, clearRest: true);

  /// 使えない文字が入力されているか。
  bool get hasInvalidCharacters => value.runes
      .map(String.fromCharCode)
      .any((character) => !isLeafletIdCharacter(character));

  /// 12 文字そろっているか。
  bool get isComplete => value.runes.length == leafletIdLength;

  /// [raw] を [from] 番目の区画から順に入れる。
  ///
  /// [clearRest] が false なら、入りきった後の区画には触れない。
  void _fill(int from, String raw, {required bool clearRest}) {
    // 区切りと空白は文字として扱わない。文字そのものは変えない。
    final characters = raw
        .replaceAll(RegExp(r'[\s\-－‐]'), '')
        .runes
        .map(String.fromCharCode)
        .toList();
    for (var i = from; i < segmentCount; i++) {
      final start = (i - from) * segmentLength;
      if (start >= characters.length && !clearRest) break;
      final part = characters.skip(start).take(segmentLength).join();
      _segments[i].value = TextEditingValue(
        text: part,
        selection: TextSelection.collapsed(offset: part.length),
      );
    }
  }

  void _onChanged(int index) {
    final text = _segments[index].text;
    final length = text.runes.length;
    // 貼り付けや 5 文字目の入力は、次の区画へ送る。
    if (length > segmentLength) _fill(index, text, clearRest: false);
    if (length >= segmentLength && index + 1 < segmentCount) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final segment in _segments) {
      segment.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

/// 公開用しおり ID を、ハイフンで区切った 3 つの欄で入力する。
class LeafletIdField extends StatelessWidget {
  /// [controller] の状態を表示し、入力を渡す。
  const LeafletIdField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  /// 入力の状態。
  final LeafletIdController controller;

  /// 入力できるか。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.tripId, style: theme.textTheme.bodySmall),
            const VGap.xsmall(),
            Row(
              children: [
                for (var i = 0; i < LeafletIdController.segmentCount; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('-', style: TextStyle(fontSize: 20)),
                    ),
                  Expanded(child: _buildSegment(i)),
                ],
              ],
            ),
            if (controller.hasInvalidCharacters)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xsmall),
                child: Text(
                  context.l10n.tripIdCheckInput,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSegment(int index) {
    return TextField(
      controller: controller._segments[index],
      focusNode: controller._focusNodes[index],
      enabled: enabled,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
      decoration: const InputDecoration(
        hintText: 'XXXX',
        counterText: '',
        isDense: true,
      ),
      onChanged: (_) => controller._onChanged(index),
    );
  }
}
