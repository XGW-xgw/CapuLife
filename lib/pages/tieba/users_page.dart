import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_models.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/pressable.dart';

class TiebaUsersPage extends StatefulWidget {
  const TiebaUsersPage({
    super.key,
    required this.type,
    this.uid = '',
  });

  /// `following` 或 `fans`.
  final String type;
  final String uid;

  @override
  State<TiebaUsersPage> createState() => _TiebaUsersPageState();
}

class _TiebaUsersPageState extends State<TiebaUsersPage> {
  TiebaClient? _client;
  List<TiebaUser> _users = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _error = '';
  final Set<int> _busy = {};

  bool get _isFans => widget.type == 'fans';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = await TiebaClient.load();
    if (!mounted) return;
    setState(() => _client = client);
    _fetch('initial');
  }

  TiebaUser? _pickUser(Map<String, dynamic> raw) {
    if (raw['user'] is Map) {
      final user = mapTiebaUser(Map<String, dynamic>.from(raw['user'] as Map));
      if (user.id != 0) return user;
    }
    final direct = mapTiebaUser(raw);
    return direct.id == 0 ? null : direct;
  }

  Future<void> _fetch(String mode) async {
    final client = _client;
    if (client == null) return;
    if (mode == 'more' && (_loadingMore || !_hasMore)) return;
    setState(() {
      if (mode == 'initial') {
        _loading = true;
        _error = '';
        _users = [];
        _page = 1;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final pn = mode == 'more' ? _page + 1 : 1;
      final result = _isFans
          ? await client.api.fansList(uid: widget.uid, pn: pn)
          : await client.api.followList(uid: widget.uid, pn: pn);
      if (!mounted) return;
      final mapped = result.items
          .map(_pickUser)
          .whereType<TiebaUser>()
          .toList();
      setState(() {
        if (mode == 'more') {
          final seen = _users.map((user) => user.id).toSet();
          _users = [
            ..._users,
            ...mapped.where((user) => !seen.contains(user.id)),
          ];
          _page = pn;
        } else {
          _users = mapped;
          _page = 1;
        }
        _hasMore = result.hasMore && mapped.isNotEmpty;
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

  Future<void> _toggleFollow(TiebaUser user) async {
    final client = _client;
    if (client == null || user.portraitRaw.isEmpty || _busy.contains(user.id)) return;
    if (!client.loggedIn) {
      showCapToast(context, '请先登录贴吧账号');
      return;
    }
    final target = !user.hasConcerned;
    setState(() => _busy.add(user.id));
    try {
      await client.api.toggleFollowUser(portrait: user.portraitRaw, follow: target);
      if (!mounted) return;
      setState(() => user.hasConcerned = target);
      showCapToast(context, target ? '已关注' : '已取消关注');
    } catch (error) {
      if (mounted) {
        showCapToast(
          context,
          error is TiebaApiException ? error.message : '操作失败',
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  void _copyProfile(TiebaUser user) {
    final name = user.account.isNotEmpty ? user.account : user.name;
    final url = 'https://tieba.baidu.com/home/main?un=${Uri.encodeComponent(name)}';
    Clipboard.setData(ClipboardData(text: url));
    showCapToast(context, '主页链接已复制');
  }

  void _openUser(TiebaUser user) {
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
                _avatar(context, user, 82),
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
            _sheetAction(
              icon: 'external-link',
              label: '复制主页链接',
              onTap: () {
                Navigator.pop(sheetContext);
                _copyProfile(user);
              },
            ),
            SizedBox(height: capRpx(context, 10)),
            _sheetAction(
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

  Widget _sheetAction({
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

  Widget _avatar(BuildContext context, TiebaUser user, double size) {
    return Container(
      width: capRpx(context, size),
      height: capRpx(context, size),
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
                  fontSize: capRpx(context, 30),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: _isFans ? '我的粉丝' : '我的关注',
            subtitle: _isFans ? '关注我的人' : '我关注的吧友',
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
                  if (client == null || (_loading && _users.isEmpty))
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (client.account == null)
                    _state(
                      icon: 'users',
                      title: '登录后查看',
                      desc: '登录百度贴吧账号后，这里会显示${_isFans ? '关注你的吧友' : '你关注的吧友'}。',
                    )
                  else if (_error.isNotEmpty && _users.isEmpty)
                    _state(
                      icon: 'wifi-off',
                      danger: true,
                      title: '列表没有加载出来',
                      desc: _error,
                      action: '重试',
                      onTap: () => _fetch('initial'),
                    )
                  else if (_users.isEmpty)
                    _state(
                      icon: 'users',
                      title: _isFans ? '还没有粉丝' : '还没有关注吧友',
                      desc: _isFans ? '多在吧里发帖交流，会有吧友关注你。' : '在贴子里点开吧友的主页即可关注。',
                      action: '刷新',
                      onTap: () => _fetch('initial'),
                    )
                  else ...[
                    for (var i = 0; i < _users.length; i += 1) ...[
                      if (i > 0) SizedBox(height: capRpx(context, 10)),
                      _row(context, _users[i]),
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
                            '没有更多了',
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

  Widget _row(BuildContext context, TiebaUser user) {
    final busy = _busy.contains(user.id);
    return Pressable(
      onTap: () => _openUser(user),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 16)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 22)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            _avatar(context, user, 72),
            SizedBox(width: capRpx(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: capRpx(context, 23),
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (user.levelName.isNotEmpty) ...[
                        SizedBox(width: capRpx(context, 6)),
                        Container(
                          height: capRpx(context, 28),
                          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 7)),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user.levelName,
                            style: TextStyle(
                              fontSize: capRpx(context, 14),
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: capRpx(context, 3)),
                  Text(
                    [
                      if (user.account.isNotEmpty) '@${user.account}',
                      if (user.intro.isNotEmpty) user.intro,
                      if (user.intro.isEmpty && user.ip.isNotEmpty) 'IP：${user.ip}',
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
              onTap: busy ? null : () => _toggleFollow(user),
              child: Container(
                height: capRpx(context, 50),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: user.hasConcerned ? AppColors.surfaceSoft : AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                  border: user.hasConcerned
                      ? Border.all(color: AppColors.line, width: 0.8)
                      : null,
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

  Widget _state({
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