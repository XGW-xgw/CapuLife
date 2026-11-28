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
import 'feed_page.dart';
import 'search_page.dart';
import 'thread_page.dart';

class TiebaExplorePage extends StatefulWidget {
  const TiebaExplorePage({super.key});

  @override
  State<TiebaExplorePage> createState() => _TiebaExplorePageState();
}

class _TiebaExplorePageState extends State<TiebaExplorePage> {
  static const _hotNames = {
    'all': '全部',
    'changgeng': '长更',
    'youxi': '游戏',
    'shuma': '数码',
    'shipin': '视频',
  };

  final ScrollController _scroll = ScrollController();
  TiebaClient? _client;
  String _tab = 'feed';
  bool _feedLoading = false;
  bool _feedLoadingMore = false;
  bool _feedHasMore = true;
  int _feedPage = 0;
  String _feedError = '';
  List<TiebaThread> _feedThreads = [];
  bool _hotLoading = false;
  bool _hotLoaded = false;
  String _hotError = '';
  List<TiebaThread> _hotThreads = [];
  List<({int id, String name, int discuss})> _topics = [];
  List<({String code, String id, String name})> _hotTabs = [];
  String _hotCode = 'all';
  String _hotTabId = '1';

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
    setState(() => _client = client);
    _fetchFeed('initial');
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_tab != 'feed') return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 260) {
      _fetchFeed('more');
    }
  }

  void _refresh() {
    if (_tab == 'hot') {
      _fetchHot();
    } else {
      _fetchFeed('initial');
    }
  }

  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (tab == 'hot' && !_hotLoaded) _fetchHot();
    if (tab == 'feed' && _feedThreads.isEmpty && !_feedLoading && _feedPage == 0) {
      _fetchFeed('initial');
    }
  }

  Future<void> _fetchFeed(String mode) async {
    final client = _client;
    if (client == null) return;
    if (mode == 'more' &&
        (_feedLoading || _feedLoadingMore || !_feedHasMore)) {
      return;
    }
    setState(() {
      if (mode == 'more') {
        _feedLoadingMore = true;
      } else {
        _feedLoading = true;
        _feedError = '';
      }
    });
    try {
      final page = mode == 'more' ? _feedPage + 1 : 1;
      final rows = await client.api.personalized(page: page);
      if (!mounted) return;
      final mapped = rows
          .map(mapTiebaProtoThread)
          .whereType<TiebaThread>()
          .where((thread) => thread.tid != 0)
          .toList();
      setState(() {
        if (mode == 'more') {
          final seen = _feedThreads.map((thread) => thread.tid).toSet();
          _feedThreads = [
            ..._feedThreads,
            ...mapped.where((thread) => !seen.contains(thread.tid)),
          ];
          _feedPage = page;
          _feedHasMore = mapped.isNotEmpty &&
              mapped.any((thread) => !seen.contains(thread.tid));
        } else {
          _feedThreads = mapped;
          _feedPage = 1;
          _feedHasMore = mapped.isNotEmpty;
        }
        _feedError = '';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is TiebaApiException ? error.message : '推荐加载失败';
      setState(() => _feedError = message);
      if (mode != 'initial' || _feedThreads.isNotEmpty) {
        showCapToast(context, message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _feedLoading = false;
          _feedLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchHot() async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _hotLoading = true;
      _hotError = '';
    });
    try {
      final result = await client.api.hotThreads(
        tabCode: _hotCode,
        tabId: _hotTabId,
      );
      if (!mounted) return;
      final threads = result.threads
          .map(mapTiebaProtoThread)
          .whereType<TiebaThread>()
          .where((thread) => thread.tid != 0)
          .toList();
      setState(() {
        _hotThreads = threads;
        _topics = result.topics;
        if (result.tabs.isNotEmpty) {
          final seen = <String>{'all'};
          final tabs = <({String code, String id, String name})>[
            (code: 'all', id: '1', name: '全部'),
          ];
          for (final tab in result.tabs) {
            if (tab.code.isEmpty || tab.code == 'all' || !seen.add(tab.code)) {
              continue;
            }
            tabs.add((
              code: tab.code,
              id: '${tab.id}',
              name: _hotNames[tab.code] ?? (tab.name.isEmpty ? tab.code : tab.name),
            ));
          }
          _hotTabs = tabs;
        }
        _hotLoaded = true;
        _hotError = '';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is TiebaApiException ? error.message : '热榜加载失败';
      setState(() => _hotError = message);
      if (_hotThreads.isNotEmpty) showCapToast(context, message);
    } finally {
      if (mounted) setState(() => _hotLoading = false);
    }
  }

  void _selectHotTab(({String code, String id, String name}) tab) {
    if (tab.code == _hotCode) return;
    setState(() {
      _hotCode = tab.code;
      _hotTabId = tab.id.isEmpty ? '0' : tab.id;
    });
    _fetchHot();
  }

  void _openThread(TiebaThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaThreadDetailPage(
          tid: thread.tid,
          title: thread.title,
          replyCount: thread.replyCount,
          forumName: thread.forumName,
        ),
      ),
    );
  }

  void _openForum(TiebaThread thread) {
    final name = thread.forumName.trim();
    if (name.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaFeedPage(external: true, forumKw: name),
      ),
    );
  }

  void _openTopic(({int id, String name, int discuss}) topic) {
    if (topic.name.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaSearchPage(initialKeyword: topic.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '发现',
            subtitle: '推荐 · 贴吧热榜',
            back: true,
            right: GestureDetector(
              onTap: _refresh,
              child: Container(
                width: capRpx(context, 58),
                height: capRpx(context, 58),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line, width: 0.8),
                ),
                child: Center(
                  child: CapIcon(
                    'refresh-cw',
                    size: capRpx(context, 27),
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              capRpx(context, 28),
              0,
              capRpx(context, 28),
              capRpx(context, 16),
            ),
            child: Container(
              padding: EdgeInsets.all(capRpx(context, 5)),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: Row(
                children: [
                  _tabButton('feed', 'sparkles', '推荐'),
                  SizedBox(width: capRpx(context, 6)),
                  _tabButton('hot', 'flame', '热榜'),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                0,
                capRpx(context, 28),
                capRpx(context, 48) + MediaQuery.paddingOf(context).bottom,
              ),
              children: _body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String icon, String label) {
    final active = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(key),
        child: AnimatedContainer(
          duration: capsuleMotion,
          curve: capsuleSpringCurve,
          height: capRpx(context, 64),
          decoration: BoxDecoration(
            color: active ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.18),
                      blurRadius: capRpx(context, 18),
                      offset: Offset(0, capRpx(context, 8)),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CapIcon(
                icon,
                size: capRpx(context, 19),
                color: active ? const Color(0xFFFFF8EA) : AppColors.muted,
              ),
              SizedBox(width: capRpx(context, 6)),
              Text(
                label,
                style: TextStyle(
                  fontSize: capRpx(context, 24),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? const Color(0xFFFFF8EA) : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final loading = _tab == 'hot' ? _hotLoading : _feedLoading;
    final error = _tab == 'hot' ? _hotError : _feedError;
    final threads = _tab == 'hot' ? _hotThreads : _feedThreads;
    return [
      if (_tab == 'hot') ...[
        if (_topics.isNotEmpty) _topicsCard(context),
        if (_hotTabs.isNotEmpty) _hotTabsRow(context),
      ],
      if (loading && threads.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: CapThreadSkeletonList(count: 2),
        )
      else if (error.isNotEmpty && threads.isEmpty)
        _stateCard(
          icon: 'wifi-off',
          danger: true,
          title: '加载失败',
          desc: error,
          action: '重试',
          onTap: _refresh,
        )
      else if (threads.isEmpty)
        _stateCard(
          icon: _tab == 'hot' ? 'flame' : 'sparkles',
          title: _tab == 'hot' ? '热榜暂时没有内容' : '推荐流暂时为空',
          desc: '过一会儿再刷新试试。',
          action: '刷新',
          onTap: _refresh,
        )
      else ...[
        for (var i = 0; i < threads.length; i += 1) ...[
          if (i > 0) SizedBox(height: capRpx(context, 14)),
          CapReveal(
            index: i,
            offset: const Offset(0, 12),
            child: _threadCard(context, threads[i], i),
          ),
        ],
        if (_tab == 'feed')
          Padding(
            padding: EdgeInsets.symmetric(vertical: capRpx(context, 22)),
            child: Center(
              child: Text(
                _feedLoadingMore
                    ? '正在加载更多'
                    : (_feedError.isNotEmpty
                        ? '$_feedError，点此重试'
                        : (!_feedHasMore ? '没有更多推荐了' : '')),
                style: TextStyle(
                  fontSize: capRpx(context, 21),
                  color: _feedError.isNotEmpty
                      ? AppColors.coral
                      : AppColors.mutedSoft,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(vertical: capRpx(context, 22)),
            child: Center(
              child: Text(
                _hotLoading ? '热榜更新中…' : '榜单实时更新，点帖子查看详情',
                style: TextStyle(
                  fontSize: capRpx(context, 21),
                  color: AppColors.mutedSoft,
                ),
              ),
            ),
          ),
      ],
    ];
  }

  Widget _topicsCard(BuildContext context) {
    final topics = _topics.take(7).toList();
    return Container(
      margin: EdgeInsets.only(bottom: capRpx(context, 16)),
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 20),
        capRpx(context, 18),
        capRpx(context, 20),
        capRpx(context, 8),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 26)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: capRpx(context, 10)),
            child: Row(
              children: [
                Row(
                  children: [
                    CapIcon(
                      'flame',
                      size: capRpx(context, 20),
                      color: AppColors.coral,
                    ),
                    SizedBox(width: capRpx(context, 6)),
                    Text(
                      '贴吧热议',
                      style: TextStyle(
                        fontSize: capRpx(context, 26),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '实时话题',
                  style: TextStyle(
                    fontSize: capRpx(context, 20),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < topics.length; i += 1)
            Pressable(
              onTap: () => _openTopic(topics[i]),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: capRpx(context, 12)),
                decoration: BoxDecoration(
                  border: i > 0
                      ? Border(
                          top: BorderSide(
                            color: AppColors.ink.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: capRpx(context, 34),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: capRpx(context, 24),
                          fontWeight: FontWeight.w800,
                          color: i < 3 ? AppColors.coral : AppColors.mutedSoft,
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 12)),
                    Expanded(
                      child: Text(
                        topics[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 23),
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 8)),
                    Text(
                      '${tiebaFormatCount(topics[i].discuss)}热议',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        color: AppColors.mutedSoft,
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

  Widget _hotTabsRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(bottom: capRpx(context, 14)),
      child: Row(
        children: [
          for (final tab in _hotTabs) ...[
            GestureDetector(
              onTap: () => _selectHotTab(tab),
              child: AnimatedContainer(
                duration: capsuleMotionFast,
                curve: capsuleSpringCurve,
                height: capRpx(context, 52),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 22)),
                margin: EdgeInsets.only(right: capRpx(context, 8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hotCode == tab.code
                      ? AppColors.accent
                      : AppColors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _hotCode == tab.code
                        ? AppColors.accent
                        : AppColors.line,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tab.name,
                  style: TextStyle(
                    fontSize: capRpx(context, 22),
                    fontWeight: FontWeight.w600,
                    color: _hotCode == tab.code
                        ? const Color(0xFFFFF8EA)
                        : AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _threadCard(BuildContext context, TiebaThread thread, int index) {
    final ranked = _tab == 'hot';
    return Pressable(
      onTap: () => _openThread(thread),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          ranked ? capRpx(context, 70) : capRpx(context, 22),
          capRpx(context, 20),
          capRpx(context, 22),
          capRpx(context, 18),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 26)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openForum(thread),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: capRpx(context, 12),
                            vertical: capRpx(context, 5),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CapIcon(
                                'message-square',
                                size: capRpx(context, 15),
                                color: AppColors.accent,
                              ),
                              SizedBox(width: capRpx(context, 4)),
                              Flexible(
                                child: Text(
                                  '${thread.forumName.isEmpty ? '贴吧' : thread.forumName}吧',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: capRpx(context, 20),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (ranked && thread.hotNum > 0)
                      Row(
                        children: [
                          CapIcon(
                            'flame',
                            size: capRpx(context, 14),
                            color: AppColors.coral,
                          ),
                          SizedBox(width: capRpx(context, 2)),
                          Text(
                            tiebaFormatCount(thread.hotNum),
                            style: TextStyle(
                              fontSize: capRpx(context, 20),
                              fontWeight: FontWeight.w700,
                              color: AppColors.coral,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        thread.lastTime,
                        style: TextStyle(
                          fontSize: capRpx(context, 20),
                          color: AppColors.mutedSoft,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: capRpx(context, 10)),
                Text(
                  thread.title,
                  style: TextStyle(
                    fontSize: capRpx(context, 28),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: AppColors.ink,
                  ),
                ),
                if (thread.preview.isNotEmpty) ...[
                  SizedBox(height: capRpx(context, 6)),
                  Text(
                    thread.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 22),
                      height: 1.55,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (thread.images.isNotEmpty) ...[
                  SizedBox(height: capRpx(context, 12)),
                  Row(
                    children: [
                      for (final image in thread.images.take(3))
                        Container(
                          width: capRpx(context, 190),
                          height: capRpx(context, 148),
                          margin: EdgeInsets.only(right: capRpx(context, 8)),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(capRpx(context, 16)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            image.url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const SizedBox(),
                          ),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: capRpx(context, 14)),
                Row(
                  children: [
                    _avatar(context, thread.author),
                    SizedBox(width: capRpx(context, 8)),
                    Flexible(
                      child: Text(
                        thread.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 21),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    if (thread.author.levelName.isNotEmpty) ...[
                      SizedBox(width: capRpx(context, 8)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 6)),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gold, width: 0.8),
                          borderRadius: BorderRadius.circular(capRpx(context, 8)),
                        ),
                        child: Text(
                          thread.author.levelName,
                          style: TextStyle(
                            fontSize: capRpx(context, 18),
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _stat(context, 'message-circle', thread.replyCount),
                    SizedBox(width: capRpx(context, 14)),
                    _stat(context, 'heart', thread.agreeCount),
                  ],
                ),
              ],
            ),
            if (ranked)
              Positioned(
                left: -capRpx(context, 52),
                top: capRpx(context, 2),
                child: SizedBox(
                  width: capRpx(context, 38),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: capRpx(context, 26),
                      fontWeight: FontWeight.w800,
                      color: index < 3 ? AppColors.coral : AppColors.mutedSoft,
                    ),
                  ),
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
        width: capRpx(context, 38),
        height: capRpx(context, 38),
        decoration: const BoxDecoration(
          color: AppColors.accentSoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          user.name.isEmpty ? '吧' : user.name.substring(0, 1),
          style: TextStyle(
            fontSize: capRpx(context, 18),
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return Container(
      width: capRpx(context, 38),
      height: capRpx(context, 38),
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

  Widget _stat(BuildContext context, String icon, int value) {
    return Row(
      children: [
        CapIcon(icon, size: capRpx(context, 16), color: AppColors.mutedSoft),
        SizedBox(width: capRpx(context, 3)),
        Text(
          tiebaFormatCount(value),
          style: TextStyle(
            fontSize: capRpx(context, 20),
            color: AppColors.mutedSoft,
          ),
        ),
      ],
    );
  }

  Widget _stateCard({
    required String icon,
    required String title,
    required String desc,
    bool danger = false,
    String action = '',
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(top: capRpx(context, 20)),
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 36),
        capRpx(context, 56),
        capRpx(context, 36),
        capRpx(context, 52),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 28)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 96),
            height: capRpx(context, 96),
            decoration: BoxDecoration(
              color: danger ? AppColors.coralSoft : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 30)),
            ),
            child: Center(
              child: CapIcon(
                icon,
                size: capRpx(context, 46),
                color: danger ? AppColors.coral : AppColors.accent,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 14)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 30),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 23),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          if (action.isNotEmpty && onTap != null) ...[
            SizedBox(height: capRpx(context, 18)),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: capRpx(context, 64),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 30)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: capRpx(context, 24),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFFDF8),
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