import 'dart:convert';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// 段落末の改行を除く、1段落の書記素数の上限。受信時には切り捨てない。
/// 他端末のデータを壊さず保持し、超過を減らす編集だけ許すため（[acceptsNoteChange]）。
const noteMaxCharacters = 1000;

/// 1 つのノートの段落数の上限。文字数と同じく、受信時には切り捨てない。
const noteMaxLines = 500;

/// 書式も含む段落Delta JSONの技術上限。DBルールのdelta上限と合わせる。
const noteMaxDeltaLength = 20000;

/// 段落IDと挿入位置は不変。削除済みのIDも、後続段落の位置を保つため残す。
class NoteLine {
  const NoteLine({
    required this.id,
    required this.generation,
    required this.afterId,
    required this.order,
    required this.writeId,
    required this.delta,
    this.deleted = false,
  });

  final String id;

  /// 初期化前の編集を、初期化後のノートへ書き戻さないための世代。
  final String generation;
  final String afterId;
  final int order;

  /// 送信を終えた古い版で、その後に受信した新しい版を上書きしないよう、版を区別する保存ID。
  final String writeId;
  final String? delta;
  final bool deleted;

  /// 挿入位置を保って本文の版だけ変える。nullは削除記録にし、本文を残さない。
  NoteLine edit(String? text, String revision) => NoteLine(
    id: id,
    generation: generation,
    afterId: afterId,
    order: order,
    writeId: revision,
    delta: text,
    deleted: text == null,
  );

  Map<String, Object?> toJson() => {
    'generation': generation,
    'afterId': afterId,
    'order': order,
    'writeId': writeId,
    'deleted': deleted,
    if (delta != null) 'delta': delta,
  };
}

/// ノートの世代と段落の集合。表示順はMapの列挙順ではなく挿入位置から復元する。
class NoteDocument {
  const NoteDocument(this.generation, this.lines);

  final String generation;
  final Map<String, NoteLine> lines;

  /// 形式・段落Delta・挿入先を検証し、不正ならFormatExceptionを投げる。
  /// 受信した超過データも保持するため、見た目の文字数・段落数は制限しない。
  static NoteDocument parse(Object? value) {
    if (value is! Map<Object?, Object?> ||
        value['schemaVersion'] != 2 ||
        !_validId(value['generation']) ||
        value.keys.any(
          (key) =>
              key != 'schemaVersion' && key != 'generation' && key != 'lines',
        )) {
      throw const FormatException('Unsupported note format');
    }
    final generation = value['generation']! as String;
    final rawLines = value['lines'];
    if (rawLines != null && rawLines is! Map<Object?, Object?>) {
      throw const FormatException('Invalid note lines');
    }
    final lines = <String, NoteLine>{};
    if (rawLines is Map<Object?, Object?>) {
      for (final entry in rawLines.entries) {
        final raw = entry.value;
        if (!_validId(entry.key) ||
            raw is! Map<Object?, Object?> ||
            raw['generation'] != generation ||
            raw['afterId'] is! String ||
            raw['order'] is! int ||
            (raw['order']! as int) < 1 ||
            !_validId(raw['writeId']) ||
            raw['deleted'] is! bool ||
            raw.keys.any(
              (key) => !const {
                'generation',
                'afterId',
                'order',
                'writeId',
                'deleted',
                'delta',
              }.contains(key),
            )) {
          throw const FormatException('Invalid note line');
        }
        final deleted = raw['deleted']! as bool;
        final delta = raw['delta'];
        if (deleted ? delta != null : delta is! String) {
          throw const FormatException('Invalid note line body');
        }
        if (delta is String) decodeLine(delta);
        final id = entry.key! as String;
        lines[id] = NoteLine(
          id: id,
          generation: generation,
          afterId: raw['afterId']! as String,
          order: raw['order']! as int,
          writeId: raw['writeId']! as String,
          deleted: deleted,
          delta: delta as String?,
        );
      }
    }
    for (final line in lines.values) {
      if (line.afterId.isEmpty) continue;
      final parent = lines[line.afterId];
      if (parent == null || parent.order >= line.order) {
        throw const FormatException('Invalid note order');
      }
    }
    return NoteDocument(generation, Map.unmodifiable(lines));
  }

