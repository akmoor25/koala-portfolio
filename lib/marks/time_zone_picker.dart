import 'package:flutter/material.dart';

import '../components/spacing.dart';
import '../helper/time_zones.dart';
import '../l10n/l10n.dart';

/// タイムゾーンを選ぶダイアログ。選んだタイムゾーンの ID を返す。選ばずに閉じたら null。
///
/// 先頭に端末のタイムゾーンと、よく使う 12 都市を並べ、続けて全てのタイムゾーンを出す。
/// 都市名か ID で絞り込める。[instant] は、時差（夏時間を含む）の表示に使う。
Future<String?> showTimeZonePicker(
  BuildContext context, {
  required String selected,
  required DateTime instant,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TimeZonePicker(selected: selected, instant: instant),
  );
}

class _TimeZonePicker extends StatefulWidget {
  const _TimeZonePicker({required this.selected, required this.instant});

  final String selected;
  final DateTime instant;

  @override
  State<_TimeZonePicker> createState() => _TimeZonePickerState();
}

class _TimeZonePickerState extends State<_TimeZonePicker> {
  late final List<String> _all = selectableZoneIds();
  String _query = '';

  /// 先頭に並べる ID（端末、よく使う都市）。重複は除く。
  List<String> get _pinned => [
    deviceZoneId,
    ...pinnedZoneIds.where((id) => id != deviceZoneId),
  ];

  bool _matches(String id) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return id.toLowerCase().contains(query) ||
        cityNameOf(id).toLowerCase().contains(query) ||
        cityNameOf(id, 'ja').contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _query.trim().isEmpty ? _pinned : <String>[];
    final rest = [
      for (final id in _all)
        if (!pinned.contains(id) && _matches(id)) id,
    ];
    final ids = [...pinned, ...rest];
    return AlertDialog(
      title: Text(context.l10n.timeZone),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 360,
        height: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.large),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.zoneSearchHint,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ids.length,
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final isDevice = id == deviceZoneId;
                  return ListTile(
                    dense: true,
                    selected: id == widget.selected,
                    title: Text(
                      zoneLabel(id, widget.instant, context.languageCode),
                    ),
                    subtitle: Text(isDevice ? context.l10n.deviceZone(id) : id),
                    onTap: () => Navigator.pop(context, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
