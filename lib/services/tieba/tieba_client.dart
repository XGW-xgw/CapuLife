import 'package:flutter/foundation.dart';

import 'tieba_api.dart';
import 'tieba_models.dart';
import 'tieba_session.dart';

class TiebaClient {
  TiebaClient._(this.store, this.api);

  static TiebaClient? _instance;

  final TiebaSessionStore store;
  final TiebaApi api;

  /// Bumped whenever the signed-in account changes, so the shell/home can
  /// refresh message badges without polling the network.
  final ValueNotifier<int> authRevision = ValueNotifier(0);

  TiebaAccount? get account => store.account;
  TiebaDevice get device => store.device;
  bool get loggedIn => account != null && account!.bduss.isNotEmpty;

  static Future<TiebaClient> load() async {
    if (_instance != null) return _instance!;
    final store = await TiebaSessionStore.load();
    final client = TiebaClient._(
      store,
      TiebaApi(
        device: store.device,
        onDeviceChanged: store.save,
      ),
    );
    _instance = client;
    return client;
  }

  Future<TiebaAccount> loginWithCookies(String rawCookie) async {
    final jar = parseTiebaCookies(rawCookie);
    final bduss = jar['BDUSS'] ?? '';
    if (bduss.isEmpty) {
      throw TiebaApiException(-5, 'Cookie 中未找到 BDUSS');
    }
    final webRaw = await TiebaCookies.read();
    final webJar = parseTiebaCookies(webRaw);
    if (webJar['BDUSS'] != null && webJar['BDUSS'] != bduss) {
      if ((jar['BAIDUID'] ?? '').isEmpty && (webJar['BAIDUID'] ?? '').isNotEmpty) {
        jar['BAIDUID'] = webJar['BAIDUID']!;
      }
    } else {
      for (final entry in webJar.entries) {
        jar.putIfAbsent(entry.key, () => entry.value);
      }
    }
    final previous = (
      bduss: device.bduss,
      stoken: device.stoken,
      tbs: device.tbs,
      zid: device.zid,
    );
    device.bduss = bduss;
    device.stoken = jar['STOKEN'] ?? '';
    device.tbs = '';
    device.zid = jar['BAIDUZID'] ?? jar['ZID'] ?? '';
    if ((jar['BAIDUID'] ?? '').isNotEmpty) {
      device.baiduId = jar['BAIDUID']!;
    }
    try {
      Map<String, dynamic>? info;
      Object? verifyError;
      try {
        info = await api.verifyLogin(
          bduss: bduss,
          stoken: device.stoken,
        );
      } catch (error) {
        verifyError = error;
        // Some accounts/web sessions are rejected by /c/s/login even though
        // the browser session itself is valid. Ask the web session endpoint
        // for the same identity before giving up.
        try {
          info = await api.webSessionInfo(
            bduss: bduss,
            stoken: device.stoken,
            baiduId: device.baiduId,
          );
        } catch (_) {
          throw verifyError;
        }
      }
      final account = TiebaAccount(
        uid: '${info['uid']}',
        name: '${info['name'] ?? ''}',
        nameShow: '${info['nameShow'] ?? ''}',
        portrait: '${info['portrait'] ?? ''}',
        bduss: bduss,
        stoken: device.stoken,
        tbs: '${info['tbs'] ?? ''}',
        zid: device.zid,
        baiduId: jar['BAIDUID'] ?? device.baiduId,
        cookie: tiebaCookieHeader(jar),
        fansNum: tiebaInt(info['fansNum']),
        concernNum: tiebaInt(info['concernNum']),
        postNum: tiebaInt(info['postNum']),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      store.setAccount(account);
      authRevision.value += 1;
      return account;
    } catch (_) {
      device
        ..bduss = previous.bduss
        ..stoken = previous.stoken
        ..tbs = previous.tbs
        ..zid = previous.zid;
      rethrow;
    }
  }

  Future<void> logout() async {
    await store.logout();
    authRevision.value += 1;
  }

  void absorbTbs(String tbs) {
    if (tbs.isEmpty) return;
    final current = account;
    if (current == null) return;
    device.tbs = tbs;
    if (current.tbs == tbs) return;
    current.tbs = tbs;
    current.updatedAt = DateTime.now().millisecondsSinceEpoch;
    store.save();
  }

  /// Re-read the tieba-domain cookie jar and refresh STOKEN / z_id / tbs when
  /// a session is missing write credentials. This mirrors TiebaFrosted's
  /// write-session self-check and keeps an old half-filled login usable.
  Future<void> healSession() async {
    final current = account;
    if (current == null || current.bduss.isEmpty) return;
    try {
      final raw = await TiebaCookies.read();
      if (raw.isEmpty) return;
      final jar = parseTiebaCookies(raw);
      final jarBduss = jar['BDUSS'] ?? '';
      if (jarBduss.isNotEmpty && jarBduss != current.bduss) return;
      final stokenRaw = jar['STOKEN'] ?? '';
      final stoken = stokenRaw.isNotEmpty ? stokenRaw : current.stoken;
      final zidRaw = jar['BAIDUZID'] ?? jar['ZID'] ?? '';
      final zid = zidRaw.isNotEmpty ? zidRaw : current.zid;
      final baiduIdRaw = jar['BAIDUID'] ?? '';
      final baiduId = baiduIdRaw.isNotEmpty ? baiduIdRaw : current.baiduId;
      var tbs = current.tbs;
      if (tbs.isEmpty || stoken != current.stoken) {
        try {
          final info = await api.verifyLogin(
            bduss: current.bduss,
            stoken: stoken,
          );
          final nextTbs = '${info['tbs'] ?? ''}';
          if (nextTbs.isNotEmpty) tbs = nextTbs;
        } catch (_) {
          // Keep the existing tbs; the next write will surface the real error.
        }
      }
      final changed = stoken != current.stoken ||
          zid != current.zid ||
          baiduId != current.baiduId ||
          tbs != current.tbs;
      if (!changed) return;
      final next = TiebaAccount(
        uid: current.uid,
        name: current.name,
        nameShow: current.nameShow,
        portrait: current.portrait,
        bduss: current.bduss,
        stoken: stoken,
        tbs: tbs,
        zid: zid,
        baiduId: baiduId,
        cookie: tiebaCookieHeader(jar),
        fansNum: current.fansNum,
        concernNum: current.concernNum,
        postNum: current.postNum,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      store.setAccount(next);
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    final current = account;
    if (current == null) return;
    final uid = int.tryParse(current.uid) ?? 0;
    if (uid > 0) {
      try {
        final profile = await api.userProfile(uid: uid);
        final user = profile.user;
        if (user != null) {
          final nameShow = '${user['nameShow'] ?? current.nameShow}';
          final portrait = '${user['portrait'] ?? current.portrait}';
          final next = TiebaAccount(
            uid: current.uid,
            name: '${user['name'] ?? current.name}'.isEmpty
                ? current.name
                : '${user['name']}',
            nameShow: nameShow.isEmpty ? current.nameShow : nameShow,
            portrait: portrait.isEmpty ? current.portrait : portrait,
            bduss: current.bduss,
            stoken: current.stoken,
            tbs: profile.tbs.isEmpty ? current.tbs : profile.tbs,
            zid: current.zid,
            baiduId: current.baiduId,
            cookie: current.cookie,
            fansNum: tiebaInt(user['fansNum']) != 0
                ? tiebaInt(user['fansNum'])
                : current.fansNum,
            concernNum: tiebaInt(user['concernNum']) != 0
                ? tiebaInt(user['concernNum'])
                : current.concernNum,
            postNum: tiebaInt(user['postNum']) != 0
                ? tiebaInt(user['postNum'])
                : current.postNum,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          store.setAccount(next);
          return;
        }
      } catch (_) {}
    }
    final keyword = current.name.isNotEmpty
        ? current.name
        : (current.nameShow.isNotEmpty ? current.nameShow : '');
    if (keyword.isEmpty) return;
    try {
      final users = await api.searchUser(keyword);
      Map<String, dynamic>? target;
      for (final user in users) {
        final id = '${user['id'] ?? user['user_id'] ?? ''}';
        if (id == current.uid) {
          target = user;
          break;
        }
      }
      if (target == null) return;
      final nameShow = '${target['show_nickname'] ?? target['name_show'] ?? current.nameShow}';
      final portrait = '${target['portrait'] ?? current.portrait}';
      final next = TiebaAccount(
        uid: current.uid,
        name: current.name,
        nameShow: nameShow.isEmpty ? current.nameShow : nameShow,
        portrait: portrait,
        bduss: current.bduss,
        stoken: current.stoken,
        tbs: current.tbs,
        zid: current.zid,
        baiduId: current.baiduId,
        cookie: current.cookie,
        fansNum: tiebaInt(target['fans_num']) != 0
            ? tiebaInt(target['fans_num'])
            : current.fansNum,
        concernNum: tiebaInt(target['concern_num']) != 0
            ? tiebaInt(target['concern_num'])
            : current.concernNum,
        postNum: tiebaInt(target['post_num']) != 0
            ? tiebaInt(target['post_num'])
            : current.postNum,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      store.setAccount(next);
    } catch (_) {}
  }

  TiebaUser selfUser() {
    final current = account;
    if (current == null) return TiebaUser();
    return TiebaUser(
      id: int.tryParse(current.uid) ?? 0,
      name: current.displayName,
      account: current.name,
      avatar: tiebaAvatarUrl(current.portrait),
      portraitRaw: current.portrait,
      fansNum: current.fansNum,
      concernNum: current.concernNum,
      postNum: current.postNum,
    );
  }
}