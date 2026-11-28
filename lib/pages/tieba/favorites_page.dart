import 'package:flutter/material.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_models.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_reveal.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/pressable.dart';
import 'login_page.dart';
import 'thread_page.dart';

class TiebaFavoritesPage extends StatefulWidget {
  const TiebaFavoritesPage({super.key});

  @override
  State<TiebaFavoritesPage> createState() => _TiebaFavoritesPageState();
}

class _TiebaFavoritesPageState extends State<TiebaFavoritesPage> {
  TiebaClient? _client;
  List<TiebaStoreThread> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() => _client = client);
    if (client.loggedIn) _fetch('initial');
  }

  Future<void> _fetch(String mode) async {
    final client = _client;
    if (client == null || !client.loggedIn) return;
    if (mode == 'more' && (_loadingMore || !_hasMore)) return;
    setState(() {
      if (mode == 'initial') {
        _loading = true;
        _error = '';
        _items = [];
        _offset = 0;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final rows = await client.api.threadStore(
        pageSize: 20,
        offset: mode == 'more' ? _offset : 0,
      );
      if (!mounted) return;
      final mapped = rows.map(mapTiebaStoreThread).where((item) => item.threadId != 0).toList();
      setState(() {
        if (mode == 'more') {
          final seen = _items.map((item) => item.threadId).toSet();
          _items = [
            ..._items,
            ...mapped.where((item) => !seen.contains(item.threadId)),
          ];
        } else {
          _items = mapped;
        }
        _offset = (mode == 'more' ? _offset : 0) + rows.length;
        _hasMore = mapped.length >= 20;
        _loading = false;
        _loadingMore = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (mode != 'more') _error = '$error';
      });
      if (mode == 'more') {
        showCapToast(context, error is TiebaApiException ? error.message : '加载失败');
      }
    }
  }

  Future<void> _remove(TiebaStoreThread item) async {
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
          '取消收藏',
          style: TextStyle(
            fontSize: capRpx(context, 28),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '将「${item.title}」从贴吧收藏中移除？',
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
            child: const Text('移除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await client.api.removeThreadStore(threadId: item.threadId);
      if (!mounted) return;
      setState(() => _items = _items.where((entry) => entry.threadId != item.threadId).toList());
      showCapToast(context, '已取消收藏');
    } catch (error) {
      if (mounted) {
        showCapToast(
          context,
          error is TiebaApiException ? error.message : '取消收藏失败',
        );
      }
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
    if (_client?.loggedIn == true) _fetch('initial');
  }

  void _open(TiebaStoreThread item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiebaThreadDetailPage(
          tid: item.threadId,
          title: item.title,
          forumName: item.forumName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '我的收藏',
            subtitle: '收藏的帖子都在这里',
            back: true,
            right: GestureDetector(
              onTap: () => _fetch('initial'),
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
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async => _fetch('initial'),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  capRpx(context, 28),
                  0,
                  capRpx(context, 28),
                  capRpx(context, 60) + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (client == null || (_loading && _items.isEmpty))
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (!client.loggedIn)
                    _state(
                      icon: 'bookmark',
                      title: '登录后查看收藏',
                      desc: '收藏列表保存在百度贴吧账号里，登录后可以随时打开。',
                      action: '登录百度账号',
                      onTap: _login,
                    )
                  else if (_error.isNotEmpty && _items.isEmpty)
                    _state(
                      icon: 'wifi-off',
                      danger: true,
                      title: '收藏没有加载出来',
                      desc: _error,
                      action: '重试',
                      onTap: () => _fetch('initial'),
                    )
                  else if (_items.isEmpty)
                    _state(
                      icon: 'bookmark',
                      title: '还没有收藏帖子',
                      desc: '在帖子右上角点收藏，稍后就能在这里找到。',
                      action: '刷新',
                      onTap: () => _fetch('initial'),
                    )
                  else ...[
                    for (var i = 0; i < _items.length; i += 1) ...[
                      if (i > 0) SizedBox(height: capRpx(context, 10)),
                      CapReveal(
                        index: i,
                        offset: const Offset(0, 10),
                        child: _card(context, _items[i]),
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
                    else if (!_hasMore)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: capRpx(context, 20)),
                        child: Center(
                          child: Text(
                            '没有更多收藏了',
                            style: TextStyle(
                              fontSize: capRpx(context, 19),
                              color: AppColors.mutedSoft,
                            ),
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => _fetch('more'),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, TiebaStoreThread item) {
    return Pressable(
      onTap: () => _open(item),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 20)),
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
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 20)),
              ),
              child: Center(
                child: CapIcon(
                  'bookmark',
                  size: capRpx(context, 34),
                  color: AppColors.accent,
                ),
              ),
            ),
            SizedBox(width: capRpx(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 5)),
                  Text(
                    '${item.forumName.isEmpty ? '贴吧' : '${item.forumName}吧'} · ${item.author.name}${item.isDeleted ? ' · 该帖已被删除' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      color: item.isDeleted ? AppColors.coral : AppColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: capRpx(context, 8)),
            GestureDetector(
              onTap: () => _remove(item),
              child: Container(
                width: capRpx(context, 52),
                height: capRpx(context, 52),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: CapIcon(
                    'trash-2',
                    size: capRpx(context, 22),
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
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