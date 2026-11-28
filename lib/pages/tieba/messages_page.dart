import 'package:flutter/material.dart';

import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_models.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_reveal.dart';
import 'login_page.dart';
import 'thread_page.dart';

class TiebaMessagesPage extends StatefulWidget {
  const TiebaMessagesPage({super.key});

  @override
  State<TiebaMessagesPage> createState() => _TiebaMessagesPageState();
}

class _TiebaMessagesPageState extends State<TiebaMessagesPage> {
  TiebaClient? _client;
  int _tab = 0;
  final List<List<Map<String, dynamic>>> _items = [[], []];
  final List<int> _page = [1, 1];
  final List<bool> _hasMore = [true, true];
  final List<bool> _loading = [false, false];
  final List<String> _error = ['', ''];
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() => _client = client);
    if (!client.loggedIn) {
      setState(() {
        _loading[0] = false;
        _loading[1] = false;
      });
      return;
    }
    await client.healSession();
    if (!mounted) return;
    _fetch(0, refresh: true);
  }

  Future<void> _fetch(int tab, {bool refresh = false}) async {
    final client = _client;
    if (client == null || client.account == null) return;
    if (!refresh && (_loadingMore || !_hasMore[tab])) return;
    if (refresh) {
      setState(() {
        _loading[tab] = _items[tab].isEmpty;
        _error[tab] = '';
        _hasMore[tab] = true;
        _page[tab] = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final pn = refresh ? 1 : _page[tab] + 1;
      final result = tab == 0
          ? await client.api.replyMe(pn: pn)
          : await client.api.atMe(pn: pn);
      if (!mounted) return;
      final mapped = result.items.asMap().entries.map((entry) {
        final raw = entry.value;
        final replyer = raw['replyer'] is Map
            ? Map<String, dynamic>.from(raw['replyer'] as Map)
            : <String, dynamic>{};
        return <String, dynamic>{
          'key':
              '${raw['thread_id'] ?? 0}-${raw['post_id'] ?? 0}-${raw['time'] ?? 0}-${entry.key}',
          'threadId': tiebaInt(raw['thread_id']),
          'postId': tiebaInt(raw['post_id']),
          'title': _strip(raw['title']),
          'content': _strip(raw['content']),
          'quote': _strip(raw['quote_content']),
          'forumName': '${raw['fname'] ?? ''}',
          'user': mapTiebaUser(replyer),
          'time': tiebaInt(raw['time']),
        };
      }).toList();
      setState(() {
        if (refresh) {
          _items[tab] = mapped;
          _page[tab] = 1;
        } else {
          final seen = _items[tab].map((item) => '${item['key']}').toSet();
          _items[tab] = [
            ..._items[tab],
            ...mapped.where((item) => !seen.contains('${item['key']}')),
          ];
          _page[tab] = pn;
        }
        _hasMore[tab] = result.hasMore && mapped.isNotEmpty;
        _loading[tab] = false;
        _loadingMore = false;
        _error[tab] = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading[tab] = false;
        _loadingMore = false;
        _error[tab] = '$error';
      });
    }
  }

  String _strip(dynamic raw) => '${raw ?? ''}'
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _openItem(Map<String, dynamic> item) {
    final tid = tiebaInt(item['threadId']);
    if (tid == 0) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaThreadDetailPage(
          tid: tid,
          title: '${item['title'] ?? ''}',
          forumName: '${item['forumName'] ?? ''}',
        ),
      ),
    );
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
      _fetch(0, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final loggedIn = client?.loggedIn == true;
    final items = _items[_tab];
    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '消息',
            subtitle: '回复我的与 @我的',
            back: true,
            right: GestureDetector(
              onTap: () => _fetch(_tab, refresh: true),
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
                else if (!loggedIn)
                  _state(
                    icon: 'bell',
                    title: '登录后查看消息',
                    desc: '回复我的、@我的都存在百度账号里，登录后同步到本机展示。',
                    action: '登录百度账号',
                    onTap: _login,
                  )
                else ...[
                  Container(
                    margin: EdgeInsets.only(bottom: capRpx(context, 14)),
                    padding: EdgeInsets.all(capRpx(context, 5)),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < 2; i += 1) ...[
                          if (i == 1) SizedBox(width: capRpx(context, 6)),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_tab == i) return;
                                setState(() => _tab = i);
                                if (!_loading[i] && _items[i].isEmpty && _error[i].isEmpty) {
                                  _fetch(i, refresh: true);
                                }
                              },
                              child: AnimatedContainer(
                                duration: capsuleMotionFast,
                                curve: capsuleSpringCurve,
                                height: capRpx(context, 54),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _tab == i ? AppColors.ink : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  i == 0 ? '回复我的' : '@我的',
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
                  if (_loading[_tab] && items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_error[_tab].isNotEmpty && items.isEmpty)
                    _state(
                      icon: 'wifi-off',
                      danger: true,
                      title: '消息没有加载出来',
                      desc: _error[_tab],
                      action: '重试',
                      onTap: () => _fetch(_tab, refresh: true),
                    )
                  else if (items.isEmpty)
                    _state(
                      icon: 'message-circle',
                      title: '暂时没有消息',
                      desc: _tab == 0 ? '去成航吧发个帖子，或者等吧友来找你。' : '暂时还没有人 @ 你。',
                      action: '刷新',
                      onTap: () => _fetch(_tab, refresh: true),
                    )
                  else ...[
                    for (var i = 0; i < items.length; i += 1) ...[
                      if (i > 0) SizedBox(height: capRpx(context, 10)),
                      CapReveal(
                        index: i,
                        offset: const Offset(0, 10),
                        child: _messageCard(context, items[i]),
                      ),
                    ],
                    if (_loadingMore)
                      Padding(
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
                      )
                    else if (!_hasMore[_tab])
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
                        child: Center(
                          child: Text(
                            '没有更多消息了',
                            style: TextStyle(
                              fontSize: capRpx(context, 19),
                              color: AppColors.mutedSoft,
                            ),
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => _fetch(_tab),
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
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(BuildContext context, Map<String, dynamic> item) {
    final user = item['user'] as TiebaUser? ?? TiebaUser();
    final forumName = '${item['forumName'] ?? ''}';
    final subtitle =
        '${tiebaFormatTime(item['time'])}${forumName.isEmpty ? '' : ' · $forumName吧'}';
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 18)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(context, user),
                SizedBox(width: capRpx(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 22),
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: AppColors.mutedSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                CapIcon(
                  'message-square',
                  size: capRpx(context, 20),
                  color: AppColors.mutedSoft,
                ),
              ],
            ),
            if ('${item['title']}'.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 8)),
              Text(
                '${item['title']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 21),
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
            if ('${item['content']}'.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 5)),
              Text(
                '${item['content']}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  height: 1.55,
                  color: AppColors.muted,
                ),
              ),
            ],
            if ('${item['quote']}'.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 6)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: capRpx(context, 10),
                  vertical: capRpx(context, 8),
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 10)),
                ),
                child: Text(
                  '${item['quote']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: capRpx(context, 18),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ),
            ],
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
            fontSize: capRpx(context, 20),
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

  Widget _state({
    required String icon,
    required String title,
    required String desc,
    required String action,
    required VoidCallback onTap,
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
      ),
    );
  }
}