import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Streams `logcat` output filtered down to a single app's process.
///
/// Requires the `android.permission.READ_LOGS` permission, which Android only
/// grants to apps via `adb shell pm grant <package> android.permission.READ_LOGS`
/// (a one-time setup step — regular install-time grants are not allowed).
class LogcatService {
  Process? _process;
  StreamSubscription<String>? _subscription;
  final _controller = StreamController<String>.broadcast();

  /// Emits one formatted line per log entry belonging to the watched app.
  Stream<String> get lines => _controller.stream;

  bool get isRunning => _process != null;

  /// Starts tailing logcat, keeping only lines whose PID matches [packageName].
  Future<void> start(String packageName) async {
    await stop();

    final pid = await _resolvePid(packageName);

    final args = ['-v', 'threadtime'];
    final process = await Process.start('logcat', args, runInShell: false);
    _process = process;

    final stdoutLines = process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    _subscription = stdoutLines.listen((line) {
      if (pid == null || _lineMatchesPid(line, pid)) {
        _controller.add(line);
      }
    }, onError: (Object error) {
      _controller.add('[log-lens] logcat stream error: $error');
    });

    if (pid == null) {
      _controller.add(
        '[log-lens] Could not resolve a PID for $packageName yet — showing the full '
        'system log until the app starts. Launch $packageName to narrow the stream.',
      );
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _process?.kill();
    _process = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  /// `threadtime` lines look like: `MM-DD HH:MM:SS.mmm  PID  TID L TAG: msg`
  /// — the PID is the first whitespace-separated token after the timestamp.
  bool _lineMatchesPid(String line, String pid) {
    final parts = line.trimLeft().split(RegExp(r'\s+'));
    // parts[0..1] = date/time, parts[2] = pid, parts[3] = tid
    return parts.length > 2 && parts[2] == pid;
  }

  Future<String?> _resolvePid(String packageName) async {
    try {
      final result = await Process.run('sh', ['-c', 'pidof -s $packageName']);
      final out = (result.stdout as String).trim();
      if (result.exitCode == 0 && out.isNotEmpty) return out;
    } catch (_) {
      // `pidof` may be unavailable on some builds — fall back to `ps`.
    }
    try {
      final result = await Process.run('sh', ['-c', "ps -A -o PID,ARGS | grep $packageName | head -n1"]);
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return null;
      final pid = out.trimLeft().split(RegExp(r'\s+')).first;
      return pid.isEmpty ? null : pid;
    } catch (_) {
      return null;
    }
  }
}
