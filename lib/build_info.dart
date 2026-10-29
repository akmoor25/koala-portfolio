/// ビルドしたコミットの短いハッシュ。
///
/// CI が `--dart-define=GIT_COMMIT=...` で渡す。手元のビルドでは `dev`。
/// 「このアプリについて」に表示して、配った APK がどのソースから作られたかを
/// 突き合わせられるようにする。
const String gitCommit = String.fromEnvironment(
  'GIT_COMMIT',
  defaultValue: 'dev',
);
