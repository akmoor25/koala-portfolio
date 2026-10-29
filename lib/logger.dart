import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:stack_trace/stack_trace.dart' show Frame, Trace;

/// アプリ全体で使うログ出力。コンソールにだけ出力する。
///
/// リリースビルドでは何も出力しない。
final AppLogger logger = AppLogger();

/// 呼び出し位置つきでコンソールへログを出す。
class AppLogger {
  final Logger _console = Logger(
    printer: _LocationPrinter(),
    filter: _NotInReleaseFilter(),
  );

  /// 詳細なトレース用のログ。
  void t(Object message, [Object? error, StackTrace? stackTrace]) =>
      _console.log(Level.trace, message, error: error, stackTrace: stackTrace);

  /// デバッグ用のログ。
  void d(Object message, [Object? error, StackTrace? stackTrace]) =>
      _console.log(Level.debug, message, error: error, stackTrace: stackTrace);

  /// 動作の記録用のログ。
  void i(Object message, [Object? error, StackTrace? stackTrace]) =>
      _console.log(Level.info, message, error: error, stackTrace: stackTrace);

  /// 回復できる問題のログ。
  void w(Object message, [Object? error, StackTrace? stackTrace]) => _console
      .log(Level.warning, message, error: error, stackTrace: stackTrace);

  /// エラーのログ。
  void e(Object message, [Object? error, StackTrace? stackTrace]) =>
      _console.log(Level.error, message, error: error, stackTrace: stackTrace);

  /// 続行できない致命的なエラーのログ。
  void f(Object message, [Object? error, StackTrace? stackTrace]) =>
      _console.log(Level.fatal, message, error: error, stackTrace: stackTrace);
}

String _levelLabel(Level level) => switch (level) {
  Level.trace => 'v',
  Level.debug => 'd',
  Level.info => 'i',
  Level.warning => 'w',
  Level.error => 'e',
  Level.fatal => 'wtf',
  _ => '',
};

// レベルごとの文字色。値は ANSI の 256 色の番号（12 青、208 橙、196 赤、199 桃）。
final Map<Level, AnsiColor> _levelColors = {
  Level.trace: AnsiColor.fg(AnsiColor.grey(0.5)),
  Level.debug: const AnsiColor.none(),
  Level.info: const AnsiColor.fg(12),
  Level.warning: const AnsiColor.fg(208),
  Level.error: const AnsiColor.fg(196),
  Level.fatal: const AnsiColor.fg(199),
};

AnsiColor _colorOf(Level level) =>
    _levelColors[level] ?? const AnsiColor.none();

/// 時刻・呼び出し位置・レベルを 1 行にまとめて出力する。
class _LocationPrinter extends PrettyPrinter {
  // スタックの先頭にある、このファイルの 3 段（_stackTraceText、log、AppLogger の各メソッド）を
  // 飛ばし、呼び出し元から 5 段まで出す。logger パッケージの中の段は、パッケージが除く。
  _LocationPrinter() : super(stackTraceBeginIndex: 3, methodCount: 5);

  @override
  List<String> log(LogEvent event) {
    final lines = <String>[];
    final errorText = event.error?.toString();
    if (errorText != null) {
      final errorColor = _colorOf(Level.error);
      lines.addAll(errorText.split('\n').map(errorColor.call));
    }

    final location = _callerFrame()?.location;
    final message =
        '${DateTime.now()} $location (${_levelLabel(event.level)}) '
        '${event.message}';
    lines.add(_colorOf(event.level)(message));

    final isError = event.level == Level.error || event.level == Level.fatal;
    if (errorText != null || isError) {
      final stackText = _stackTraceText(event);
      if (stackText != null) {
        final stackColor = _colorOf(Level.trace);
        lines.addAll(stackText.split('\n').map(stackColor.call));
      }
    }
    return lines;
  }

  String? _stackTraceText(LogEvent event) {
    final stackTrace = event.stackTrace;
    if (stackTrace == null) {
      final count = methodCount ?? 0;
      return count > 0 ? formatStackTrace(StackTrace.current, count) : null;
    }
    final count = errorMethodCount ?? 0;
    return count > 0 ? formatStackTrace(stackTrace, count) : null;
  }

  Frame? _callerFrame() {
    // _callerFrame、log、Logger.log（パッケージ）、AppLogger の各メソッドの 4 段を飛ばすと、呼び出し元になる。
    final frames = Trace.current(4).frames;
    return frames.isEmpty ? null : frames.first;
  }
}

/// リリースビルドではログを出さない。
class _NotInReleaseFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) =>
      !kReleaseMode && event.level.index >= (level ?? Level.trace).index;
}
