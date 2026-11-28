import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_session.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/cap_webview.dart';

class TiebaLoginPage extends StatefulWidget {
  const TiebaLoginPage({super.key});

  @override
  State<TiebaLoginPage> createState() => _TiebaLoginPageState();
}

class _TiebaLoginPageState extends State<TiebaLoginPage> {
  static const _loginUrl =
      'https://wappass.baidu.com/passport?login&u=https%3A%2F%2Ftieba.baidu.com%2Findex%2Ftbwise%2Fmine';
  static const _sessionUrl = 'https://tieba.baidu.com/index/tbwise/mine';

  final GlobalKey<CapWebViewState> _webKey = GlobalKey<CapWebViewState>();
  TiebaClient? _client;
  bool _ready = false;
  bool _verifying = false;
  bool _capturing = false;
  bool _finishing = false;
  int _attempt = 0;
  Timer? _poll;
  String _verifyError = '';
  String _lastTriedBduss = '';
  String _loadedUrl = '';
  int _lastTryAt = 0;
  int _stokenMisses = 0;
  bool _lastVerifyFailed = false;
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    if (!client.loggedIn) {
      // A dead Baidu session survives in the WebView cookie jar and makes
      // passport jump straight back to an unusable tieba session. Start from
      // a clean jar unless the user is currently signed in.
      await TiebaCookies.clearBaidu();
      if (!mounted) return;
    }
    setState(() {
      _client = client;
      _ready = true;
    });
    _startPolling();
  }

  Future<void> _clearAndReload() async {
    setState(() {
      _verifyError = '';
      _lastTriedBduss = '';
      _attempt = 0;
      _stokenMisses = 0;
      _lastVerifyFailed = false;
    });
    await TiebaCookies.clearBaidu();
    await _client?.logout();
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() {
      _client = client;
      _ready = true;
    });
    await _webKey.currentState?.loadUrl(_loginUrl);
    if (mounted) showCapToast(context, '已清除百度旧登录，请重新登录');
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted || _finishing || _verifying) return;
      _probe(auto: true);
    });
  }

  Future<Map<String, String>> _readCookies() async {
    // Tieba's write endpoints only trust the STOKEN scoped to tieba.baidu.com.
    // passport/wappass also store a STOKEN, but that copy is web-login-only and
    // mixing it in gets every write rejected as "not logged in".
    final raw = await TiebaCookies.read();
    if (raw.isEmpty) return <String, String>{};
    return parseTiebaCookies(raw);
  }

  String _cookieHeader(Map<String, String> jar) =>
      jar.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');

  Future<void> _probe({bool auto = false}) async {
    if (!mounted || _capturing || _finishing) return;
    if (auto &&
        !_loadedUrl.contains('/index/tbwise') &&
        DateTime.now().difference(_openedAt).inSeconds < 45) {
      return;
    }
    _capturing = true;
    try {
      var jar = await _readCookies();
      if (jar['BDUSS'] == null || jar['BDUSS']!.isEmpty) {
        if (!auto) {
          if (mounted) {
            setState(() => _verifyError = '还没有检测到百度登录状态，请先在下方页面完成登录。');
          }
        }
        return;
      }
      final bduss = jar['BDUSS']!;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_verifying) return;
      if (auto &&
          _lastVerifyFailed &&
          bduss == _lastTriedBduss) {
        return;
      }
      if (auto &&
          bduss == _lastTriedBduss &&
          now - _lastTryAt < 8000) {
        return;
      }
      if (jar['STOKEN'] == null || jar['STOKEN']!.isEmpty) {
        if (_attempt < 3) {
          _attempt += 1;
          await _webKey.currentState?.loadUrl(_sessionUrl);
          await Future<void>.delayed(const Duration(milliseconds: 900));
          jar = await _readCookies();
        }
        if (auto && (jar['STOKEN'] ?? '').isEmpty) {
          _stokenMisses += 1;
          if (_stokenMisses < 8) {
            // Give passport a little longer to plant the tieba-scoped STOKEN
            // instead of burning the session's tbs immediately.
            return;
          }
        }
      }
      if ((jar['STOKEN'] ?? '').isNotEmpty) _stokenMisses = 0;
      final raw = _cookieHeader(jar);
      if (raw.isEmpty) return;
      _lastTriedBduss = bduss;
      _lastTryAt = now;
      await _finish(raw);
    } finally {
      _capturing = false;
    }
  }

  Future<void> _onLoaded(String url) async {
    _loadedUrl = url;
    if (!mounted || _finishing) return;
    if (url.contains('wappass.baidu.com') && url.contains('passport')) return;
    await _probe(auto: true);
  }

  Future<bool> _finish(String raw) async {
    if (_finishing) return false;
    final client = _client;
    if (client == null) return false;
    _finishing = true;
    if (mounted) {
      setState(() {
        _verifying = true;
        _verifyError = '';
      });
    }
    try {
      final account = await client.loginWithCookies(raw);
      if (!mounted) return false;
      _poll?.cancel();
      _lastVerifyFailed = false;
      final name = account.displayName;
      final extra = account.stoken.isEmpty ? '（缺少 STOKEN，暂只能浏览）' : '';
      showCapToast(context, '欢迎回来，$name$extra');
      unawaited(client.refreshProfile());
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) Navigator.of(context).pop(true);
      return true;
    } catch (error) {
      if (!mounted) return false;
      _lastVerifyFailed = true;
      final message = error is TiebaApiException
          ? error.message
          : '登录失败：$error';
      setState(() => _verifyError = message);
      showCapToast(context, message);
      return false;
    } finally {
      _finishing = false;
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _pasteCookie() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '粘贴百度 Cookie',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(capRpx(context, 16)),
          ),
          child: TextField(
            controller: controller,
            maxLines: 4,
            style: TextStyle(fontSize: capRpx(context, 21), color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'BDUSS=...; STOKEN=...; BAIDUID=...',
              hintStyle: TextStyle(
                fontSize: capRpx(context, 20),
                color: AppColors.mutedSoft,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('登录', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.isEmpty) return;
    final value = raw.contains('=') ? raw : 'BDUSS=$raw';
    await _finish(value);
  }

  @override
  Widget build(BuildContext context) {
    return CapPage(
      child: Stack(
        children: [
          Column(
            children: [
              CapAppHeader(
                title: '登录贴吧',
                subtitle: '登录后同步消息、关注与回复',
                back: true,
                right: GestureDetector(
                  onTap: _pasteCookie,
                  child: Container(
                    height: capRpx(context, 52),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '粘贴 Cookie',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  capRpx(context, 28),
                  capRpx(context, 2),
                  capRpx(context, 28),
                  capRpx(context, 12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(capRpx(context, 16)),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(capRpx(context, 20)),
                        border: Border.all(color: AppColors.line, width: 0.8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: capRpx(context, 54),
                            height: capRpx(context, 54),
                            decoration: BoxDecoration(
                              color: AppColors.mintSoft,
                              borderRadius: BorderRadius.circular(capRpx(context, 16)),
                            ),
                            child: Center(
                              child: CapIcon(
                                'shield-check',
                                size: capRpx(context, 30),
                                color: AppColors.mint,
                              ),
                            ),
                          ),
                          SizedBox(width: capRpx(context, 12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '在下方百度页面登录',
                                  style: TextStyle(
                                    fontSize: capRpx(context, 22),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: capRpx(context, 3)),
                                Text(
                                  '账号、密码与验证码都在百度页面完成；CapuLife 只读取贴吧域名下的 BDUSS / STOKEN 并保存在本机。',
                                  style: TextStyle(
                                    fontSize: capRpx(context, 17),
                                    height: 1.55,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: capRpx(context, 8)),
                    GestureDetector(
                      onTap: () => _probe(),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 14),
                          vertical: capRpx(context, 10),
                        ),
                        decoration: BoxDecoration(
                          color: _verifyError.isEmpty
                              ? AppColors.surface.withValues(alpha: 0.7)
                              : AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(capRpx(context, 16)),
                          border: Border.all(
                            color: _verifyError.isEmpty
                                ? AppColors.line
                                : AppColors.coral.withValues(alpha: 0.28),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            CapIcon(
                              _verifyError.isEmpty ? 'refresh-cw' : 'triangle-alert',
                              size: capRpx(context, 20),
                              color: _verifyError.isEmpty ? AppColors.accent : AppColors.coral,
                            ),
                            SizedBox(width: capRpx(context, 8)),
                            Expanded(
                              child: Text(
                                _verifyError.isEmpty
                                    ? '登录完成后会自动校验；如果没有反应，点这里再试一次'
                                    : _verifyError,
                                style: TextStyle(
                                  fontSize: capRpx(context, 18),
                                  height: 1.45,
                                  color: _verifyError.isEmpty ? AppColors.muted : AppColors.coral,
                                ),
                              ),
                            ),
                            if (_verifyError.isNotEmpty) ...[
                              SizedBox(width: capRpx(context, 8)),
                              Container(
                                height: capRpx(context, 40),
                                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 12)),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.coral,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '重新校验',
                                  style: TextStyle(
                                    fontSize: capRpx(context, 17),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 8)),
                    GestureDetector(
                      onTap: _pasteCookie,
                      child: Container(
                        width: double.infinity,
                        height: capRpx(context, 58),
                        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(capRpx(context, 16)),
                        ),
                        child: Row(
                          children: [
                            CapIcon(
                              'copy',
                              size: capRpx(context, 19),
                              color: AppColors.muted,
                            ),
                            SizedBox(width: capRpx(context, 8)),
                            Expanded(
                              child: Text(
                                '网页登录卡住？改用粘贴 Cookie 登录',
                                style: TextStyle(
                                  fontSize: capRpx(context, 18),
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            CapIcon(
                              'chevron-right',
                              size: capRpx(context, 18),
                              color: AppColors.mutedSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 8)),
                    GestureDetector(
                      onTap: _clearAndReload,
                      child: Container(
                        width: double.infinity,
                        height: capRpx(context, 52),
                        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            CapIcon(
                              'rotate-ccw',
                              size: capRpx(context, 18),
                              color: AppColors.mutedSoft,
                            ),
                            SizedBox(width: capRpx(context, 7)),
                            Expanded(
                              child: Text(
                                '登录态一直异常？清空旧 Cookie 再登录',
                                style: TextStyle(
                                  fontSize: capRpx(context, 18),
                                  color: AppColors.mutedSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: !_ready
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : CapWebView(
                          key: _webKey,
                          url: _loginUrl,
                          userAgent: _client!.device.webUserAgent(),
                          onLoaded: _onLoaded,
                        ),
                ),
              ),
            ],
          ),
          if (_verifying)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x33081221),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 30),
                      vertical: capRpx(context, 22),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60B1422),
                      borderRadius: BorderRadius.circular(capRpx(context, 18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: capRpx(context, 28),
                          height: capRpx(context, 28),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF6F0E2),
                          ),
                        ),
                        SizedBox(width: capRpx(context, 12)),
                        Text(
                          '正在校验账号…',
                          style: TextStyle(
                            fontSize: capRpx(context, 23),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFFBF2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}