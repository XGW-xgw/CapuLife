import 'dart:io';

import 'package:flutter/services.dart';

/// Minimal app-private JSON storage.
///
/// The original app keeps its state on-device only. We use the same idea:
/// a single JSON file in the Android files directory. Keeping this in the
/// embedder avoids pulling a third-party storage plugin (and its Gradle
/// buildscript) into the native shell.
class CapStorage {
  static const _channel = MethodChannel('capulife/storage');
  static const _fileName = 'cap_state_v2.json';

  static Future<String?> _filesDir() async {
    try {
      return await _channel.invokeMethod<String>('getFilesDir');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> filesDir() => _filesDir();

  static Future<String?> read() async {
    final dir = await _filesDir();
    if (dir == null) return null;
    try {
      final file = File('$dir/$_fileName');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String contents) async {
    final dir = await _filesDir();
    if (dir == null) return;
    try {
      await File('$dir/$_fileName').writeAsString(contents, flush: true);
    } catch (_) {}
  }
}
