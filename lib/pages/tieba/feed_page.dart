import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_models.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_reveal.dart';
import '../../widgets/cap_skeleton.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/pressable.dart';
import 'compose_sheet.dart';
import 'explore_page.dart';
import 'login_page.dart';
import 'me_page.dart';
import 'messages_page.dart';
import 'search_page.dart';
import 'thread_page.dart';

const tiebaHomeForum = '成都航空职业技术大学';

class TiebaFeedPage extends StatefulWidget {
  const TiebaFeedPage({
    super.key,
    this.external = false,
    this.forumKw = tiebaHomeForum,
  });

  final bool external;
  final String forumKw;

  @override
  State<TiebaFeedPage> createState() => _TiebaFeedPageState();
}

class _TiebaFeedPageState extends State<TiebaFeedPage> {
  final ScrollController _scroll = ScrollController();
  TiebaClient? _client;
  TiebaForum? _forum;
  List<TiebaThread> _threads = [];
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';
  int _pn = 0;
  bool _hasMore = true;
  String _activeTab = 'latest';
  int _sortType = 0;
  int _activeCid = 0;
  List<({int id, String name})> _goodCategories = [];
  bool _followLoading = false;
  bool _signLoading = false;
  bool _signedToday = false;
  bool _gated = false;

  String get _kw => widget.forumKw;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _boot();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() {
      _client = client;
      _signedToday = client.store.signedToday(
        client.account?.uid ?? '',
        _forum?.id ?? 0,
      );
    });
    if (widget.external && !client.loggedIn) {
      setState(() {
        _gated = true;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loginGate();
      });
      return;
    }
    _fetch('initial');
  }

  Future<void> _loginGate() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '需要登录',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '进入「$_kw吧」需要登录百度贴吧账号。',
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('返回', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('去登录', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (go != true) {
      Navigator.of(context).maybePop();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => const TiebaLoginPage(),
      ),
    );
    if (!mounted) return;
    if (_client!.loggedIn) {
      setState(() => _gated = false);
      _fetch('initial');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _fetch('more');
    }
  }

  Map<String, String> get _extraParams => _activeTab == 'good'
      ? {'is_good': '1', 'cid': '$_activeCid'}
      : {'sort_type': '$_sortType'};

  Future<void> _fetch(String mode) async {
    final client = _client;
    if (client == null || _gated) return;
    if (mode == 'more' && (_loading || _loadingMore || !_hasMore)) return;
    setState(() {
      if (mode == 'initial') {
        _loading = true;
        _error = '';
        _threads = [];
        _pn = 0;
        _hasMore = true;
      } else if (mode == 'refresh') {
        _error = '';
      } else {
        _loadingMore = true;
      }
    });
    try {
      final startPn = mode == 'more' ? _pn : 0;
      final json = await client.api.frsPage(
        kw: _kw,
        pn: startPn,
        rn: 30,
        extra: _extraParams,
      );
      if (!mounted) return;
      if (json['forum'] is Map) {
        final forum = mapTiebaForum(json['forum'] as Map);
        if (forum.name.isNotEmpty) {
          setState(() {
            _forum = forum;
            if (forum.goodClassify.isNotEmpty) {
              _goodCategories = forum.goodClassify
                  .where((item) => item.name.isNotEmpty)
                  .toList();
            }
            _signedToday = client.store.signedToday(
              client.account?.uid ?? '',
              forum.id,
            );
          });
        }
      }
      final users = buildTiebaUserMap(
        json['user_list'] is List ? json['user_list'] as List : null,
      );
      final items = (json['thread_list'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => mapTiebaThread(entry, users))
          .whereType<TiebaThread>()
          .where((thread) => thread.tid != 0)
          .toList();
      final page = json['page'] is Map ? json['page'] as Map : const {};
      final hasMore =
          '${page['has_more'] ?? 0}' == '1' && items.isNotEmpty;
      if (mode == 'more') {
        final seen = _threads.map((thread) => thread.tid).toSet();
        _threads = [
          ..._threads,
          ...items.where((thread) => !seen.contains(thread.tid)),
        ];
      } else {
        _threads = items;
      }
      _pn = startPn + 30;
      _hasMore = hasMore;
      _fallbackCategories();
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is TiebaApiException
          ? error.message
          : '贴吧接口请求失败';
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (mode != 'more') _error = message;
      });
      if (mode == 'more') showCapToast(context, message);
    }
  }

  void _fallbackCategories() {
    if (widget.external) return;
    if (_goodCategories.isNotEmpty) return;
    _goodCategories = const [
      (id: 0, name: '全部'),
      (id: 1, name: '吧务活动'),
      (id: 5, name: '吧友原创'),
      (id: 2, name: '学院风采'),
      (id: 3, name: '学习工作'),
      (id: 4, name: '娱乐时间'),
    ];
  }

  Future<bool> _ensureLogin() async {
    final client = _client;
    if (client == null) return false;
    if (client.loggedIn) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '需要登录',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '关注贴吧、签到和发帖需要百度贴吧账号。',
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
            child: const Text('去登录', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return false;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => const TiebaLoginPage(),
      ),
    );
    if (!mounted) return false;
    return client.loggedIn;
  }

  Future<void> _toggleFollow() async {
    final client = _client;
    final forum = _forum;
    if (client == null || forum == null || _followLoading) return;
    if (!await _ensureLogin() || !mounted) return;
    setState(() => _followLoading = true);
    final target = !forum.isLiked;
    try {
      await client.api.toggleForumLike(
        forumId: forum.id,
        forumName: forum.name,
        like: target,
      );
      if (!mounted) return;
      setState(() => forum.isLiked = target);
      showCapToast(context, target ? '已关注${forum.name}吧' : '已取消关注');
    } catch (error) {
      if (mounted) {
        showCapToast(
          context,
          error is TiebaApiException ? error.message : '操作失败',
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _signIn() async {
    final client = _client;
    final forum = _forum;
    if (client == null || forum == null || _signLoading || _signedToday) return;
    if (!await _ensureLogin() || !mounted) return;
    setState(() => _signLoading = true);
    try {
      final result = await client.api.signForum(
        forumId: forum.id,
        forumName: forum.name,
      );
      if (!mounted) return;
      client.store.markSigned(client.account?.uid ?? '', forum.id);
      setState(() => _signedToday = true);
      final cont = tiebaInt(result['contSignNum']);
      showCapToast(context, cont > 0 ? '签到成功，连续 $cont 天' : '签到成功');
    } catch (error) {
      final message = error is TiebaApiException ? error.message : '签到失败';
      if (message.contains('已签') || message.contains('签过') || message.contains('已经签到')) {
        client.store.markSigned(client.account?.uid ?? '', forum.id);
        if (mounted) setState(() => _signedToday = true);
        if (mounted) showCapToast(context, '今天已经签过啦');
      } else if (mounted) {
        showCapToast(context, message);
      }
    } finally {
      if (mounted) setState(() => _signLoading = false);
    }
  }

  Future<void> _compose() async {
    final client = _client;
    final forum = _forum;
    if (client == null || forum == null) {
      showCapToast(context, '贴吧信息还在加载');
      return;
    }
    if (!await _ensureLogin() || !mounted) return;
    final sent = await showTiebaComposeSheet(
      context: context,
      client: client,
      forumName: forum.name,
      forumId: forum.id,
      onSent: () {},
    );
    if (sent == true && mounted) _fetch('initial');
  }

  void _openThread(TiebaThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaThreadDetailPage(
          tid: thread.tid,
          title: thread.title,
          replyCount: thread.replyCount,
          forumName: _forum?.name ?? _kw,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaSearchPage(forumName: _forum?.name ?? _kw),
      ),
    );
  }

  void _openMe() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TiebaMePage()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TiebaMessagesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () async => _fetch(_threads.isEmpty ? 'initial' : 'refresh'),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: widget.external ? 0 : MediaQuery.paddingOf(context).top,
          bottom: widget.external
              ? capRpx(context, 48) + MediaQuery.paddingOf(context).bottom
              : capRpx(context, 230) + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (widget.external)
            CapAppHeader(
              title: '贴吧',
              subtitle: '${_forum?.name ?? _kw}吧',
              back: true,
              right: _actions(context),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                capRpx(context, 10),
                capRpx(context, 20),
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '成航吧',
                          style: TextStyle(
                            fontSize: capRpx(context, 42),
                            fontWeight: FontWeight.w800,
                            letterSpacing: capRpx(context, -1.4),
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: capRpx(context, 2)),
                        Text(
                          '成都航空职业技术大学吧',
                          style: TextStyle(
                            fontSize: capRpx(context, 19),
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _actions(context),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              capRpx(context, 28),
              0,
              capRpx(context, 28),
              0,
            ),
            child: Column(
              children: [
                if (_forum != null) _forumHero(context, _forum!),
                _searchEntry(context),
                if (!widget.external) _discoverEntry(context),
                _toolbar(context),
                if (_activeTab == 'good' && _goodCategories.isNotEmpty)
                  _categories(context),
                ..._feedBody(context),
              ],
            ),
          ),
        ],
      ),
    );
    if (!widget.external) return content;
    return CapPage(child: content);
  }

  Widget _actions(BuildContext context) {
    final avatar = _client?.account?.portrait ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circle(context, 'refresh-cw', () => _fetch(_threads.isEmpty ? 'initial' : 'refresh')),
        SizedBox(width: capRpx(context, 5)),
        _circle(context, 'bell', _openMessages),
        SizedBox(width: capRpx(context, 5)),
        GestureDetector(
          onTap: _openMe,
          child: Container(
            width: capRpx(context, 62),
            height: capRpx(context, 62),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatar.isEmpty
                ? Center(
                    child: CapIcon(
                      'user',
                      size: capRpx(context, 27),
                      color: AppColors.ink,
                    ),
                  )
                : Image.network(
                    tiebaAvatarUrl(avatar),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Center(
                      child: CapIcon(
                        'user',
                        size: capRpx(context, 27),
                        color: AppColors.ink,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _circle(BuildContext context, String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 62),
        height: capRpx(context, 62),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 27), color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _forumHero(BuildContext context, TiebaForum forum) {
    return Container(
      margin: EdgeInsets.only(top: capRpx(context, 6), bottom: capRpx(context, 20)),
      padding: EdgeInsets.all(capRpx(context, 26)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capRpx(context, 34)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF5FFFDF8), Color(0xEBF6F1E7)],
        ),
        border: Border.all(color: AppColors.line, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: capRpx(context, 24),
            offset: Offset(0, capRpx(context, 10)),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: capRpx(context, 92),
                height: capRpx(context, 92),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 26)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                clipBehavior: Clip.antiAlias,
                child: forum.avatar.isEmpty
                    ? Center(
                        child: CapIcon(
                          'message-circle',
                          size: capRpx(context, 44),
                          color: AppColors.accent,
                        ),
                      )
                    : Image.network(
                        forum.avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Center(
                          child: CapIcon(
                            'message-circle',
                            size: capRpx(context, 44),
                            color: AppColors.accent,
                          ),
                        ),
                      ),
              ),
              SizedBox(width: capRpx(context, 18)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${forum.name}吧',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: capRpx(context, 32),
                              fontWeight: FontWeight.w800,
                              letterSpacing: capRpx(context, -0.6),
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (!widget.external) ...[
                          SizedBox(width: capRpx(context, 8)),
                          _tag(context, '校园', AppColors.accent, AppColors.accentSoft, icon: 'graduation-cap'),
                        ],
                      ],
                    ),
                    SizedBox(height: capRpx(context, 5)),
                    Text(
                      forum.slogan.isEmpty ? '${forum.name}吧友聚集地' : forum.slogan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 10)),
              GestureDetector(
                onTap: _followLoading ? null : _toggleFollow,
                child: Opacity(
                  opacity: _followLoading ? 0.6 : 1,
                  child: Container(
                    height: capRpx(context, 54),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        CapIcon(
                          forum.isLiked ? 'check' : 'plus',
                          size: capRpx(context, 18),
                          color: Colors.white,
                        ),
                        SizedBox(width: capRpx(context, 4)),
                        Text(
                          forum.isLiked ? '已关注' : '关注',
                          style: TextStyle(
                            fontSize: capRpx(context, 20),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: capRpx(context, 20)),
            padding: EdgeInsets.only(top: capRpx(context, 18)),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _stat(context, tiebaFormatCount(forum.memberNum), '关注'),
                ),
                Expanded(
                  child: _stat(context, tiebaFormatCount(forum.postNum), '帖子'),
                ),
                GestureDetector(
                  onTap: _signLoading || _signedToday ? null : _signIn,
                  child: Container(
                    height: capRpx(context, 50),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 15)),
                    decoration: BoxDecoration(
                      color: _signedToday ? AppColors.surfaceSoft : AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        CapIcon(
                          _signedToday ? 'check' : 'calendar-plus',
                          size: capRpx(context, 18),
                          color: _signedToday ? AppColors.muted : AppColors.accent,
                        ),
                        SizedBox(width: capRpx(context, 4)),
                        Text(
                          _signedToday ? '已签到' : '签到',
                          style: TextStyle(
                            fontSize: capRpx(context, 19),
                            fontWeight: FontWeight.w700,
                            color: _signedToday ? AppColors.muted : AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: capRpx(context, 31),
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
    );
  }

  Widget _tag(
    BuildContext context,
    String text,
    Color color,
    Color background, {
    String? icon,
  }) {
    return Container(
      height: capRpx(context, 30),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 9)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            CapIcon(icon, size: capRpx(context, 15), color: color),
            SizedBox(width: capRpx(context, 3)),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: capRpx(context, 16),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchEntry(BuildContext context) {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        height: capRpx(context, 68),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 22)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            CapIcon('search', size: capRpx(context, 22), color: AppColors.mutedSoft),
            SizedBox(width: capRpx(context, 8)),
            Expanded(
              child: Text(
                '搜索贴吧、帖子、用户',
                style: TextStyle(
                  fontSize: capRpx(context, 22),
                  color: AppColors.mutedSoft,
                ),
              ),
            ),
            CapIcon(
              'chevron-right',
              size: capRpx(context, 20),
              color: AppColors.mutedSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _discoverEntry(BuildContext context) {
    return Pressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TiebaExplorePage()),
        );
      },
      child: Container(
        margin: EdgeInsets.only(top: capRpx(context, 10)),
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 16),
          vertical: capRpx(context, 12),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EA).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(capRpx(context, 18)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            CapIcon(
              'flame',
              size: capRpx(context, 24),
              color: AppColors.coral,
            ),
            SizedBox(width: capRpx(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '推荐 · 贴吧热榜',
                    style: TextStyle(
                      fontSize: capRpx(context, 24),
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 2)),
                  Text(
                    '全吧热门帖子与实时热议',
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      color: AppColors.muted,
                    ),
                  ),
                ],
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
    );
  }

  Widget _toolbar(BuildContext context) {    return Padding(
      padding: EdgeInsets.only(top: capRpx(context, 14), bottom: capRpx(context, 12)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(capRpx(context, 5)),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                for (final entry in const [('latest', '最新'), ('good', '吧主推荐')]) ...[
                  if (entry.$1 == 'good') SizedBox(width: capRpx(context, 6)),
                  GestureDetector(
                    onTap: () {
                      if (_activeTab == entry.$1) return;
                      setState(() {
                        _activeTab = entry.$1;
                        _activeCid = 0;
                      });
                      _fetch('initial');
                    },
                    child: AnimatedContainer(
                      duration: capsuleMotion,
                      curve: capsuleSpringCurve,
                      height: capRpx(context, 48),
                      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeTab == entry.$1 ? AppColors.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.$2,
                        style: TextStyle(
                          fontSize: capRpx(context, 22),
                          fontWeight: _activeTab == entry.$1 ? FontWeight.w700 : FontWeight.w600,
                          color: _activeTab == entry.$1 ? const Color(0xFFFFF8EA) : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (_activeTab == 'latest')
            GestureDetector(
              onTap: () {
                setState(() => _sortType = _sortType == 0 ? 1 : 0);
                _fetch('initial');
              },
              child: Container(
                height: capRpx(context, 48),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 12)),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line, width: 0.8),
                ),
                child: Row(
                  children: [
                    CapIcon(
                      'chevron-down',
                      size: capRpx(context, 18),
                      color: AppColors.muted,
                    ),
                    SizedBox(width: capRpx(context, 2)),
                    Text(
                      _sortType == 0 ? '按回复' : '按发布',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(width: capRpx(context, 8)),
          GestureDetector(
            onTap: _compose,
            child: Container(
              height: capRpx(context, 48),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.22),
                    blurRadius: capRpx(context, 14),
                    offset: Offset(0, capRpx(context, 6)),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CapIcon('pencil', size: capRpx(context, 18), color: Colors.white),
                  SizedBox(width: capRpx(context, 4)),
                  Text(
                    '发帖',
                    style: TextStyle(
                      fontSize: capRpx(context, 21),
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

  Widget _categories(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(bottom: capRpx(context, 12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in _goodCategories) ...[
            GestureDetector(
              onTap: () {
                if (_activeCid == item.id) return;
                setState(() => _activeCid = item.id);
                _fetch('initial');
              },
              child: Container(
                height: capRpx(context, 46),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
                margin: EdgeInsets.only(right: capRpx(context, 8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeCid == item.id ? AppColors.accentSoft : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _activeCid == item.id
                        ? AppColors.accent.withValues(alpha: 0.24)
                        : AppColors.line,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: capRpx(context, 20),
                    fontWeight: _activeCid == item.id ? FontWeight.w700 : FontWeight.w400,
                    color: _activeCid == item.id ? AppColors.accent : AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _feedBody(BuildContext context) {
    if (_gated) {
      return [
        _stateCard(
          context,
          icon: 'shield-check',
          title: '登录后查看$_kw吧',
          desc: '百度贴吧账号登录后即可进入这个吧。',
          actions: [
            _stateButton(context, '去登录', primary: true, onTap: _loginGate),
          ],
        ),
      ];
    }
    if (_loading && _threads.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(
            top: capRpx(context, 10),
            bottom: capRpx(context, 30),
          ),
          child: const CapThreadSkeletonList(count: 3),
        ),
      ];
    }
    if (_error.isNotEmpty && _threads.isEmpty) {
      return [
        _stateCard(
          context,
          icon: 'wifi-off',
          danger: true,
          title: '没能连上贴吧',
          desc: _error,
          actions: [
            _stateButton(context, '重试', primary: true, onTap: () => _fetch('initial')),
          ],
        ),
      ];
    }
    if (_threads.isEmpty) {
      return [
        _stateCard(
          context,
          icon: 'message-circle',
          title: '这个分区暂时没有帖子',
          desc: '可以切到「最新」或「吧主推荐」看看，或者刷新试试。',
          actions: [
            _stateButton(context, '刷新', primary: true, onTap: () => _fetch('initial')),
          ],
        ),
      ];
    }
    return [
      SizedBox(height: capRpx(context, 4)),
      for (var i = 0; i < _threads.length; i += 1) ...[
        if (i > 0) SizedBox(height: capRpx(context, 18)),
        CapReveal(
          index: i,
          child: _threadCard(context, _threads[i]),
        ),
      ],
      if (_loadingMore)
        Padding(
          padding: EdgeInsets.symmetric(vertical: capRpx(context, 24)),
          child: Center(
            child: Text(
              '正在加载更多…',
              style: TextStyle(
                fontSize: capRpx(context, 19),
                color: AppColors.mutedSoft,
              ),
            ),
          ),
        )
      else if (!_hasMore)
        Padding(
          padding: EdgeInsets.symmetric(vertical: capRpx(context, 24)),
          child: Center(
            child: Text(
              '已经到底了',
              style: TextStyle(
                fontSize: capRpx(context, 19),
                color: AppColors.mutedSoft,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _threadCard(BuildContext context, TiebaThread thread) {
    return Pressable(
      onTap: () => _openThread(thread),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 22)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 30)),
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: capRpx(context, 20),
              offset: Offset(0, capRpx(context, 8)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(context, thread.author),
                SizedBox(width: capRpx(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 22),
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink2,
                        ),
                      ),
                      Text(
                        '${thread.lastTime} · 最后回复',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: AppColors.mutedSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: capRpx(context, 36),
                  padding: EdgeInsets.symmetric(horizontal: capRpx(context, 10)),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      CapIcon(
                        'message-circle',
                        size: capRpx(context, 17),
                        color: AppColors.muted,
                      ),
                      SizedBox(width: capRpx(context, 3)),
                      Text(
                        '${thread.replyCount}',
                        style: TextStyle(
                          fontSize: capRpx(context, 18),
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 14)),
            Wrap(
              spacing: capRpx(context, 6),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (thread.isTop)
                  _badge(context, '置顶', AppColors.accentSoft, AppColors.accent),
                if (thread.isGood)
                  _badge(context, '精', AppColors.goldSoft, AppColors.gold),
                Text(
                  thread.title,
                  style: TextStyle(
                    fontSize: capRpx(context, 28),
                    fontWeight: FontWeight.w700,
                    height: 1.42,
                    letterSpacing: capRpx(context, -0.3),
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            if (thread.preview.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 8)),
              Text(
                thread.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 22),
                  height: 1.6,
                  color: AppColors.muted,
                ),
              ),
            ],
            if (thread.images.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 14)),
              Row(
                children: [
                  for (var i = 0; i < math_min(3, thread.images.length); i += 1) ...[
                    if (i > 0) SizedBox(width: capRpx(context, 8)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openThread(thread),
                        child: Container(
                          height: thread.images.length == 1
                              ? capRpx(context, 190)
                              : capRpx(context, 150),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(capRpx(context, 16)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                thread.images[i].thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => const SizedBox(),
                              ),
                              if (i == 2 && thread.images.length > 3)
                                ColoredBox(
                                  color: const Color(0x7A0D1A2E),
                                  child: Center(
                                    child: Text(
                                      '+${thread.images.length - 3}',
                                      style: TextStyle(
                                        fontSize: capRpx(context, 30),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            SizedBox(height: capRpx(context, 14)),
            Container(
              padding: EdgeInsets.only(top: capRpx(context, 10)),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: Row(
                children: [
                  _foot(context, 'message-square', '${thread.replyCount}'),
                  SizedBox(width: capRpx(context, 16)),
                  _foot(context, 'eye', tiebaFormatCount(thread.viewCount)),
                  SizedBox(width: capRpx(context, 16)),
                  _foot(context, 'heart', tiebaFormatCount(thread.agreeCount)),
                  const Spacer(),
                  CapIcon(
                    'chevron-right',
                    size: capRpx(context, 20),
                    color: AppColors.mutedSoft,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, TiebaUser user) {
    if (user.avatar.isEmpty) {
      return Container(
        width: capRpx(context, 46),
        height: capRpx(context, 46),
        decoration: const BoxDecoration(
          color: AppColors.accentSoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          user.name.isEmpty ? '吧' : user.name.substring(0, 1),
          style: TextStyle(
            fontSize: capRpx(context, 21),
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return Container(
      width: capRpx(context, 46),
      height: capRpx(context, 46),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        user.avatar,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const SizedBox(),
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color background, Color color) {
    return Container(
      height: capRpx(context, 32),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 9)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(capRpx(context, 8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 17),
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _foot(BuildContext context, String icon, String value) {
    return Row(
      children: [
        CapIcon(icon, size: capRpx(context, 18), color: AppColors.mutedSoft),
        SizedBox(width: capRpx(context, 4)),
        Text(
          value,
          style: TextStyle(
            fontSize: capRpx(context, 18),
            color: AppColors.mutedSoft,
          ),
        ),
      ],
    );
  }

  Widget _stateCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String desc,
    bool danger = false,
    List<Widget> actions = const [],
  }) {
    return Container(
      margin: EdgeInsets.only(top: capRpx(context, 24)),
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 34),
        capRpx(context, 50),
        capRpx(context, 34),
        capRpx(context, 46),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 32)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 96),
            height: capRpx(context, 96),
            decoration: BoxDecoration(
              color: danger ? AppColors.coralSoft : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 28)),
            ),
            child: Center(
              child: CapIcon(
                icon,
                size: capRpx(context, 48),
                color: danger ? AppColors.coral : AppColors.accent,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 16)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 28),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 21),
              height: 1.65,
              color: AppColors.muted,
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 18)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < actions.length; i += 1) ...[
                  if (i > 0) SizedBox(width: capRpx(context, 10)),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stateButton(
    BuildContext context,
    String text, {
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 62),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 24)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: primary ? null : Border.all(color: AppColors.line, width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: capRpx(context, 21),
            fontWeight: FontWeight.w700,
            color: primary ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

int math_min(int a, int b) => a < b ? a : b;