  /// 改行で分け、書式を保った段落へ新IDを付ける。入力上限の判定は別途行う。
  static NoteDocument fromDelta(
    Delta delta,
    String generation,
    String Function() newId,
  ) {
    final lines = <String, NoteLine>{};
    var after = '';
    var order = 0;
    for (final body in splitNoteDelta(delta)) {
      final id = newId();
      lines[id] = NoteLine(
        id: id,
        generation: generation,
        afterId: after,
        order: ++order,
        writeId: newId(),
        delta: body,
      );
      after = id;
    }
    return NoteDocument(generation, lines);
  }

  /// 同じ挿入先では時計・IDの降順で並べ、到着順によらず同じ順序にする。
  /// 削除済み段落も挿入先としてたどり、表示結果からだけ除く。
  List<NoteLine> get visibleLines {
    final children = <String, List<NoteLine>>{};
    for (final line in lines.values) {
      children.putIfAbsent(line.afterId, () => []).add(line);
    }
    for (final siblings in children.values) {
      siblings.sort((a, b) {
        final order = b.order.compareTo(a.order);
        return order != 0 ? order : b.id.compareTo(a.id);
      });
    }
    final result = <NoteLine>[];
    final pending = [...?children['']?.reversed];
    while (pending.isNotEmpty) {
      final line = pending.removeLast();
      if (!line.deleted) result.add(line);
      pending.addAll(children[line.id]?.reversed ?? const []);
    }
    return result;
  }

  /// 表示段落を結合する。全段落が削除済みでも、Quillに必要な末尾改行を返す。
  Delta toDelta() {
    final delta = Delta();
    for (final line in visibleLines) {
      for (final op in decodeLine(line.delta!).toList()) {
        delta.push(op);
      }
    }
    return delta.isEmpty ? (Delta()..insert('\n')) : delta;
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'generation': generation,
    if (lines.isNotEmpty)
      'lines': {for (final line in lines.values) line.id: line.toJson()},
  };
}

bool _validId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(value);

/// 末尾改行を1つだけ持つ、テキストと書式の段落Deltaを復元する。
/// JSON長・形式・Quillでの復元可否を検証し、不正ならFormatExceptionを投げる。
Delta decodeLine(String encoded) {
  if (encoded.length > noteMaxDeltaLength) {
    throw const FormatException('Note line is too large');
  }
  final json = jsonDecode(encoded);
  if (json is! List<Object?> || json.isEmpty) {
    throw const FormatException('Invalid paragraph Delta');
  }
  final delta = Delta();
  for (final op in json) {
    if (op is! Map<String, Object?> ||
        op['insert'] is! String ||
        (op['insert']! as String).isEmpty ||
        op.keys.any((key) => key != 'insert' && key != 'attributes')) {
      throw const FormatException('Only text inserts are supported');
    }
    final attributes = op['attributes'];
    if (attributes != null && attributes is! Map<String, Object?>) {
      throw const FormatException('Invalid paragraph attributes');
    }
    delta.insert(op['insert'], attributes as Map<String, Object?>?);
  }
  final text = delta.toList().map((op) => op.data! as String).join();
  if (!text.endsWith('\n') || '\n'.allMatches(text).length != 1) {
    throw const FormatException(
      'A paragraph needs exactly one trailing newline',
    );
  }
  try {
    Document.fromDelta(delta).close();
  } on ArgumentError catch (e) {
    throw FormatException('Invalid paragraph: $e');
  } on StateError catch (e) {
    throw FormatException('Invalid paragraph: $e');
  } on TypeError catch (e) {
    throw FormatException('Invalid paragraph: $e');
  } on AssertionError catch (e) {
    throw FormatException('Invalid paragraph: $e');
  }
  return delta;
}

/// Quillの操作境界と段落境界は一致しないため、改行ごとに属性を保って分割する。
List<String> splitNoteDelta(Delta delta) {
  final lines = <String>[];
  var line = Delta();
  for (final op in delta.toList()) {
    if (!op.isInsert || op.data is! String) {
      throw const FormatException('Only text notes are supported');
    }
    final text = op.data! as String;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] != '\n') continue;
      line.insert(text.substring(start, i + 1), op.attributes);
      lines.add(jsonEncode(line.toJson()));
      line = Delta();
      start = i + 1;
    }
    if (start < text.length) line.insert(text.substring(start), op.attributes);
  }
  if (line.isNotEmpty || lines.isEmpty) {
    throw const FormatException('A note must end with a newline');
  }
  return lines;
}

