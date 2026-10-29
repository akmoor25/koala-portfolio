import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../l10n/write_task.dart';
import '../../logger.dart';

/// ローカル反映後にサーバーから拒否された書き込み。
class FirebaseWriteFailure {
  const FirebaseWriteFailure(this.task, {this.note = false});

  final WriteTask? task;
  final bool note;
}

/// SDK の永続化キューを使い、画面はサーバー応答ではなくローカル反映を待つ。
class FirebaseLocalWrites {
  final _failures = StreamController<FirebaseWriteFailure>.broadcast();
  final _pending = <Future<void>>{};

  Stream<FirebaseWriteFailure> get failures => _failures.stream;

  /// ローカル作成した参加権限がサーバーで確定するまで、購読の再試行を待たせる。
  Future<void> waitForPendingWrites() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  Future<void> update(
    DatabaseReference reference,
    Map<String, Object?> values, {
    WriteTask? task,
    bool note = false,
  }) => write(
    reference,
    () => reference.update(values),
    (snapshot) => values.entries.every(
      (entry) => _matches(snapshot.child(entry.key).value, entry.value),
    ),
    task: task,
    note: note,
  );

  Future<void> set(
    DatabaseReference reference,
    Object? value, {
    WriteTask? task,
    bool note = false,
  }) => write(
    reference,
    () => reference.set(value),
    (snapshot) => _matches(snapshot.value, value),
    task: task,
    note: note,
  );

  /// [reference] は読み取り権限があり、更新を確認できる最小の場所にする。
  Future<void> write(
    DatabaseReference reference,
    Future<void> Function() action,
    bool Function(DataSnapshot) matches, {
    WriteTask? task,
    bool note = false,
  }) async {
    final local = Completer<void>();
    var submitted = false;
    var applied = false;
    final subscription = reference.onValue.listen(
      (event) {
        if (!submitted || local.isCompleted || !matches(event.snapshot)) return;
        applied = true;
        local.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!local.isCompleted) local.completeError(error, stack);
      },
    );
    try {
      submitted = true;
      late final Future<void> server;
      server = action()
          .then(
            (_) {
              if (!local.isCompleted) local.complete();
            },
            onError: (Object error, StackTrace stack) {
              if (!local.isCompleted) {
                local.completeError(error, stack);
              } else {
                logger.e('Firebase queued write failed', error, stack);
                if (applied) {
                  _failures.add(FirebaseWriteFailure(task, note: note));
                }
              }
            },
          )
          .whenComplete(() => _pending.remove(server));
      _pending.add(server);
      unawaited(server);
      await local.future;
    } finally {
      await subscription.cancel();
    }
  }

  /// 読み取り権限のない通知トークンなどは、送信を開始して失敗をログに残す。
  void enqueue(Future<void> Function() action) {
    unawaited(
      action().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          logger.w('Firebase background write failed', error, stack);
        },
      ),
    );
  }

  static bool _matches(Object? actual, Object? expected) {
    if (expected is Map) {
      if (expected.length == 1 && expected['.sv'] == 'timestamp') {
        return actual is num;
      }
      final entries = expected.entries.where((entry) => entry.value != null);
      if (entries.isEmpty) return actual == null;
      return actual is Map &&
          actual.length == entries.length &&
          entries.every((entry) => _matches(actual[entry.key], entry.value));
    }
    if (expected is List) {
      return actual is List &&
          actual.length == expected.length &&
          List.generate(
            expected.length,
            (index) => _matches(actual[index], expected[index]),
          ).every((matches) => matches);
    }
    return actual == expected;
  }
}
