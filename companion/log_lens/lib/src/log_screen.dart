import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:share_plus/share_plus.dart';

import 'drive_uploader.dart';
import 'logcat_service.dart';

class LogScreen extends StatefulWidget {
  final AppInfo app;

  const LogScreen({super.key, required this.app});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  static const _maxLines = 4000;
  static const _autoUploadInterval = Duration(minutes: 5);

  final _service = LogcatService();
  final _uploader = DriveUploader();
  final _scrollController = ScrollController();
  final List<String> _lines = [];

  StreamSubscription<String>? _subscription;
  Timer? _autoUploadTimer;
  bool _running = false;
  bool _autoUpload = false;
  bool _autoScroll = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _status = 'Starting capture for ${widget.app.packageName}…';
    });
    _subscription = _service.lines.listen(_onLine);
    try {
      await _service.start(widget.app.packageName);
      setState(() => _status = null);
    } catch (error) {
      setState(() {
        _running = false;
        _status = 'Failed to start logcat: $error\n\n'
            'Make sure READ_LOGS has been granted once via:\n'
            'adb shell pm grant $_thisPackagePlaceholder android.permission.READ_LOGS';
      });
    }
  }

  // Filled in once the app's own package name is known at build time — see
  // android/app/build.gradle `applicationId`.
  static const _thisPackagePlaceholder = 'com.asimfarooq.log_lens';

  void _onLine(String line) {
    setState(() {
      _lines.add(line);
      if (_lines.length > _maxLines) {
        _lines.removeRange(0, _lines.length - _maxLines);
      }
    });
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _stop() async {
    await _service.stop();
    setState(() => _running = false);
  }

  Future<void> _toggleCapture() async {
    if (_running) {
      await _stop();
    } else {
      _lines.clear();
      await _start();
    }
  }

  String _composeLog() => _lines.join('\n');

  Future<void> _shareManually() async {
    if (_lines.isEmpty) {
      _showSnack('Nothing captured yet.');
      return;
    }
    final fileName = _fileName();
    await SharePlus.instance.share(
      ShareParams(
        text: 'Log Lens capture for ${widget.app.packageName}',
        subject: fileName,
        files: [XFile.fromData(
          Uint8List.fromList(utf8.encode(_composeLog())),
          name: fileName,
          mimeType: 'text/plain',
        )],
      ),
    );
  }

  Future<void> _toggleAutoUpload(bool value) async {
    if (value) {
      final signedIn = _uploader.isSignedIn || await _uploader.signIn();
      if (!signedIn) {
        _showSnack('Google Drive sign-in isn\'t wired up yet — see drive_uploader.dart.');
        setState(() => _autoUpload = false);
        return;
      }
      _autoUploadTimer?.cancel();
      _autoUploadTimer = Timer.periodic(_autoUploadInterval, (_) => _autoUploadNow());
      setState(() => _autoUpload = true);
      _showSnack('Automatic Drive uploads enabled (every ${_autoUploadInterval.inMinutes} min).');
    } else {
      _autoUploadTimer?.cancel();
      _autoUploadTimer = null;
      setState(() => _autoUpload = false);
    }
  }

  Future<void> _autoUploadNow() async {
    if (_lines.isEmpty) return;
    try {
      await _uploader.uploadLogFile(fileName: _fileName(), content: _composeLog());
    } catch (error) {
      _showSnack('Auto-upload failed: $error');
    }
  }

  String _fileName() {
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    return 'log-lens_${widget.app.packageName}_$stamp.txt';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _autoUploadTimer?.cancel();
    _subscription?.cancel();
    _service.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(_lines.clear),
          ),
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause_circle_outline),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          if (_status != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(_status!),
            ),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _toggleCapture,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow),
              label: Text(_running ? 'Stop' : 'Start'),
            ),
            OutlinedButton.icon(
              onPressed: _shareManually,
              icon: const Icon(Icons.ios_share),
              label: const Text('Share log (manual)'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Auto-upload to Drive'),
                Switch(value: _autoUpload, onChanged: _toggleAutoUpload),
              ],
            ),
            Text('${_lines.length} lines', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList() {
    if (_lines.isEmpty) {
      return Center(
        child: Text(
          _running ? 'Waiting for log lines from ${widget.app.packageName}…' : 'Capture stopped — tap Start.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return Container(
      color: const Color(0xFF0D1117),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _lines.length,
        itemBuilder: (context, index) {
          final line = _lines[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Text(
              line,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: _colorForLine(line),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _colorForLine(String line) {
    // `threadtime` format places the priority letter right before the tag,
    // e.g. "... E AndroidRuntime: ...". Color by severity for quick scanning.
    final match = RegExp(r'\s([VDIWEF])\s').firstMatch(line);
    switch (match?.group(1)) {
      case 'E':
      case 'F':
        return const Color(0xFFFF6B6B);
      case 'W':
        return const Color(0xFFFFD166);
      case 'I':
        return const Color(0xFF8FE3A0);
      case 'D':
        return const Color(0xFF8FC7FF);
      default:
        return const Color(0xFFB6BEC9);
    }
  }
}