/// 入力上限用の書記素数。絵文字・結合文字をまとめ、末尾改行を除く。
int lineCharacters(String line) {
  final text = decodeLine(line).toList().map((op) => op.data! as String).join();
  return text.substring(0, text.length - 1).characters.length;
}

/// カーソル位置・編集差分用のUTF-16長。書記素数とは異なり末尾改行も含む。
int lineLength(String line) =>
    decodeLine(line).toList().fold(0, (sum, op) => sum + op.length!);

/// 入力上限を検証する。受信済みの超過は保持し、超過量の合計を減らす変更だけ許す。
bool acceptsNoteChange(Delta before, Delta after) {
  final oldLines = splitNoteDelta(before);
  final newLines = splitNoteDelta(after);
  int excess(List<String> lines) => lines.fold(
    0,
    (sum, line) => sum + math.max(0, lineCharacters(line) - noteMaxCharacters),
  );
  if (newLines.any((line) => line.length > noteMaxDeltaLength)) return false;
  final oldExcess =
      excess(oldLines) + math.max(0, oldLines.length - noteMaxLines);
  final newExcess =
      excess(newLines) + math.max(0, newLines.length - noteMaxLines);
  if (oldExcess > 0) return newExcess < oldExcess;
  return newLines.length <=
          (oldLines.length > noteMaxLines ? oldLines.length : noteMaxLines) &&
      excess(newLines) <= excess(oldLines);
}

/// 変更前の段落開始位置を変換し、分割では左、結合では最初のIDを維持する。
/// 返すのは変更・削除対象だけで、未変更の段落は含めない。
Map<String, NoteLine> editNoteLines(
  NoteDocument document,
  Delta before,
  Delta change,
  String Function() newId,
) {
  final visible = document.visibleLines;
  final after = before.compose(change);
  final bodies = splitNoteDelta(after);
  final starts = <int>[];
  var offset = 0;
  for (final body in bodies) {
    starts.add(offset);
    offset += lineLength(body);
  }
  final deletions = <(int, int)>[];
  var oldOffset = 0;
  for (final op in change.toList()) {
    if (op.isInsert) continue;
    final end = oldOffset + op.length!;
    if (op.isDelete) {
      if (deletions.isNotEmpty && deletions.last.$2 == oldOffset) {
        deletions[deletions.length - 1] = (deletions.last.$1, end);
      } else {
        deletions.add((oldOffset, end));
      }
    }
    oldOffset = end;
  }
  final ids = <int, NoteLine>{};
  var oldStart = 0;
  for (final line in visible) {
    final oldEnd = oldStart + lineLength(line.delta!);
    // 全段落を消した場合は、その位置へ詰められる次の段落からIDを奪わない。
    if (!deletions.any((range) => range.$1 <= oldStart && range.$2 >= oldEnd)) {
      final mapped = change.transformPosition(oldStart);
      var index = starts.lastIndexWhere((start) => start <= mapped);
      if (index < 0) index = 0;
      ids.putIfAbsent(index, () => line);
    }
    oldStart = oldEnd;
  }
  var clock = document.lines.values.fold(
    0,
    (n, line) => n > line.order ? n : line.order,
  );
  var previous = '';
  final result = <String, NoteLine>{};
  final used = <String>{};
  for (var i = 0; i < bodies.length; i++) {
    final existing = ids[i];
    final line =
        existing ??
        NoteLine(
          id: newId(),
          generation: document.generation,
          afterId: previous,
          order: ++clock,
          writeId: newId(),
          delta: bodies[i],
        );
    used.add(line.id);
    previous = line.id;
    if (existing == null || line.delta != bodies[i]) {
      result[line.id] = line.edit(bodies[i], newId());
    }
  }
  for (final line in visible) {
    if (!used.contains(line.id)) result[line.id] = line.edit(null, newId());
  }
  return result;
}
