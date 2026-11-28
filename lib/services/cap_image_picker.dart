import 'package:flutter/services.dart';

class CapImagePicker {
  static const _channel = MethodChannel('capulife/media');

  static Future<String?> pickImage() async {
    try {
      final result = await _channel.invokeMethod<String>('pickImage');
      if (result == null || result.isEmpty) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> pickImages({int count = 9}) async {
    try {
      final result = await _channel.invokeListMethod<String>('pickImages', {
        'count': count.clamp(1, 9),
      });
      if (result == null) return const [];
      return result.where((path) => path.isNotEmpty).toList();
    } catch (_) {
      final single = await pickImage();
      return single == null ? const [] : [single];
    }
  }
}
