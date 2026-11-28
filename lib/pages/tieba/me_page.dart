import 'package:flutter/material.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_models.dart';
import '../../services/tieba/tieba_session.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/pressable.dart';
import 'favorites_page.dart';
import 'login_page.dart';
import 'messages_page.dart';
import 'tieba_web_page.dart';
import 'users_page.dart';

class TiebaMePage extends StatefulWidget {
  const TiebaMePage({super.key});

  @override
  State<TiebaMePage> createState() => _TiebaMePageState();
}

class _TiebaMePageState extends State<TiebaMePage> {
  TiebaClient? _client;
  bool _signingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() => _client = client);
    if (client.loggedIn) {
      await client.refreshProfile();
      if (mounted) setState(() {});
    }
  }

  Future<void> _login() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => const TiebaLoginPage(),
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (_client?.loggedIn == true) {
      await _client?.refreshProfile();
      if (mounted) setState(() {});
    }
  }

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TiebaMessagesPage()),
    );
  }

  void _openUsers(String type) {
    final account = _client?.account;
    if (account == null) {
      _login();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaUsersPage(type: type, uid: account.uid),
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TiebaFavoritesPage()),
    );
  }

  Future<void> _signAll() async {
    final client = _client;
    if (client == null || _signingAll) return;
    if (!client.loggedIn) {
      _login();
      return;
    }
    setState(() => _signingAll = true);
    try {
      await client.healSession();
      final forums = await client.api.followedForums();
      if (forums.isEmpty) {
        if (mounted) {
          showCapToast(context, '没有拿到关注的吧列表，请稍后重试或点“清空重登”');
        }
        return;
      }
      final unsigned = forums.where((forum) {
        final signed = forum['is_sign'] == true || '${forum['is_sign'] ?? 0}' == '1';
        return !signed;
      }).toList();
      if (unsigned.isEmpty) {
        if (mounted) showCapToast(context, '关注的吧今天都签过了');
        return;
      }
      var signed = 0;
      var failed = 0;
      String firstError = '';
      // Sign in small batches: /c/c/forum/sign is the same endpoint the single
      // sign-in button uses, and it is far more reliable than msign for
      // accounts whose batch endpoint returns an empty info list.
      for (var start = 0; start < unsigned.length; start += 3) {
        final batch = unsigned.skip(start).take(3).toList();
        final results = await Future.wait(batch.map((forum) async {
          final id = tiebaFirstInt(forum['forum_id'], forum['id']);
          final name = '${forum['forum_name'] ?? forum['name'] ?? ''}';
          if (name.isEmpty) {
            if (firstError.isEmpty) firstError = '吧信息不完整';
            return false;
          }
          if (id > 0) {
            try {
              await client.api.signForum(forumId: id, forumName: name);
              client.store.markSigned(client.account?.uid ?? '', id);
              return true;
            } catch (error) {
              final message = error is TiebaApiException ? error.message : '$error';
              if (message.contains('已签') ||
                  message.contains('签过') ||
                  message.contains('已经签到')) {
                client.store.markSigned(client.account?.uid ?? '', id);
                return true;
              }
              if (firstError.isEmpty) firstError = message;
            }
          }
          // The official sign endpoint occasionally rejects a stale forum
          // directory entry; the web sign endpoint only needs kw + tbs.
          try {
            await client.api.webSignForum(name);
            client.store.markSigned(client.account?.uid ?? '', id);
            return true;
          } catch (error) {
            final message = error is TiebaApiException ? error.message : '$error';
            if (message.contains('已签') ||
                message.contains('签过') ||
                message.contains('已经签到')) {
              client.store.markSigned(client.account?.uid ?? '', id);
              return true;
            }
            if (firstError.isEmpty) firstError = message;
            return false;
          }
        }));
        signed += results.where((value) => value).length;
        failed += results.where((value) => !value).length;
      }
      if (!mounted) return;
      if (signed > 0) {
        showCapToast(
          context,
          failed > 0
              ? '签到完成：$signed/${unsigned.length} 个吧，$failed 个失败'
              : '签到完成：$signed/${unsigned.length} 个吧',
        );
      } else {
        showCapToast(
          context,
          firstError.isEmpty ? '签到失败，请重试' : '签到失败：$firstError',
        );
      }
    } catch (error) {
      if (mounted) {
        showCapToast(
          context,
          error is TiebaApiException ? error.message : '一键签到失败',
        );
      }
    } finally {
      if (mounted) setState(() => _signingAll = false);
    }
  }

  Future<void> _openProfileWeb() async {
    final account = _client?.account;
    if (account == null) return;
    final url =
        'https://tieba.baidu.com/home/main?un=${Uri.encodeComponent(account.name.isNotEmpty ? account.name : account.displayName)}';
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => TiebaWebPage(
          url: url,
          title: '我的贴吧主页',
          userAgent: _client?.device.webUserAgent('tieba/12.52.1.0') ?? '',
        ),
      ),
    );
  }

  Future<void> _freshLogin() async {
    final client = _client;
    if (client == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '清空旧登录并重登',
          style: TextStyle(
            fontSize: capRpx(context, 29),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '会先清空本机百度 Cookie。如果之前一直提示未登录、签到或回帖失败，用这个入口重新登录一次。',
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空并登录', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await client.logout();
    if (!mounted) return;
    setState(() {});
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => const TiebaLoginPage(),
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (client.loggedIn) {
      await client.refreshProfile();
      if (mounted) setState(() {});
    }
  }

  Future<void> _logout() async {
    final client = _client;
    if (client == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '退出登录',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '将清除本机保存的贴吧 Cookie 与账号信息。',
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await client.logout();
    if (!mounted) return;
    setState(() {});
    showCapToast(context, '已退出登录');
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final account = client?.account;
    return CapPage(
      child: Column(
        children: [
          const CapAppHeader(
            title: '我的贴吧',
            subtitle: '账号、关注与内容',
            back: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                0,
                capRpx(context, 28),
                capRpx(context, 60) + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (client == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (account == null)
                  _loginCard(context)
                else ...[
                  _profileCard(context, account),
                  SizedBox(height: capRpx(context, 14)),
                  Row(
                    children: [
                      Expanded(
                        child: _statCell(
                          context,
                          '关注',
                          tiebaFormatCount(account.concernNum),
                          () => _openUsers('following'),
                        ),
                      ),
                      SizedBox(width: capRpx(context, 12)),
                      Expanded(
                        child: _statCell(
                          context,
                          '粉丝',
                          tiebaFormatCount(account.fansNum),
                          () => _openUsers('fans'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: capRpx(context, 16)),
                  _menuCard(
                    context,
                    [
                      ('users', '我的关注', () => _openUsers('following')),
                      ('heart', '我的粉丝', () => _openUsers('fans')),
                      ('message-circle', '消息与私信', _openMessages),
                      ('external-link', '在贴吧网页打开我的主页', _openProfileWeb),
                    ],
                  ),
                  SizedBox(height: capRpx(context, 14)),
                  _menuCard(
                    context,
                    [
                      ('bookmark', '我的收藏', _openFavorites),
                      ('calendar-plus', _signingAll ? '正在签到…' : '一键全签', _signAll),
                      ('rotate-ccw', '登录态异常？清空重登', _freshLogin),
                    ],
                  ),
                  SizedBox(height: capRpx(context, 18)),
                  Pressable(
                    onTap: _logout,
                    child: Container(
                      height: capRpx(context, 78),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(capRpx(context, 20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CapIcon(
                            'ban',
                            size: capRpx(context, 24),
                            color: AppColors.coral,
                          ),
                          SizedBox(width: capRpx(context, 6)),
                          Text(
                            '退出登录',
                            style: TextStyle(
                              fontSize: capRpx(context, 23),
                              fontWeight: FontWeight.w700,
                              color: AppColors.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: capRpx(context, 16)),
                  Text(
                    '凭据只保存在本机；退出登录会清除百度贴吧 Cookie，不影响学校 WebVPN 的登录状态。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      height: 1.55,
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 30),
        capRpx(context, 48),
        capRpx(context, 30),
        capRpx(context, 44),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 30)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 96),
            height: capRpx(context, 96),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 28)),
            ),
            child: Center(
              child: CapIcon(
                'user',
                size: capRpx(context, 46),
                color: AppColors.accent,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 18)),
          Text(
            '还没有登录百度账号',
            style: TextStyle(
              fontSize: capRpx(context, 28),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            '登录后可以查看消息、关注与粉丝，点赞和回帖也会用到这个账号。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 20),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          GestureDetector(
            onTap: _login,
            child: Container(
              height: capRpx(context, 68),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 26)),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CapIcon(
                    'shield-check',
                    size: capRpx(context, 24),
                    color: Colors.white,
                  ),
                  SizedBox(width: capRpx(context, 6)),
                  Text(
                    '登录百度账号',
                    style: TextStyle(
                      fontSize: capRpx(context, 22),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, TiebaAccount account) {
    final avatar = tiebaAvatarUrl(account.portrait);
    return Container(
      padding: EdgeInsets.all(capRpx(context, 24)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capRpx(context, 32)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF152E4E), Color(0xFF0C192C)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: capRpx(context, 96),
            height: capRpx(context, 96),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatar.isEmpty
                ? Center(
                    child: Text(
                      account.displayName.substring(0, 1),
                      style: TextStyle(
                        fontSize: capRpx(context, 38),
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                : Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const SizedBox(),
                  ),
          ),
          SizedBox(width: capRpx(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: capRpx(context, 30),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: capRpx(context, 4)),
                Text(
                  '${account.name.isEmpty ? '百度贴吧账号' : '@${account.name}'} · UID ${account.uid}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: capRpx(context, 38),
            padding: EdgeInsets.symmetric(horizontal: capRpx(context, 10)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                CapIcon(
                  'badge-check',
                  size: capRpx(context, 18),
                  color: const Color(0xFFF1CF89),
                ),
                SizedBox(width: capRpx(context, 4)),
                Text(
                  '已登录',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF1CF89),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: capRpx(context, 18)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 22)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: capRpx(context, 32),
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 18),
                color: AppColors.mutedSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    List<(String, String, VoidCallback)> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 26)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 1)
            Pressable(
              onTap: items[i].$3,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: capRpx(context, 18),
                  vertical: capRpx(context, 16),
                ),
                decoration: BoxDecoration(
                  border: i < items.length - 1
                      ? const Border(
                          bottom: BorderSide(color: AppColors.line, width: 1),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: capRpx(context, 44),
                      height: capRpx(context, 44),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(capRpx(context, 13)),
                      ),
                      child: Center(
                        child: CapIcon(
                          items[i].$1,
                          size: capRpx(context, 24),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 12)),
                    Expanded(
                      child: Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: capRpx(context, 22),
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    CapIcon(
                      'chevron-right',
                      size: capRpx(context, 22),
                      color: AppColors.mutedSoft,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}