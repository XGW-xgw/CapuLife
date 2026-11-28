import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_emoticons.dart';
import '../../services/tieba/tieba_models.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/pressable.dart';
import 'compose_sheet.dart';
import 'feed_page.dart';
import 'login_page.dart';
import 'tieba_web_page.dart';

class TiebaThreadDetailPage extends StatefulWidget {
  const TiebaThreadDetailPage({
    super.key,
    required this.tid,
    this.title = '',
    this.replyCount = 0,
    this.forumName = '成都航空职业技术大学',
  });

  final int tid;
  final String title;
  final int replyCount;
  final String forumName;

  @override
  State<TiebaThreadDetailPage> createState() => _TiebaThreadPageState();
}

class _TiebaThreadPageState extends State<TiebaThreadDetailPage> {
  final ScrollController _scroll = ScrollController();
  TiebaClient? _client;
  TiebaForum? _forum;
  late String _title = widget.title;
  late String _forumName = widget.forumName;
  late int _replyCount = widget.replyCount;
  TiebaPost? _firstPost;
  List<TiebaPost> _replies = [];
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';
  int _page = 1;
  int _totalPage = 1;
  bool _collected = false;
  bool _collecting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() => _client = client);
    _fetch('initial');
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 320) {
      _fetch('more');
    }
  }

  Future<void> _fetch(String mode) async {
    final client = _client;
    if (client == null || widget.tid == 0) return;
    if (mode == 'more' && (_loading || _loadingMore || _page >= _totalPage)) {
      return;
    }
    setState(() {
      if (mode == 'initial') {
        _loading = true;
        _error = '';
        _firstPost = null;
        _replies = [];
      } else if (mode == 'more') {
        _loadingMore = true;
      }
    });
    try {
      final pn = mode == 'more' ? _page + 1 : 1;
      final json = await client.api.pbPage(tid: widget.tid, pn: pn, rn: 15);
      if (!mounted) return;
      if (json['anti'] is Map) {
        client.absorbTbs('${(json['anti'] as Map)['tbs'] ?? ''}');
      }
      final mapped = mapTiebaThreadPage(json);
      final page = json['page'] is Map ? json['page'] as Map : const {};
      _page = tiebaInt(page['current_page']) != 0
          ? tiebaInt(page['current_page'])
          : pn;
      _totalPage = tiebaInt(page['total_page']) != 0
          ? tiebaInt(page['total_page'])
          : 1;
      if (mapped.forum.name.isNotEmpty) _forumName = mapped.forum.name;
      if (mapped.threadTitle.isNotEmpty) _title = mapped.threadTitle;
      if (mode == 'more') {
        final seen = _replies.map((post) => post.id).toSet();
        _replies = [
          ..._replies,
          ...mapped.replies.where((post) => !seen.contains(post.id)),
        ];
      } else {
        _firstPost = mapped.firstPost;
        _forum = mapped.forum;
        _replies = mapped.replies;
        _collected = mapped.collectStatus != 0;
        _replyCount = _replyCount > 0
            ? _replyCount
            : (mapped.posts.length - 1).clamp(0, 1 << 30);
        _autoLoadSubs();
      }
      if (mode == 'more') _autoLoadSubs();
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is TiebaApiException
          ? error.message
          : '帖子加载失败';
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (mode != 'more') _error = message;
      });
      if (mode == 'more') showCapToast(context, message);
    }
  }

  void _autoLoadSubs() {
    final posts = <TiebaPost>[
      if (_firstPost != null && _firstPost!.subPostNumber > 0) _firstPost!,
      ..._replies.where((post) => post.subPostNumber > 0),
    ];
    for (final post in posts.take(4)) {
      _loadSubs(post);
    }
  }

  Future<void> _loadSubs(TiebaPost post, {bool more = false, bool expand = false}) async {
    final client = _client;
    if (client == null || post.subsLoading || post.subsMoreLoading) return;
    if (!more && post.subsLoaded) return;
    if (more) {
      post.subsMoreLoading = true;
    } else {
      post.subsLoading = true;
    }
    setState(() {});
    final page = more ? post.subsPage + 1 : 1;
    try {
      final json = await client.api.pbFloor(
        tid: widget.tid,
        pid: post.id,
        pn: page,
        rn: 20,
      );
      if (!mounted) return;
      final users = buildTiebaUserMap(
        json['user_list'] is List ? json['user_list'] as List : null,
      );
      final mapped = (json['subpost_list'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => mapTiebaSubPost(entry, users))
          .whereType<TiebaSubPost>()
          .toList();
      if (more) {
        final seen = post.subPosts.map((entry) => entry.id).toSet();
        post.subPosts = [
          ...post.subPosts,
          ...mapped.where((entry) => !seen.contains(entry.id)),
        ];
        post.subsPage = page;
      } else {
        post.subPosts = mapped;
        post.subsPage = 1;
      }
      post.subsLoaded = true;
      if (expand || more) post.subsExpanded = true;
    } catch (_) {
      if (mounted) showCapToast(context, more ? '更多评论加载失败' : '楼中楼加载失败');
    } finally {
      post.subsLoading = false;
      post.subsMoreLoading = false;
      if (mounted) setState(() {});
    }
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
          '点赞、收藏和回复需要百度贴吧账号。',
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

  Future<void> _toggleCollect() async {
    final client = _client;
    if (client == null || _collecting) return;
    if (!await _ensureLogin() || !mounted) return;
    _collecting = true;
    final target = !_collected;
    try {
      if (target) {
        await client.api.addThreadStore(threadId: widget.tid);
      } else {
        await client.api.removeThreadStore(
          threadId: widget.tid,
          forumId: _forum?.id ?? 0,
        );
      }
      if (!mounted) return;
      setState(() => _collected = target);
      showCapToast(context, target ? '已收藏' : '已取消收藏');
    } catch (error) {
      if (mounted) {
        showCapToast(
          context,
          error is TiebaApiException ? error.message : '操作失败',
        );
      }
    } finally {
      _collecting = false;
    }
  }

  Future<void> _toggleAgree(TiebaPost post) async {
    final client = _client;
    if (client == null || !await _ensureLogin() || !mounted) return;
    final target = !post.hasAgreed;
    final previous = post.agreeCount;
    setState(() {
      post.hasAgreed = target;
      post.agreeCount = (post.agreeCount + (target ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      await client.api.opAgree(
        threadId: widget.tid,
        postId: post.id,
        opType: target ? 0 : 1,
        objType: post.floor == 1 ? 3 : 1,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        post.hasAgreed = !target;
        post.agreeCount = previous;
      });
      showCapToast(
        context,
        error is TiebaApiException ? error.message : '点赞失败',
      );
    }
  }

  Future<void> _reply() async {
    final client = _client;
    if (client == null || !await _ensureLogin() || !mounted) return;
    final sent = await showTiebaComposeSheet(
      context: context,
      client: client,
      forumName: _forumName,
      forumId: _forum?.id ?? 0,
      reply: true,
      threadId: widget.tid,
      threadTitle: _title,
      onSent: () {},
    );
    if (sent == true && mounted) _fetch('initial');
  }

  Future<void> _replySub(TiebaPost parent, TiebaSubPost sub) async {
    final client = _client;
    if (client == null || !await _ensureLogin() || !mounted) return;
    final sent = await showTiebaComposeSheet(
      context: context,
      client: client,
      forumName: _forumName,
      forumId: _forum?.id ?? 0,
      reply: true,
      threadId: widget.tid,
      threadTitle: _title,
      quotePostId: parent.id,
      subPostId: sub.id,
      replyUid: sub.author.id,
      replyPrefix: '回复 ${sub.author.name} :',
      replyUserName: sub.author.name,
      onSent: () {},
    );
    if (sent == true && mounted) _fetch('initial');
  }

  Future<void> _replyPost(TiebaPost post) async {
    final client = _client;
    if (client == null || !await _ensureLogin() || !mounted) return;
    final sent = await showTiebaComposeSheet(
      context: context,
      client: client,
      forumName: _forumName,
      forumId: _forum?.id ?? 0,
      reply: true,
      threadId: widget.tid,
      threadTitle: _title,
      quotePostId: post.id,
      replyUid: post.author.id,
      replyUserName: post.author.name,
      onSent: () {},
    );
    if (sent == true && mounted) _fetch('initial');
  }

  Future<void> _toggleSubAgree(TiebaSubPost sub) async {
    final client = _client;
    if (client == null || !await _ensureLogin() || !mounted) return;
    final target = !sub.hasAgreed;
    final previous = sub.agreeCount;
    setState(() {
      sub.hasAgreed = target;
      sub.agreeCount = (sub.agreeCount + (target ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      await client.api.opAgree(
        threadId: widget.tid,
        postId: sub.id,
        opType: target ? 0 : 1,
        objType: 2,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        sub.hasAgreed = !target;
        sub.agreeCount = previous;
      });
      showCapToast(
        context,
        error is TiebaApiException ? error.message : '点赞失败',
      );
    }
  }

  void _copyLink() {
    Clipboard.setData(
      ClipboardData(text: 'https://tieba.baidu.com/p/${widget.tid}'),
    );
    showCapToast(context, '链接已复制');
  }

  void _previewImages(List<TiebaImage> images, int index) {
    if (images.isEmpty) return;
    final urls = images.map((image) => image.big.isEmpty ? image.url : image.big).toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(capRpx(context, 20)),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: urls.length,
            itemBuilder: (context, page) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  urls[page],
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: _title.isEmpty ? '帖子详情' : _title,
            subtitle: '$_forumName吧',
            back: true,
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _headIcon('refresh-cw', () => _fetch('initial')),
                SizedBox(width: capRpx(context, 4)),
                _headIcon('bookmark', _toggleCollect, active: _collected),
                SizedBox(width: capRpx(context, 4)),
                _headIcon('external-link', () {
                  Clipboard.setData(
                    ClipboardData(text: 'https://tieba.baidu.com/p/${widget.tid}'),
                  );
                  showCapToast(context, '链接已复制，可在浏览器打开');
                }),
              ],
            ),
          ),
          if (_forumName.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TiebaFeedPage(
                      external: true,
                      forumKw: _forumName,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  capRpx(context, 28),
                  0,
                  capRpx(context, 28),
                  capRpx(context, 10),
                ),
                child: Row(
                  children: [
                    CapIcon(
                      'message-square',
                      size: capRpx(context, 18),
                      color: AppColors.muted,
                    ),
                    SizedBox(width: capRpx(context, 5)),
                    Text(
                      '进入 $_forumName吧',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    CapIcon(
                      'chevron-right',
                      size: capRpx(context, 18),
                      color: AppColors.mutedSoft,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _body(context)),
          _actionBar(context),
        ],
      ),
    );
  }

  Widget _headIcon(String icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 58),
        height: capRpx(context, 58),
        decoration: BoxDecoration(
          color: active ? AppColors.accentSoft : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? AppColors.accent.withValues(alpha: 0.25) : AppColors.line,
            width: 0.8,
          ),
        ),
        child: Center(
          child: CapIcon(
            icon,
            size: capRpx(context, 27),
            color: active ? AppColors.accent : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _firstPost == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error.isNotEmpty && _firstPost == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(capRpx(context, 30)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CapIcon('wifi-off', size: capRpx(context, 46), color: AppColors.coral),
              SizedBox(height: capRpx(context, 14)),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: capRpx(context, 22),
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
              SizedBox(height: capRpx(context, 18)),
              GestureDetector(
                onTap: () => _fetch('initial'),
                child: Container(
                  height: capRpx(context, 62),
                  padding: EdgeInsets.symmetric(horizontal: capRpx(context, 22)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '重试',
                    style: TextStyle(
                      fontSize: capRpx(context, 21),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_firstPost == null && _replies.isEmpty) {
      return Center(
        child: Text(
          '帖子内容不存在',
          style: TextStyle(fontSize: capRpx(context, 22), color: AppColors.muted),
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 4),
        capRpx(context, 28),
        capRpx(context, 30),
      ),
      children: [
        if (_firstPost != null) _postCard(context, _firstPost!, first: true),
        for (final post in _replies) _postCard(context, post),
        if (_loadingMore)
          Padding(
            padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
            child: Center(
              child: Text(
                '正在加载更多楼层…',
                style: TextStyle(
                  fontSize: capRpx(context, 19),
                  color: AppColors.mutedSoft,
                ),
              ),
            ),
          )
        else if (_page >= _totalPage && _replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
            child: Center(
              child: Text(
                '没有更多回复了',
                style: TextStyle(
                  fontSize: capRpx(context, 19),
                  color: AppColors.mutedSoft,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _postCard(BuildContext context, TiebaPost post, {bool first = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: capRpx(context, 18)),
      padding: EdgeInsets.all(capRpx(context, 24)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 30)),
        border: Border.all(color: AppColors.line, width: 0.8),
        gradient: first
            ? const RadialGradient(
                center: Alignment(0.9, -1),
                radius: 1.2,
                colors: [Color(0x0F1646B8), Color(0x00FFFFFF)],
              )
            : null,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(context, post.author),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: capRpx(context, 6),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          post.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: capRpx(context, 25),
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (post.author.bawuText.isNotEmpty)
                          _tag(context, post.author.bawuText, AppColors.gold, AppColors.goldSoft),
                        if (post.author.levelName.isNotEmpty)
                          _tag(context, post.author.levelName, AppColors.muted, AppColors.surfaceSoft),
                        if (post.author.level > 0)
                          Text(
                            'Lv.${post.author.level}',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: capRpx(context, 17),
                              color: AppColors.mutedSoft,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: capRpx(context, 3)),
                    Text(
                      '${tiebaFormatTime(post.time)}${post.author.ip.isEmpty ? '' : ' · ${post.author.ip}'}',
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                first ? '楼主' : (post.floor > 0 ? '第${post.floor}楼' : ''),
                style: TextStyle(
                  fontSize: capRpx(context, 17),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
          if (first && post.title.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 16)),
            Text(
              post.title,
              style: TextStyle(
                fontSize: capRpx(context, 32),
                fontWeight: FontWeight.w800,
                height: 1.35,
                letterSpacing: capRpx(context, -0.6),
                color: AppColors.ink,
              ),
            ),
          ],
          if (post.blocks.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 12)),
            ..._content(context, post.blocks),
          ],
          if (post.subPostNumber > 0) ...[
            SizedBox(height: capRpx(context, 12)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 12),
                vertical: capRpx(context, 10),
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.subsLoading)
                    Text(
                      '正在加载楼中楼…',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        color: AppColors.muted,
                      ),
                    )
                  else if (!post.subsLoaded)
                    GestureDetector(
                      onTap: () => _loadSubs(post),
                      child: Text(
                        '查看 ${post.subPostNumber} 条楼中楼',
                        style: TextStyle(
                          fontSize: capRpx(context, 18),
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  else ...[
                    for (var i = 0;
                        i < (post.subsExpanded
                            ? post.subPosts.length
                            : math.min(5, post.subPosts.length));
                        i += 1) ...[
                      if (i > 0) SizedBox(height: capRpx(context, 8)),
                      _subPost(context, post, post.subPosts[i]),
                    ],
                    if (post.subPosts.length > 5 ||
                        post.subPostNumber > post.subPosts.length) ...[
                      SizedBox(height: capRpx(context, 10)),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (!post.subsExpanded) {
                                setState(() => post.subsExpanded = true);
                                if (post.subPosts.length <
                                    math.min(5, post.subPostNumber)) {
                                  _loadSubs(post, more: true);
                                }
                              } else if (post.subPosts.length <
                                  post.subPostNumber) {
                                _loadSubs(post, more: true);
                              } else {
                                setState(() => post.subsExpanded = false);
                              }
                            },
                            child: Container(
                              height: capRpx(context, 44),
                              padding: EdgeInsets.symmetric(
                                horizontal: capRpx(context, 14),
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    !post.subsExpanded
                                        ? '更多评论（${post.subPostNumber}）'
                                        : post.subPosts.length < post.subPostNumber
                                            ? (post.subsMoreLoading
                                                ? '正在加载…'
                                                : '加载更多评论')
                                            : '收起评论',
                                    style: TextStyle(
                                      fontSize: capRpx(context, 18),
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  SizedBox(width: capRpx(context, 4)),
                                  CapIcon(
                                    post.subsExpanded &&
                                            post.subPosts.length >= post.subPostNumber
                                        ? 'chevron-up'
                                        : 'chevron-down',
                                    size: capRpx(context, 16),
                                    color: AppColors.accent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (post.subsExpanded &&
                              post.subPosts.length < post.subPostNumber) ...[
                            const Spacer(),
                            Text(
                              '${post.subPosts.length}/${post.subPostNumber}',
                              style: TextStyle(
                                fontSize: capRpx(context, 16),
                                color: AppColors.mutedSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: capRpx(context, 12)),
          Container(
            padding: EdgeInsets.only(top: capRpx(context, 10)),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  tiebaFormatFullTime(post.time),
                  style: TextStyle(
                    fontSize: capRpx(context, 16),
                    color: AppColors.mutedSoft,
                  ),
                ),
                const Spacer(),
                _postAction(
                  context,
                  icon: 'heart',
                  label: '${post.agreeCount}',
                  active: post.hasAgreed,
                  onTap: () => _toggleAgree(post),
                ),
                SizedBox(width: capRpx(context, 8)),
                _postAction(
                  context,
                  icon: 'message-square',
                  label: '回复',
                  onTap: () => _replyPost(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postAction(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool compact = false,
  }) {
    final height = compact ? 44.0 : 56.0;
    final iconSize = compact ? 18.0 : 24.0;
    final fontSize = compact ? 16.0 : 18.0;
    final color = active ? AppColors.coral : AppColors.muted;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: capsuleMotionFast,
        curve: capsuleSpringCurve,
        height: capRpx(context, height),
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, compact ? 10 : 14),
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.coralSoft : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.coral.withValues(alpha: 0.28)
                : AppColors.line,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CapIcon(
              icon,
              size: capRpx(context, iconSize),
              color: color,
            ),
            SizedBox(width: capRpx(context, 5)),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, fontSize),
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subPost(BuildContext context, TiebaPost parent, TiebaSubPost sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _replySub(parent, sub),
          child: _TiebaRichText(
            inlines: sub.inlines,
            leading: '${sub.author.name}: ',
            leadingColor: AppColors.accent,
            fontSize: capRpx(context, 20),
            lineHeight: 1.6,
            color: AppColors.ink,
          ),
        ),
        if (sub.images.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: capRpx(context, 6)),
            child: Row(
              children: [
                for (final image in sub.images.take(3))
                  GestureDetector(
                    onTap: () => _previewImages(sub.images, sub.images.indexOf(image)),
                    child: Container(
                      width: capRpx(context, 72),
                      height: capRpx(context, 72),
                      margin: EdgeInsets.only(right: capRpx(context, 6)),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(capRpx(context, 8)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        image.thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const SizedBox(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              tiebaFormatTime(sub.time),
              style: TextStyle(
                fontSize: capRpx(context, 16),
                color: AppColors.mutedSoft,
              ),
            ),
            const Spacer(),
            _postAction(
              context,
              icon: 'heart',
              label: '${sub.agreeCount}',
              active: sub.hasAgreed,
              compact: true,
              onTap: () => _toggleSubAgree(sub),
            ),
            SizedBox(width: capRpx(context, 6)),
            _postAction(
              context,
              icon: 'message-square',
              label: '回复',
              compact: true,
              onTap: () => _replySub(parent, sub),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, List<TiebaContentBlock> blocks) {
    final widgets = <Widget>[];
    for (final block in blocks) {
      if (block.inlines.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: capRpx(context, 8)),
            child: _TiebaRichText(
              inlines: block.inlines,
              fontSize: capRpx(context, 24),
              lineHeight: 1.65,
              color: AppColors.ink,
            ),
          ),
        );
      }
      if (block.videos.isNotEmpty) {
        for (final video in block.videos) {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: capRpx(context, 10)),
              child: _videoCard(context, video),
            ),
          );
        }
      }
      if (block.images.isNotEmpty) {
        final images = block.images;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: capRpx(context, 8)),
            child: Wrap(
              spacing: capRpx(context, 8),
              runSpacing: capRpx(context, 8),
              children: [
                for (var i = 0; i < images.take(9).length; i += 1)
                  GestureDetector(
                    onTap: () => _previewImages(images, i),
                    child: Container(
                      width: images.length == 1
                          ? capRpx(context, 420)
                          : capRpx(context, 194),
                      height: images.length == 1
                          ? capRpx(context, 280)
                          : capRpx(context, 194),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(capRpx(context, 14)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        images[i].url,
                        fit: images.length == 1 ? BoxFit.cover : BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.mutedSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }
    return widgets;
  }

  void _openWebPage(String url, {String title = '贴吧网页'}) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => TiebaWebPage(
          url: url,
          title: title,
          userAgent: _client?.device.webUserAgent('tieba/12.52.1.0') ?? '',
        ),
      ),
    );
  }

  Widget _videoCard(BuildContext context, TiebaVideo video) {
    final duration = video.duration;
    final durationText = duration > 0
        ? '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}'
        : '';
    return GestureDetector(
      onTap: () {
        final target = video.pageUrl.isNotEmpty ? video.pageUrl : video.playUrl;
        _openWebPage(target, title: '视频');
      },
      child: Container(
        width: double.infinity,
        height: capRpx(context, 360),
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(capRpx(context, 18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.cover.isNotEmpty)
              Image.network(
                video.cover,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x14000000), Color(0x99000000)],
                ),
              ),
            ),
            Center(
              child: Container(
                width: capRpx(context, 92),
                height: capRpx(context, 92),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                ),
                child: Center(
                  child: CapIcon(
                    'play',
                    size: capRpx(context, 42),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              left: capRpx(context, 14),
              bottom: capRpx(context, 12),
              child: Row(
                children: [
                  Container(
                    height: capRpx(context, 32),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 9)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(capRpx(context, 8)),
                    ),
                    child: Text(
                      '视频',
                      style: TextStyle(
                        fontSize: capRpx(context, 16),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (durationText.isNotEmpty) ...[
                    SizedBox(width: capRpx(context, 6)),
                    Container(
                      height: capRpx(context, 32),
                      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 8)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(capRpx(context, 8)),
                      ),
                      child: Text(
                        durationText,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: capRpx(context, 16),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
        width: capRpx(context, 52),
        height: capRpx(context, 52),
        decoration: const BoxDecoration(
          color: AppColors.accentSoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          user.name.isEmpty ? '吧' : user.name.substring(0, 1),
          style: TextStyle(
            fontSize: capRpx(context, 24),
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return Container(
      width: capRpx(context, 52),
      height: capRpx(context, 52),
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

  Widget _tag(BuildContext context, String text, Color color, Color background) {
    return Container(
      height: capRpx(context, 28),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 8)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(capRpx(context, 7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 16),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 10),
        capRpx(context, 28),
        capRpx(context, 12) + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _copyLink,
              child: Container(
                height: capRpx(context, 78),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                  border: Border.all(color: AppColors.line, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      'copy',
                      size: capRpx(context, 24),
                      color: AppColors.ink,
                    ),
                    SizedBox(width: capRpx(context, 6)),
                    Text(
                      '复制链接',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: capRpx(context, 12)),
          Expanded(
            child: GestureDetector(
              onTap: _reply,
              child: Container(
                height: capRpx(context, 78),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      'pencil',
                      size: capRpx(context, 24),
                      color: Colors.white,
                    ),
                    SizedBox(width: capRpx(context, 6)),
                    Text(
                      '回复',
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
          ),
        ],
      ),
    );
  }
}
/// Rich text that turns http(s) URLs (from link nodes or raw text) into
/// tappable browser links while keeping Tieba's inline emoji images.
class _TiebaRichText extends StatefulWidget {
  const _TiebaRichText({
    required this.inlines,
    required this.fontSize,
    required this.lineHeight,
    required this.color,
    this.leading = '',
    this.leadingColor,
  });

  final List<TiebaInline> inlines;
  final double fontSize;
  final double lineHeight;
  final Color color;
  final String leading;
  final Color? leadingColor;

  @override
  State<_TiebaRichText> createState() => _TiebaRichTextState();
}

class _TiebaRichTextState extends State<_TiebaRichText> {
  static final RegExp _urlPattern = RegExp(r'https?://[^\s<>"'']+');
  static final RegExp _emoticonPattern =
      RegExp(r'#\(([^()]{1,16})\)|\[([^\[\]]{1,16})\]');
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TiebaRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _disposeRecognizers();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    if (widget.leading.isNotEmpty) {
      spans.add(TextSpan(
        text: widget.leading,
        style: TextStyle(
          color: widget.leadingColor ?? widget.color,
          fontWeight: FontWeight.w600,
        ),
      ));
    }
    for (final inline in widget.inlines) {
      if (inline.emoji.isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 1)),
              child: Image.network(
                inline.emoji,
                width: widget.fontSize * 1.15,
                height: widget.fontSize * 1.15,
                errorBuilder: (context, error, stack) => const SizedBox(),
              ),
            ),
          ),
        );
        continue;
      }
      _addTextSpan(spans, inline.text, widget.fontSize, inline.accent, inline.link);
    }
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: widget.fontSize,
        height: widget.lineHeight,
        color: widget.color,
      ),
    );
  }

  void _addTextSpan(
    List<InlineSpan> spans,
    String text,
    double fontSize,
    bool accent,
    String explicitLink,
  ) {
    if (text.isEmpty) return;
    var cursor = 0;
    for (final match in _emoticonPattern.allMatches(text)) {
      if (match.start > cursor) {
        _addPlainWithLinks(
          spans,
          text.substring(cursor, match.start),
          fontSize,
          accent,
          explicitLink,
        );
      }
      final name = match.group(1) ?? match.group(2) ?? '';
      final id = tiebaEmoticonIdForName(name);
      if (id == null) {
        spans.add(TextSpan(text: match.group(0)));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 1)),
              child: Image.network(
                tiebaEmoticonUrl(id),
                width: fontSize * 1.15,
                height: fontSize * 1.15,
                errorBuilder: (context, error, stack) => Text(
                  match.group(0) ?? '',
                  style: TextStyle(fontSize: fontSize, color: widget.color),
                ),
              ),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      _addPlainWithLinks(
        spans,
        text.substring(cursor),
        fontSize,
        accent,
        explicitLink,
      );
    }
  }

  void _addPlainWithLinks(
    List<InlineSpan> spans,
    String text,
    double fontSize,
    bool accent,
    String explicitLink,
  ) {
    if (text.isEmpty) return;
    if (explicitLink.isNotEmpty) {
      _addLink(spans, text, explicitLink, accent);
      return;
    }
    var cursor = 0;
    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: accent ? const TextStyle(color: AppColors.accent) : null,
        ));
      }
      var raw = match.group(0) ?? '';
      var url = raw;
      while (url.isNotEmpty && '.,!?;:，。！？；：、）)'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      if (url.isEmpty) {
        spans.add(TextSpan(text: raw));
      } else {
        _addLink(spans, url, url, accent);
        final rest = raw.substring(url.length);
        if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: accent ? const TextStyle(color: AppColors.accent) : null,
      ));
    }
  }

  void _addLink(
    List<InlineSpan> spans,
    String text,
    String url,
    bool accent,
  ) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TiebaWebPage(url: url, title: '贴吧链接'),
          ),
        );
      };
    _recognizers.add(recognizer);
    spans.add(TextSpan(
      text: text,
      recognizer: recognizer,
      style: TextStyle(
        color: AppColors.accent,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.accent.withValues(alpha: 0.45),
        fontWeight: accent ? FontWeight.w600 : null,
      ),
    ));
  }
}
