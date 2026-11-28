import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_models.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_skeleton.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/pressable.dart';
import 'feed_page.dart';
import 'thread_page.dart';

class TiebaSearchPage extends StatefulWidget {
  const TiebaSearchPage({
    super.key,
    this.forumName = '',
    this.initialKeyword = '',
  });

  final String forumName;
  final String initialKeyword;

  @override
  State<TiebaSearchPage> createState() => _TiebaSearchPageState();
}

class _TiebaSearchPageState extends State<TiebaSearchPage> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  TiebaClient? _client;
  int _tab = 0;
  String _keyword = '';
  bool _loading = false;
  String _error = '';
  bool _inForumOnly = false;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  List<TiebaSearchThread> _threads = [];
  List<TiebaSearchForum> _forums = [];
  List<TiebaUser> _users = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() => _client = client);
    final initial = widget.initialKeyword.trim();
    if (initial.isNotEmpty) {
      _input.text = initial;
      _search();
    } else {
      _focus.requestFocus();
    }
  }

  Future<void> _search({bool fromPagination = false}) async {
    final keyword = fromPagination ? _keyword : _input.text.trim();
    final client = _client;
    if (client == null) return;
    if (keyword.isEmpty) {
      showCapToast(context, '请输入搜索内容');
      _focus.requestFocus();
      return;
    }
    _focus.unfocus();
    setState(() {
      if (!fromPagination) {
        _keyword = keyword;
        _page = 1;
        _hasMore = false;
        _threads = [];
        _forums = [];
        _users = [];
      }
      _loading = !fromPagination;
      _loadingMore = fromPagination;
      _error = '';
    });
    try {
      if (_tab == 0) {
        final result = await client.api.searchThread(
          keyword: keyword,
          pn: fromPagination ? _page + 1 : 1,
          order: 2,
          forumName: _inForumOnly ? widget.forumName : '',
        );
        if (!mounted) return;
        final mapped = result.items.map(mapTiebaSearchThread).where((item) => item.tid != 0).toList();
        setState(() {
          if (fromPagination) {
            final seen = _threads.map((item) => item.tid).toSet();
            _threads = [
              ..._threads,
              ...mapped.where((item) => !seen.contains(item.tid)),
            ];
            _page += 1;
          } else {
            _threads = mapped;
          }
          _hasMore = result.hasMore && mapped.isNotEmpty;
        });
      } else if (_tab == 1) {
        final result = await client.api.searchForum(keyword);
        if (!mounted) return;
        final exact = result['exact'];
        final fuzzy = result['fuzzy'] as List<dynamic>;
        final list = <TiebaSearchForum>[
          if (exact is Map) mapTiebaSearchForum(exact),
          ...fuzzy.whereType<Map>().map(mapTiebaSearchForum),
        ];
        final seen = <int>{};
        setState(() {
          _forums = [
            for (final forum in list)
              if (forum.name.isNotEmpty && seen.add(forum.id)) forum,
          ];
          _hasMore = false;
        });
      } else {
        final rows = await client.api.searchUser(keyword);
        if (!mounted) return;
        final seen = <int>{};
        final users = <TiebaUser>[];
        for (final raw in rows) {
          final user = mapTiebaUser(raw);
          if (user.id != 0 && seen.add(user.id)) users.add(user);
        }
        setState(() {
          _users = users;
          _hasMore = false;
        });
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!fromPagination) _error = error is TiebaApiException ? error.message : '$error';
      });
      if (fromPagination) {
        showCapToast(context, error is TiebaApiException ? error.message : '加载失败');
      }
    }
  }

  void _switchTab(int tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _threads = [];
      _forums = [];
      _users = [];
      _error = '';
      _page = 1;
      _hasMore = false;
    });
    if (_keyword.isNotEmpty) _search();
  }

  void _openForum(String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaFeedPage(external: true, forumKw: name),
      ),
    );
  }

  void _openThread(TiebaSearchThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaThreadDetailPage(
          tid: thread.tid,
          title: thread.title,
          forumName: thread.forumName,
        ),
      ),
    );
  }

  Future<void> _toggleFollow(TiebaUser user) async {
    final client = _client;
    if (client == null) return;
    if (!client.loggedIn) {
      showCapToast(context, '请先登录贴吧账号');
      return;
    }
    if (user.portraitRaw.isEmpty) {
      showCapToast(context, '该用户没有可关注的资料');
      return;
    }
    try {
      final target = !user.hasConcerned;
      await client.api.toggleFollowUser(portrait: user.portraitRaw, follow: target);
      if (!mounted) return;
      setState(() => user.hasConcerned = target);
      showCapToast(context, target ? '已关注' : '已取消关注');
    } catch (error) {
      if (mounted) {
        showCapToast(context, error is TiebaApiException ? error.message : '操作失败');
      }
    }
  }

  void _copyUser(TiebaUser user) {
    final name = user.account.isNotEmpty ? user.account : user.name;
    final url = 'https://tieba.baidu.com/home/main?un=${Uri.encodeComponent(name)}';
    Clipboard.setData(ClipboardData(text: url));
    showCapToast(context, '主页链接已复制');
  }

  @override
  Widget build(BuildContext context) {
    return CapPage(
      child: Column(
        children: [
          const CapAppHeader(
            title: '搜索',
            subtitle: '贴吧、帖子与吧友',
            back: true,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              capRpx(context, 28),
              0,
              capRpx(context, 28),
              capRpx(context, 12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: capRpx(context, 70),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(capRpx(context, 22)),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        CapIcon(
                          'search',
                          size: capRpx(context, 22),
                          color: AppColors.mutedSoft,
                        ),
                        SizedBox(width: capRpx(context, 8)),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _search(),
                            style: TextStyle(
                              fontSize: capRpx(context, 23),
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '搜索感兴趣的帖子或吧友',
                              hintStyle: TextStyle(
                                fontSize: capRpx(context, 22),
                                color: AppColors.mutedSoft,
                              ),
                            ),
                          ),
                        ),
                        if (_input.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _input.clear();
                              setState(() {});
                            },
                            child: CapIcon(
                              'x',
                              size: capRpx(context, 21),
                              color: AppColors.mutedSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: capRpx(context, 10)),
                GestureDetector(
                  onTap: () => _search(),
                  child: Container(
                    height: capRpx(context, 70),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 22)),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(capRpx(context, 22)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '搜索',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              capRpx(context, 28),
              0,
              capRpx(context, 28),
              capRpx(context, 12),
            ),
            child: Container(
              padding: EdgeInsets.all(capRpx(context, 5)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i += 1) ...[
                    if (i > 0) SizedBox(width: capRpx(context, 6)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchTab(i),
                        child: AnimatedContainer(
                          duration: capsuleMotionFast,
                          curve: capsuleSpringCurve,
                          height: capRpx(context, 52),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab == i ? AppColors.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            const ['帖子', '贴吧', '用户'][i],
                            style: TextStyle(
                              fontSize: capRpx(context, 21),
                              fontWeight: FontWeight.w700,
                              color: _tab == i ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                0,
                capRpx(context, 28),
                capRpx(context, 60) + MediaQuery.paddingOf(context).bottom,
              ),
              children: _body(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_loading) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: CapThreadSkeletonList(count: 2),
        ),
      ];
    }
    if (_error.isNotEmpty) {
      return [
        _empty(
          icon: 'wifi-off',
          title: '搜索没有完成',
          desc: _error,
          action: '重试',
          onTap: () => _search(),
          danger: true,
        ),
      ];
    }
    if (_keyword.isEmpty) {
      return [
        _empty(
          icon: 'search',
          title: '搜点什么吧',
          desc: '可以搜吧名、帖子标题或吧友昵称。',
        ),
      ];
    }
    if (_tab == 0) {
      if (_threads.isEmpty) {
        return [
          _empty(
            icon: 'search',
            title: '没有找到相关帖子',
            desc: '换个关键词试试，或切到「贴吧」看看有没有对应的吧。',
          ),
        ];
      }
      return [
        if (widget.forumName.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: capRpx(context, 10)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _inForumOnly = false);
                    _search();
                  },
                  child: _chip('全站', !_inForumOnly),
                ),
                SizedBox(width: capRpx(context, 8)),
                GestureDetector(
                  onTap: () {
                    setState(() => _inForumOnly = true);
                    _search();
                  },
                  child: _chip('本吧内', _inForumOnly),
                ),
              ],
            ),
          ),
        for (var i = 0; i < _threads.length; i += 1) ...[
          if (i > 0) SizedBox(height: capRpx(context, 10)),
          _threadCard(context, _threads[i]),
        ],
        _footer(context),
      ];
    }
    if (_tab == 1) {
      if (_forums.isEmpty) {
        return [
          _empty(
            icon: 'message-circle',
            title: '没有找到相关贴吧',
            desc: '检查一下吧名，或者换个说法再搜。',
          ),
        ];
      }
      return [
        for (var i = 0; i < _forums.length; i += 1) ...[
          if (i > 0) SizedBox(height: capRpx(context, 10)),
          _forumCard(context, _forums[i]),
        ],
      ];
    }
    if (_users.isEmpty) {
      return [
        _empty(
          icon: 'user',
          title: '没有找到相关吧友',
          desc: '可以试试完整昵称，或改用贴吧里的搜索。',
        ),
      ];
    }
    return [
      for (var i = 0; i < _users.length; i += 1) ...[
        if (i > 0) SizedBox(height: capRpx(context, 10)),
        _userCard(context, _users[i]),
      ],
    ];
  }

  Widget _chip(String label, bool active) => Container(
    height: capRpx(context, 44),
    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: active ? AppColors.accentSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: active ? AppColors.accent.withValues(alpha: 0.24) : AppColors.line,
        width: 0.8,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: capRpx(context, 19),
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? AppColors.accent : AppColors.muted,
      ),
    ),
  );

  Widget _footer(BuildContext context) {
    if (_loadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
        child: Center(
          child: Text(
            '正在加载更多…',
            style: TextStyle(
              fontSize: capRpx(context, 19),
              color: AppColors.mutedSoft,
            ),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
        child: Center(
          child: Text(
            '结果到底了',
            style: TextStyle(
              fontSize: capRpx(context, 19),
              color: AppColors.mutedSoft,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _search(fromPagination: true),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
        child: Center(
          child: Text(
            '加载更多',
            style: TextStyle(
              fontSize: capRpx(context, 19),
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _threadCard(BuildContext context, TiebaSearchThread thread) {
    return Pressable(
      onTap: () => _openThread(thread),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 20)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thread.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: capRpx(context, 24),
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
            if (thread.content.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 6)),
              Text(
                thread.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  height: 1.55,
                  color: AppColors.muted,
                ),
              ),
            ],
            SizedBox(height: capRpx(context, 10)),
            Row(
              children: [
                Container(
                  height: capRpx(context, 34),
                  padding: EdgeInsets.symmetric(horizontal: capRpx(context, 9)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${thread.forumName.isEmpty ? '贴吧' : '${thread.forumName}吧'}',
                    style: TextStyle(
                      fontSize: capRpx(context, 16),
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                SizedBox(width: capRpx(context, 8)),
                Expanded(
                  child: Text(
                    '${thread.author.name}${thread.time > 0 ? ' · ${tiebaFormatTime(thread.time)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ),
                CapIcon(
                  'message-circle',
                  size: capRpx(context, 16),
                  color: AppColors.mutedSoft,
                ),
                SizedBox(width: capRpx(context, 3)),
                Text(
                  '${thread.replyCount}',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _forumCard(BuildContext context, TiebaSearchForum forum) {
    return Pressable(
      onTap: () => _openForum(forum.name),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 18)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: capRpx(context, 76),
              height: capRpx(context, 76),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 20)),
              ),
              clipBehavior: Clip.antiAlias,
              child: forum.avatar.isEmpty
                  ? Center(
                      child: CapIcon(
                        'message-circle',
                        size: capRpx(context, 34),
                        color: AppColors.accent,
                      ),
                    )
                  : Image.network(
                      forum.avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox(),
                    ),
            ),
            SizedBox(width: capRpx(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${forum.name}吧',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 24),
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 4)),
                  Text(
                    forum.slogan.isNotEmpty
                        ? forum.slogan
                        : '${forum.concernNum} 关注 · ${forum.postNum} 帖子',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      color: AppColors.mutedSoft,
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

  Widget _userCard(BuildContext context, TiebaUser user) {
    return Pressable(
      onTap: () => _showUserSheet(user),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 16)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 22)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: capRpx(context, 72),
              height: capRpx(context, 72),
              decoration: const BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: user.avatar.isEmpty
                  ? Center(
                      child: Text(
                        user.name.isEmpty ? '吧' : user.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: capRpx(context, 28),
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  : Image.network(
                      user.avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox(),
                    ),
            ),
            SizedBox(width: capRpx(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 3)),
                  Text(
                    [
                      if (user.account.isNotEmpty) '@${user.account}',
                      if (user.levelName.isNotEmpty) user.levelName,
                      if (user.fansNum > 0) '${tiebaFormatCount(user.fansNum)} 粉丝',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: capRpx(context, 8)),
            GestureDetector(
              onTap: () => _toggleFollow(user),
              child: Container(
                height: capRpx(context, 50),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: user.hasConcerned ? AppColors.surfaceSoft : AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.hasConcerned ? '已关注' : '关注',
                  style: TextStyle(
                    fontSize: capRpx(context, 19),
                    fontWeight: FontWeight.w700,
                    color: user.hasConcerned ? AppColors.muted : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserSheet(TiebaUser user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 24),
          capRpx(context, 20),
          capRpx(context, 24),
          capRpx(context, 24) + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: capRpx(context, 76),
              height: capRpx(context, 5),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: capRpx(context, 20)),
            Row(
              children: [
                Container(
                  width: capRpx(context, 82),
                  height: capRpx(context, 82),
                  decoration: const BoxDecoration(
                    color: AppColors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: user.avatar.isEmpty
                      ? Center(
                          child: Text(
                            user.name.isEmpty ? '吧' : user.name.substring(0, 1),
                            style: TextStyle(
                              fontSize: capRpx(context, 32),
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      : Image.network(
                          user.avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const SizedBox(),
                        ),
                ),
                SizedBox(width: capRpx(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 28),
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: capRpx(context, 4)),
                      Text(
                        [
                          if (user.account.isNotEmpty) '@${user.account}',
                          if (user.levelName.isNotEmpty) user.levelName,
                          if (user.ip.isNotEmpty) 'IP：${user.ip}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 19),
                          color: AppColors.mutedSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 18)),
            _sheetRow(
              icon: 'external-link',
              label: '复制主页链接',
              onTap: () {
                Navigator.pop(sheetContext);
                _copyUser(user);
              },
            ),
            SizedBox(height: capRpx(context, 10)),
            _sheetRow(
              icon: user.hasConcerned ? 'minus' : 'plus',
              label: user.hasConcerned ? '取消关注' : '关注 TA',
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleFollow(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetRow({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 72),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 20)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            CapIcon(icon, size: capRpx(context, 24), color: AppColors.muted),
            SizedBox(width: capRpx(context, 10)),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 22),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty({
    required String icon,
    required String title,
    required String desc,
    String action = '',
    VoidCallback? onTap,
    bool danger = false,
  }) {
    return Container(
      margin: EdgeInsets.only(top: capRpx(context, 24)),
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 30),
        capRpx(context, 46),
        capRpx(context, 30),
        capRpx(context, 40),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 28)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 90),
            height: capRpx(context, 90),
            decoration: BoxDecoration(
              color: danger ? AppColors.coralSoft : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 26)),
            ),
            child: Center(
              child: CapIcon(
                icon,
                size: capRpx(context, 44),
                color: danger ? AppColors.coral : AppColors.accent,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 16)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 27),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 20),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          if (action.isNotEmpty && onTap != null) ...[
            SizedBox(height: capRpx(context, 18)),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: capRpx(context, 62),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 24)),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: capRpx(context, 21),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}