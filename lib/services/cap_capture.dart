import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/cap_ledger.dart';
import '../data/cap_store.dart';

/// Bridges Android notification listening to the local ledger.
/// Notification-channel payments enter the ledger directly (with a guessed
/// category); anything that cannot be classified stays in `ledger.pending`.
class CapCapture {
  static const _channel = MethodChannel('capulife/capture');

  static Future<void> setWatchedApps(List<String> apps) async {
    try {
      await _channel.invokeMethod('setWatchedApps', apps);
    } catch (_) {}
  }

  static Future<void> setPageCaptureEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setPageCaptureEnabled', enabled);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _pullRaw(String method) async {
    try {
      final raw = await _channel.invokeMethod<String>(method);
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> peekRaw() => _pullRaw('peekRawJson');

  static Future<int> sync(CapStore store) async {
    if (!store.settings.autoLedger) return 0;
    final events = await _pullRaw('pullCapturesJson');
    if (events.isEmpty) return 0;
    var added = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final event in events) {
      final amountCents = (event['amountCents'] as num?)?.toInt() ?? 0;
      if (amountCents <= 0) continue;
      final at = (event['at'] as num?)?.toInt() ?? now;
      final merchant = '${event['merchant'] ?? ''}'.trim();
      final text = '${event['text'] ?? ''}';
      final isAuto = event['auto'] == true;
      final type = event['type'] == 'income' ? 'income' : 'expense';
      final source = '${event['source'] ?? 'notification'}';
      if (!isAuto) {
        final existingPending = store.ledger.pending.any(
          (item) =>
              '${item['id']}' == '${event['id']}' ||
              ('${item['type'] ?? 'expense'}' == type &&
                  ((item['amountCents'] as num?)?.toInt() ?? 0) == amountCents &&
                  (((item['at'] as num?)?.toInt() ?? 0) - at).abs() <
                      10 * 60 * 1000),
        );
        if (existingPending) continue;
        final duplicateTx = store.ledger.transactions.any(
          (tx) =>
              tx.amountCents == amountCents &&
              tx.type == type &&
              (tx.timestamp - at).abs() < 10 * 60 * 1000,
        );
        if (duplicateTx) continue;
        store.addLedgerPending({...event, 'source': source});
        added += 1;
        continue;
      }
      // Avoid importing the same notification twice (system may re-post it).
      final duplicate = store.ledger.transactions.any(
        (tx) =>
            tx.amountCents == amountCents &&
            tx.note.trim() == merchant &&
            (tx.timestamp - at).abs() < 5 * 60 * 1000,
      );
      if (duplicate) continue;
      final categoryId = suggestLedgerCategory(
        store.ledger,
        merchant,
        text: text,
      );
      final saved = store.upsertLedgerTransaction(
        type: type,
        amountCents: amountCents,
        categoryId: categoryId,
        note: merchant,
        timestamp: at,
        source: source,
      );
      if (saved != null) {
        // A page capture for the same payment may already be waiting for
        // confirmation; the notification is authoritative, so drop it.
        final pendingMatches = store.ledger.pending
            .where(
              (item) =>
                  ((item['amountCents'] as num?)?.toInt() ?? 0) == amountCents &&
                  '${item['type'] ?? 'expense'}' == type &&
                  (((item['at'] as num?)?.toInt() ?? 0) - at).abs() <
                      10 * 60 * 1000,
            )
            .map((item) => '${item['id'] ?? ''}')
            .where((id) => id.isNotEmpty)
            .toList();
        for (final id in pendingMatches) {
          store.dismissLedgerCapture(id);
        }
        added += 1;
      }
    }
    return added;
  }
}
