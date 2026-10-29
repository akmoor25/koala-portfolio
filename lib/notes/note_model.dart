import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../data/app_services.dart';
import '../data/data_types.dart';
import '../data/firebase/firebase_services.dart';
import '../entity/leaflet_entity.dart';
import '../helper/deep_equals.dart';
import '../l10n/l10n.dart';
import '../logger.dart';
import 'note_document.dart';
import 'remote_caret.dart';

/// 最後の入力から保存するまでの待ち時間。続けて打つ間は、段落ごとにまとめて 1 回で送る。
const _saveDebounce = Duration(milliseconds: 300);

/// 入力が続いていても、最初の未保存の変更から必ず保存するまでの上限。
/// 打ち続けている間に、他のメンバーへ何も届かない状態を防ぐ。
const _saveDeadline = Duration(seconds: 2);

/// カーソルの位置を送る最短の間隔。書き込みの回数を抑え、最後の位置は必ず送る。
const _caretInterval = Duration(milliseconds: 150);

/// 段落単位の後勝ち同期。送信を終えた古い版が、新しい未送信の編集や受信した版を
/// 消さないよう、未送信、送信中、受信済みの版を分けて持つ。
class NoteModel extends ChangeNotifier {
  NoteModel(this._leaflet, AppServices services)
    : _notes = services.notes,
      _presence = services.presence,
      _initial = initialOf(services.auth.currentUser?.name) {
    quillController = QuillController(
      document: _EditingDocument(_acceptChange, _onChange),
      selection: const TextSelection.collapsed(offset: 0),
    )..readOnly = true;
    quillController.onReplaceText = _acceptReplacement;
    quillController.addListener(_onCaretMaybeMoved);
    editorFocusNode.addListener(_onCaretMaybeMoved);
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _visible = false;
        _presenceQueued = false;
        _caretThrottle.cancel();
        unawaited(putText());
        unawaited(_clearPresence());
      },
      onShow: () {
        _visible = true;
        _onCaretMaybeMoved();
        unawaited(putText());
      },
    );
  }

  final LeafletEntity _leaflet;
  final FirebaseNoteRepository _notes;
  final FirebasePresenceRepository _presence;
  final String _initial;
  late final QuillController quillController;
  final FocusNode editorFocusNode = FocusNode();
  final ScrollController editorScrollController = ScrollController();
  final GlobalKey<EditorState> editorKey = GlobalKey<EditorState>();
  AppLocalizations l10n = AppLocalizationsEn();
  void Function(String message)? onWriteError;
  int editingCount = 0;
  List<RemoteCaret> _carets = const [];
  List<RemoteCaret> get remoteCarets {
    final view = _view;
    if (view == null) return const [];
    final positions = <String, (int, int)>{};
    var start = 0;
    for (final line in view.visibleLines) {
      final length = lineLength(line.delta!);
      positions[line.id] = (start, length);
      start += length;
    }
    return [
      for (final caret in _carets)
        if (caret.generation == view.generation &&
            positions.containsKey(caret.lineId))
          RemoteCaret(
            uid: caret.uid,
            name: caret.name,
            index:
                positions[caret.lineId]!.$1 +
                caret.index.clamp(0, positions[caret.lineId]!.$2 - 1),
          ),
    ];
  }

  bool invalidFormat = false;
  bool readFailed = false;
  bool get ready =>
      !_closed && _view != null && !invalidFormat && !readFailed && !_retrying;
  bool get hasUnsavedChanges => _dirty.isNotEmpty || _flight.isNotEmpty;
  Object? get unreadableValue => _raw;

  Object? _raw;
  NoteDocument? _remote;
  NoteDocument? _view;
  final Map<String, NoteLine> _dirty = {};
  Map<String, NoteLine> _flight = {};
  Future<bool>? _saving;
  Timer? _debounce;
  Timer? _deadline;
  bool _closed = false;
  bool _visible = true;
  bool _presenceQueued = false;
  (String, String, int)? _queuedPresence;
  bool _reportedFailure = false;
  bool _reportedLimit = false;
  bool _initializing = false;
  bool _retrying = false;
  StreamSubscription<Object?>? _noteSubscription;
  StreamSubscription<Collaborators>? _collaboratorSubscription;
  late final AppLifecycleListener _lifecycle;
  void Function()? _stopDisconnect;
  late final _caretThrottle = LatestValueThrottle<(String, String, int)?>(
    _caretInterval,
    _writePresence,
  );

  Future<void> fetchNote() async {
    if (_closed || _noteSubscription != null) return;
    _collaboratorSubscription = _presence
        .watchCollaborators(_leaflet.key)
        .listen(
          (value) {
            if (_closed) return;
            editingCount = value.editingCount;
            _carets = value.carets;
            notifyListeners();
          },
          onError: (Object e, StackTrace s) =>
              logger.w('presence listen failed', e, s),
        );
    _noteSubscription = _notes
        .watchNote(_leaflet.key)
        .listen(
          _onNote,
          onError: (Object e, StackTrace s) {
            logger.w('note listen failed', e, s);
            if (_closed) return;
            readFailed = true;
            quillController.readOnly = true;
            _notify();
          },
        );
    final stop = await _presence.keepMyCaretCleanedOnDisconnect(
      _leaflet.key,
      onConnected: () {
        _presenceQueued = false;
        _onCaretMaybeMoved();
      },
    );
    if (_closed) {
      stop();
    } else {
      _stopDisconnect = stop;
    }
  }

  void _onNote(Object? value) {
    if (_closed) return;
    _raw = value;
    readFailed = false;
    if (value == null) {
      _view = null;
      quillController.readOnly = true;
      if (!_initializing) unawaited(resetUnreadableNote(null));
      return;
    }
    final NoteDocument next;
    try {
      next = NoteDocument.parse(value);
    } on FormatException catch (_, s) {
      logger.w('Unreadable note format', null, s);
      invalidFormat = true;
      quillController.readOnly = true;
      _notify();
      return;
    }
    invalidFormat = false;
    if (_remote != null && _remote!.generation != next.generation) {
      _dirty.clear();
      _flight = {};
      quillController.document.history.clear();
      onWriteError?.call(l10n.noteResetRemotely);
    }
    _remote = next;
    var lost = false;
    _dirty.removeWhere((id, line) {
      final deleted = next.lines[id]?.deleted == true;
      lost |= deleted && !line.deleted;
      return deleted;
    });
    _flight = {
      for (final entry in _flight.entries)
        if (next.lines[entry.key]?.deleted != true) entry.key: entry.value,
    };
    if (lost) onWriteError?.call(l10n.noteLineDeleted);
    _reconcile();
  }

  /// 読めなかった値を確認した画面だけが呼ぶ。内容が変わっていたら消さない。
  Future<bool> resetUnreadableNote(Object? expected) async {
    if (_initializing || _closed || readFailed) return false;
    if (!mapEqualsDeep(_raw, expected)) return false;
    _initializing = true;
    final generation = _notes.newNoteId();
    final line = NoteLine(
      id: 'empty',
      generation: generation,
      afterId: '',
      order: 1,
      writeId: _notes.newNoteId(),
      delta: '[{"insert":"\\n"}]',
    );
    try {
      return await _notes.resetNote(
        _leaflet.key,
        expected,
        NoteDocument(generation, {line.id: line}),
      );
    } on WriteUnconfirmed catch (e, s) {
      logger.w('note reset unconfirmed', e, s);
      if (_closed) return false;
      onWriteError?.call(l10n.noteResetUnconfirmed);
      if (_raw == null) {
        readFailed = true;
        _notify();
      }
      return false;
    } on Exception catch (e, s) {
      logger.w('note reset failed', e, s);
      if (_closed) return false;
      onWriteError?.call(l10n.noteSaveFailed);
      if (_raw == null) {
        readFailed = true;
        _notify();
      }
      return false;
    } finally {
      _initializing = false;
    }
  }

  Future<void> retryRead() async {
    if (_closed || _retrying) return;
    _retrying = true;
    invalidFormat = false;
    readFailed = false;
    quillController.readOnly = true;
    _notify();
    try {
      await _noteSubscription?.cancel();
      _noteSubscription = null;
      await _collaboratorSubscription?.cancel();
      _stopDisconnect?.call();
      await fetchNote();
    } finally {
      _retrying = false;
      _notify();
    }
  }

  void _reconcile() {
    final remote = _remote;
    if (remote == null || _closed) return;
    _view = NoteDocument(remote.generation, {
      ...remote.lines,
      ..._flight,
      ..._dirty,
    });
    _applyDelta(_view!.toDelta());
    final visible = _view!.visibleLines;
    final overLimit =
        visible.length > noteMaxLines ||
        visible.any((line) => lineCharacters(line.delta!) > noteMaxCharacters);
    if (overLimit && !_reportedLimit) {
      onWriteError?.call(l10n.noteReceivedLimit);
    }
    _reportedLimit = overLimit;
    quillController.readOnly = false;
    _onCaretMaybeMoved();
    _notify();
  }

  void _applyDelta(Delta target) {
    final current = quillController.document.toDelta();
    final change = current.diff(target);
    if (change.isEmpty) return;
    quillController.ignoreFocusOnTextChange = !editorFocusNode.hasFocus;
    try {
      quillController.compose(
        change,
        quillController.selection,
        ChangeSource.remote,
      );
    } finally {
      quillController.ignoreFocusOnTextChange = false;
    }
  }

  bool _acceptReplacement(int index, int length, Object? data) {
    if (!ready) return false;
    final before = quillController.document.toDelta();
    final change = Delta()..retain(index);
    if (data is String && data.isNotEmpty) change.insert(data);
    if (data is Delta) {
      for (final op in data.toList()) {
        change.push(op);
      }
    }
    if (data is! String && data is! Delta) {
      onWriteError?.call(l10n.noteUnsupported);
      return false;
    }
    if (length > 0) change.delete(length);
    return _acceptChange(before, before.compose(change));
  }

  bool _acceptChange(Delta before, Delta after) {
    if (!ready) return false;
    try {
      if (acceptsNoteChange(before, after)) return true;
      onWriteError?.call(l10n.noteLimit);
    } on FormatException catch (_, s) {
      logger.w('Unsupported note edit', null, s);
      onWriteError?.call(l10n.noteUnsupported);
    }
    return false;
  }

  void _onChange(DocChange event) {
    if (_closed || event.source != ChangeSource.local) return;
    final view = _view;
    if (view == null) return;
    final changes = editNoteLines(
      view,
      event.before,
      event.change,
      _notes.newNoteId,
    );
    _dirty.addAll(changes);
    _view = NoteDocument(view.generation, {...view.lines, ...changes});
    _debounce?.cancel();
    _debounce = Timer(_saveDebounce, () => unawaited(putText()));
    _deadline ??= Timer(_saveDeadline, () => unawaited(putText()));
    _notify();
  }

  /// 保存要求を直列化する。完了した古い版で新しい未送信編集を消さない。
  Future<bool> putText() async {
    if (_closed || !ready) return !hasUnsavedChanges;
    _debounce?.cancel();
    _deadline?.cancel();
    _debounce = null;
    _deadline = null;
    final running = _saving;
    if (running != null) return running;
    final operation = _save();
    _saving = operation;
    try {
      return await operation;
    } finally {
      _saving = null;
    }
  }

  Future<bool> _save() async {
    while (_dirty.isNotEmpty && !_closed && ready) {
      final generation = _view!.generation;
      final batch = Map<String, NoteLine>.of(_dirty);
      _dirty.clear();
      _flight = batch;
      try {
        await _notes.saveNoteLines(_leaflet.key, generation, batch);
        if (_closed) return true;
        if (_remote?.generation == generation) {
          final lines = Map<String, NoteLine>.of(_remote!.lines);
          for (final entry in batch.entries) {
            // 受信したサーバーの値に、より新しい書き込みが入っていれば残す。
            if (lines[entry.key] == null ||
                lines[entry.key]?.writeId == _flight[entry.key]?.writeId) {
              lines[entry.key] = entry.value;
            }
          }
          _remote = NoteDocument(generation, lines);
        }
        _flight = {};
        _reportedFailure = false;
      } on Exception catch (e, s) {
        logger.w('save note lines failed', e, s);
        if (_closed) return false;
        if (_remote?.generation == generation) {
          for (final entry in batch.entries) {
            if (_remote!.lines[entry.key]?.deleted != true) {
              _dirty.putIfAbsent(entry.key, () => entry.value);
            }
          }
        }
        _flight = {};
        if (!_reportedFailure) onWriteError?.call(l10n.noteSaveFailed);
        _reportedFailure = true;
        _reconcile();
        return false;
      }
    }
    _reconcile();
    return !hasUnsavedChanges;
  }

  (String, String, int)? get _caretAddress {
    final view = _view;
    if (!editorFocusNode.hasFocus || view == null) return null;
    final index = quillController.selection.extentOffset;
    var start = 0;
    for (final line in view.visibleLines) {
      final length = lineLength(line.delta!);
      if (index < start + length) {
        return (view.generation, line.id, index - start);
      }
      start += length;
    }
    return null;
  }

  void _onCaretMaybeMoved() {
    if (_closed || !_visible) return;
    final address = _caretAddress;
    if (_presenceQueued && address == _queuedPresence) return;
    _presenceQueued = true;
    _queuedPresence = address;
    if (address == null) {
      _caretThrottle.cancel();
      _writePresence(null);
    } else {
      _caretThrottle.add(address);
    }
  }

  void _writePresence((String, String, int)? address) {
    if (!_visible || _closed) return;
    unawaited(
      _guardPresence(
        () => _presence.writeMyCaret(
          _leaflet.key,
          name: _initial,
          index: address?.$3,
          generation: address?.$1,
          lineId: address?.$2,
        ),
      ),
    );
  }

  Future<void> _clearPresence() =>
      _guardPresence(() => _presence.clearMyCaret(_leaflet.key));

  Future<void> _guardPresence(Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (e, s) {
      logger.w('presence write failed', e, s);
    }
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  /// 画面を閉じたら、退場アニメーション中も保存や画面への通知を再開しない。
  /// エディタの破棄は、画面が実際に取り除かれるdisposeまで待つ。
  void stopEditing() {
    _closed = true;
    _debounce?.cancel();
    _deadline?.cancel();
    _caretThrottle.cancel();
  }

  @override
  void dispose() {
    stopEditing();
    _lifecycle.dispose();
    _stopDisconnect?.call();
    unawaited(_noteSubscription?.cancel());
    unawaited(_collaboratorSubscription?.cancel());
    unawaited(_clearPresence());
    quillController.removeListener(_onCaretMaybeMoved);
    editorFocusNode.removeListener(_onCaretMaybeMoved);
    quillController.dispose();
    editorFocusNode.dispose();
    editorScrollController.dispose();
    super.dispose();
  }
}

/// Quillの非同期changesより先にDBの受信が来ても、ローカル変更を取りこぼさない。
class _EditingDocument extends Document {
  _EditingDocument(this.accept, this.onLocalChange);

  final bool Function(Delta before, Delta after) accept;
  final void Function(DocChange change) onLocalChange;

  @override
  void compose(Delta delta, ChangeSource changeSource) {
    final before = toDelta();
    if (changeSource == ChangeSource.local &&
        !accept(before, before.compose(delta))) {
      return;
    }
    final ignored = history.ignoreChange;
    if (changeSource == ChangeSource.remote) history.ignoreChange = true;
    try {
      super.compose(delta, changeSource);
    } finally {
      history.ignoreChange = ignored;
    }
    if (changeSource == ChangeSource.remote && !ignored) {
      history.transform(delta);
    }
    if (changeSource == ChangeSource.local) {
      onLocalChange(DocChange(before, delta, changeSource));
    }
  }
}
