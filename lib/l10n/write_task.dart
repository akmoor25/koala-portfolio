import 'app_localizations.dart';

/// 書き込みの種類。失敗したときに、何に失敗したかを利用者へ伝えるために使う。
enum WriteTask {
  /// ニックネームの保存。
  saveNickname,

  /// しおりの作成。
  createTrip,

  /// サンプルのしおりの追加。
  addSamples,

  /// しおりの更新。
  updateTrip,

  /// しおりの削除。
  deleteTrip,

  /// 共同編集の設定。
  enableSharing,

  /// 共同編集の停止。
  disableSharing,

  /// しおりから抜ける操作。
  leaveTrip,

  /// しおりの期間の更新。
  updatePeriod,

  /// 旅程の追加。
  addPlan,

  /// 旅程の更新。
  updatePlan,

  /// 旅程の削除。
  deletePlan,

  /// アカウントと、自分のデータの削除。
  deleteAccount,
}

/// 書き込みの失敗・結果不明を伝える文。
extension WriteTaskMessage on AppLocalizations {
  /// [task] に失敗したことと、通信状況の確認を促す文。
  String writeFailed(WriteTask task) => taskFailed(_taskName(task));

  /// [task] を送信したが、結果を確認できなかったことを伝える文。
  String writeUnconfirmed(WriteTask task) => taskUnconfirmed(_taskName(task));

  String _taskName(WriteTask task) {
    return switch (task) {
      WriteTask.saveNickname => taskSaveNickname,
      WriteTask.createTrip => taskCreateTrip,
      WriteTask.addSamples => taskAddSamples,
      WriteTask.updateTrip => taskUpdateTrip,
      WriteTask.deleteTrip => taskDeleteTrip,
      WriteTask.enableSharing => taskEnableSharing,
      WriteTask.disableSharing => taskDisableSharing,
      WriteTask.leaveTrip => taskLeaveTrip,
      WriteTask.updatePeriod => taskUpdatePeriod,
      WriteTask.addPlan => taskAddPlan,
      WriteTask.updatePlan => taskUpdatePlan,
      WriteTask.deletePlan => taskDeletePlan,
      WriteTask.deleteAccount => taskDeleteAccount,
    };
  }
}
