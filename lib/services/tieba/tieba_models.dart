const _avatarHost =
    'https://gss0.bdstatic.com/6LZ1dD3d1sgCo2Kml5_Y_D3/sys/portrait/item/';
const _emojiHost = 'https://tb3.bdstatic.com/emoji/';

String tiebaAvatarUrl(String? portrait) {
  final value = (portrait ?? '').trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value.replaceFirst('http://', 'https://');
  }
  return '$_avatarHost$value';
}

String tiebaEmojiUrl(String code) {
  final match = RegExp(r'^image_emoticon(\d+)$').firstMatch(code);
  return match == null ? '' : '${_emojiHost}image_editoricon${match.group(1)}@2x.png';
}

String tiebaFormatCount(dynamic value) {
  final amount = (value is num) ? value.toDouble() : double.tryParse('$value') ?? 0;
  String trim(double value) =>
      value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  if (amount >= 100000000) return '${trim(amount / 100000000)}亿';
  if (amount >= 10000) return '${trim(amount / 10000)}W';
  return '${amount.round()}';
}

/// Tieba JSON mixes numbers and numeric strings between endpoints.
int tiebaInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value == null) return 0;
  return int.tryParse('$value') ?? 0;
}

int tiebaFirstInt(dynamic first, dynamic second) {
  final value = tiebaInt(first);
  return value != 0 ? value : tiebaInt(second);
}

String tiebaFormatTime(dynamic value) {
  if (value == null || '$value'.isEmpty) return '';
  if (value is String && !RegExp(r'^\d+$').hasMatch(value)) return value;
  var num = int.tryParse('$value') ?? 0;
  if (num == 0) return '';
  if (num < 100000000000) num *= 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(num);
  final diff = DateTime.now().difference(date);
  if (!diff.isNegative && diff.inMinutes < 1) return '刚刚';
  if (!diff.isNegative && diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (!diff.isNegative && diff.inDays < 1) return '${diff.inHours}小时前';
  final now = DateTime.now();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  if (date.year == now.year) return '$month-$day';
  return '${date.year}-$month-$day';
}

String tiebaFormatFullTime(dynamic value) {
  if (value == null || '$value'.isEmpty) return '';
  var num = int.tryParse('$value') ?? 0;
  if (num == 0) return '$value';
  if (num < 100000000000) num *= 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(num);
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}

class TiebaUser {
  TiebaUser({
    this.id = 0,
    this.name = '贴吧用户',
    this.account = '',
    this.avatar = '',
    this.portraitRaw = '',
    this.hasConcerned = false,
    this.level = 0,
    this.levelName = '',
    this.isBawu = false,
    this.bawuText = '',
    this.ip = '',
    this.gender = 0,
    this.intro = '',
    this.fansNum = 0,
    this.concernNum = 0,
    this.postNum = 0,
  });

  int id;
  String name;
  String account;
  String avatar;
  String portraitRaw;
  bool hasConcerned;
  int level;
  String levelName;
  bool isBawu;
  String bawuText;
  String ip;
  int gender;
  String intro;
  int fansNum;
  int concernNum;
  int postNum;
}

TiebaUser mapTiebaUser(Map? user) {
  if (user == null) return TiebaUser();
  final isBawu = '${user['is_bawu'] ?? 0}' == '1';
  final grade = user['bazhu_grade'];
  final bawuDesc = grade is Map ? '${grade['desc'] ?? ''}' : '';
  var bawuText = '';
  if (bawuDesc.contains('吧主')) {
    bawuText = '吧主';
  } else if (isBawu) {
    bawuText = '吧务';
  }
  final accountName = '${user['name'] ?? user['user_name'] ?? ''}'.trim();
  final shownName =
      '${user['name_show'] ?? user['show_nickname'] ?? user['user_nickname'] ?? ''}'.trim();
  final display = (shownName.isNotEmpty ? shownName : accountName).trim();
  return TiebaUser(
    id: tiebaFirstInt(user['id'], user['user_id']),
    name: display.isEmpty ? '贴吧用户' : display,
    account: accountName.isNotEmpty && accountName != display ? accountName : '',
    avatar: tiebaAvatarUrl('${user['portrait'] ?? user['user_portrait'] ?? ''}'),
    portraitRaw: '${user['portrait'] ?? ''}',
    hasConcerned: user['has_concerned'] == true ||
        '${user['has_concerned'] ?? 0}' == '1' ||
        user['is_followed'] == true ||
        '${user['is_followed'] ?? 0}' == '1',
    level: tiebaInt(user['level_id']),
    levelName: '${user['level_name'] ?? ''}',
    isBawu: isBawu,
    bawuText: bawuText,
    ip: '${user['ip_address'] ?? ''}',
    gender: tiebaFirstInt(user['gender'], user['sex']),
    intro: '${user['intro'] ?? ''}',
    fansNum: tiebaInt(user['fans_num']),
    concernNum: tiebaInt(user['concern_num']),
    postNum: tiebaInt(user['post_num']),
  );
}

Map<int, TiebaUser> buildTiebaUserMap(List? userList) {
  final map = <int, TiebaUser>{};
  for (final user in (userList ?? const [])) {
    if (user is Map && (user['id'] != null || user['user_id'] != null)) {
      final item = mapTiebaUser(user);
      if (item.id != 0) map[item.id] = item;
    }
  }
  return map;
}

class TiebaForum {
  TiebaForum({
    this.id = 0,
    this.name = '成都航空职业技术大学',
    this.avatar = '',
    this.slogan = '',
    this.memberNum = 0,
    this.postNum = 0,
    this.threadNum = 0,
    this.isLiked = false,
    this.showInfo = '',
    this.goodClassify = const [],
  });

  int id;
  String name;
  String avatar;
  String slogan;
  int memberNum;
  int postNum;
  int threadNum;
  bool isLiked;
  String showInfo;
  List<({int id, String name})> goodClassify;
}

TiebaForum mapTiebaForum(Map? forum) {
  if (forum == null) return TiebaForum();
  final good = <({int id, String name})>[];
  if (forum['good_classify'] is List) {
    for (final item in forum['good_classify'] as List) {
      if (item is Map) {
        good.add((
          id: tiebaInt(item['class_id']),
          name: '${item['class_name'] ?? ''}',
        ));
      }
    }
  }
  return TiebaForum(
    id: tiebaInt(forum['id']),
    name: '${forum['name'] ?? '成都航空职业技术大学'}',
    avatar: tiebaAvatarUrl('${forum['avatar'] ?? ''}'),
    slogan: '${forum['slogan'] ?? ''}',
    memberNum: tiebaInt(forum['member_num']),
    postNum: tiebaInt(forum['post_num']),
    threadNum: tiebaInt(forum['thread_num']),
    isLiked: '${forum['is_like'] ?? 0}' == '1',
    showInfo: forum['show_info'] is Map ? '${(forum['show_info'] as Map)['content'] ?? ''}' : '',
    goodClassify: good,
  );
}

class TiebaImage {
  const TiebaImage({
    required this.thumb,
    required this.url,
    this.big = '',
    this.width = 0,
    this.height = 0,
    this.picId = 0,
  });

  final String thumb;
  final String url;
  final String big;
  final int width;
  final int height;
  final int picId;
}

class TiebaThread {
  TiebaThread({
    required this.tid,
    required this.title,
    required this.author,
    required this.authorId,
    required this.replyCount,
    required this.viewCount,
    required this.agreeCount,
    required this.lastTime,
    required this.isTop,
    required this.isGood,
    required this.preview,
    required this.images,
    this.forumName = '',
    this.forumId = 0,
    this.hotNum = 0,
  });

  int tid;
  String title;
  TiebaUser author;
  int authorId;
  int replyCount;
  int viewCount;
  int agreeCount;
  String lastTime;
  bool isTop;
  bool isGood;
  String preview;
  List<TiebaImage> images;
  String forumName;
  int forumId;
  int hotNum;
}

String _previewText(List? content, [int maxLength = 120]) {
  var text = '';
  for (final node in content ?? const []) {
    if (node is Map && '${node['type'] ?? ''}' == '0' && node['text'] != null) {
      text += '${node['text']}';
    }
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > maxLength ? '${text.substring(0, maxLength)}…' : text;
}

List<TiebaImage> _mapMedia(List? media) {
  if (media == null) return [];
  final list = <TiebaImage>[];
  for (final item in media) {
    if (item is! Map) continue;
    final thumb = '${item['small_pic'] ?? item['big_pic'] ?? item['water_pic'] ?? item['cdn_src'] ?? ''}';
    final full = '${item['big_pic'] ?? item['water_pic'] ?? item['small_pic'] ?? item['cdn_src'] ?? ''}';
    if (thumb.isEmpty && full.isEmpty) continue;
    list.add(TiebaImage(thumb: thumb, url: full));
  }
  return list;
}

TiebaThread? mapTiebaThread(Map? thread, Map<int, TiebaUser> users) {
  if (thread == null) return null;
  final authorId = tiebaInt(thread['author_id']);
  final author = users[authorId] ?? mapTiebaUser(thread['author'] is Map ? thread['author'] as Map : null);
  return TiebaThread(
    tid: tiebaFirstInt(thread['id'], thread['tid']),
    title: _stripTags('${thread['title'] ?? thread['abstract'] ?? '无标题'}'),
    author: author,
    authorId: authorId,
    replyCount: tiebaInt(thread['reply_num']),
    viewCount: tiebaInt(thread['view_num']),
    agreeCount: tiebaInt(thread['agree_num']),
    lastTime: '${thread['last_time'] ?? tiebaFormatTime(thread['last_time_int'] ?? thread['create_time'])}',
    isTop: '${thread['is_top'] ?? 0}' == '1',
    isGood: '${thread['is_good'] ?? 0}' == '1',
    preview: _previewText(thread['first_post_content'] is List ? thread['first_post_content'] as List : thread['rich_abstract'] is List ? thread['rich_abstract'] as List : null),
    images: _mapMedia(thread['media'] is List ? thread['media'] as List : null),
    forumName: thread['forum_info'] is Map ? '${(thread['forum_info'] as Map)['name'] ?? ''}' : '',
    forumId: thread['forum_info'] is Map
        ? tiebaInt((thread['forum_info'] as Map)['id'])
        : tiebaInt(thread['forum_id']),
  );
}

String _stripTags(String raw) => raw
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

TiebaThread? mapTiebaProtoThread(Map? item) {
  if (item == null || item['tid'] == null) return null;
  final rawUser = item['author'] is Map ? item['author'] as Map : const {};
  final images = <TiebaImage>[];
  if (item['images'] is List) {
    for (final image in item['images'] as List) {
      if (image is Map) {
        images.add(
          TiebaImage(
            thumb: '${image['url'] ?? ''}',
            url: '${image['big'] ?? image['url'] ?? ''}',
            width: tiebaInt(image['width']),
            height: tiebaInt(image['height']),
          ),
        );
      }
    }
  }
  return TiebaThread(
    tid: tiebaFirstInt(item['tid'], item['id']),
    title: _stripTags('${item['title'] ?? '无标题'}'),
    author: TiebaUser(
      name: '${rawUser['nameShow'] ?? rawUser['name'] ?? '贴吧用户'}',
      avatar: tiebaAvatarUrl('${rawUser['portrait'] ?? ''}'),
      levelName: '${rawUser['levelName'] ?? ''}',
    ),
    authorId: 0,
    replyCount: tiebaInt(item['replyCount']),
    viewCount: 0,
    agreeCount: tiebaInt(item['agreeCount']),
    lastTime: tiebaFormatTime(item['lastTimeInt'] ?? item['createTime']),
    isTop: false,
    isGood: false,
    preview: _stripTags('${item['abstractText'] ?? ''}'),
    images: images,
    forumName: '${item['forumName'] ?? ''}',
    forumId: tiebaInt(item['forumId']),
    hotNum: tiebaInt(item['hotNum']),
  );
}

class TiebaInline {
  const TiebaInline.text(this.text, {this.accent = false, this.link = ''}) : emoji = '';
  const TiebaInline.emoji(this.emoji) : text = '', accent = false, link = '';

  final String text;
  final String emoji;
  final bool accent;
  final String link;
}

class TiebaVideo {
  const TiebaVideo({
    required this.pageUrl,
    required this.playUrl,
    required this.cover,
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });

  final String pageUrl;
  final String playUrl;
  final String cover;
  final int width;
  final int height;
  final int duration;
}

class TiebaContentBlock {
  const TiebaContentBlock({
    this.inlines = const [],
    this.images = const [],
    this.videos = const [],
  });

  final List<TiebaInline> inlines;
  final List<TiebaImage> images;
  final List<TiebaVideo> videos;
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

List<TiebaContentBlock> tiebaContentBlocks(List? content) {
  final blocks = <TiebaContentBlock>[];
  var inlines = <TiebaInline>[];
  var images = <TiebaImage>[];

  void flushText() {
    if (inlines.isNotEmpty) {
      blocks.add(TiebaContentBlock(inlines: inlines));
      inlines = [];
    }
  }

  void flushImages() {
    if (images.isNotEmpty) {
      blocks.add(TiebaContentBlock(images: images));
      images = [];
    }
  }

  for (final node in content ?? const []) {
    if (node is! Map) continue;
    final type = tiebaInt(node['type']);
    if (type == 3) {
      flushText();
      final url = '${node['cdn_src_active'] ?? node['cdn_src'] ?? node['big_cdn_src'] ?? node['origin_src'] ?? ''}';
      final big = '${node['big_cdn_src'] ?? node['origin_src'] ?? node['cdn_src'] ?? url}';
      if (url.isNotEmpty) {
        final size = '${node['bsize'] ?? ''}'.split(',');
        images.add(
          TiebaImage(
            thumb: url,
            url: url,
            big: big,
            width: size.isNotEmpty ? int.tryParse(size[0]) ?? 0 : 0,
            height: size.length > 1 ? int.tryParse(size[1]) ?? 0 : 0,
            picId: tiebaInt(node['pic_id']),
          ),
        );
      }
      continue;
    }
    if (type == 5) {
      flushText();
      flushImages();
      final pageUrl = '${node['text'] ?? ''}';
      final playUrl = '${node['link'] ?? ''}';
      final cover = '${node['src'] ?? node['thumbnail'] ?? ''}';
      if (pageUrl.isNotEmpty || playUrl.isNotEmpty) {
        final size = '${node['bsize'] ?? ''}'.split(',');
        final width = size.isNotEmpty ? int.tryParse(size[0]) ?? 0 : 0;
        final height = size.length > 1 ? int.tryParse(size[1]) ?? 0 : 0;
        final duration = tiebaInt(node['during_time']);
        blocks.add(TiebaContentBlock(
          videos: [
            TiebaVideo(
              pageUrl: pageUrl,
              playUrl: playUrl,
              cover: cover,
              width: width > 0 ? width : tiebaInt(node['width']),
              height: height > 0 ? height : tiebaInt(node['height']),
              duration: duration,
            ),
          ],
        ));
      }
      continue;
    }
    flushImages();
    if (type == 2) {
      final code = '${node['text'] ?? ''}';
      final emoji = tiebaEmojiUrl(code);
      if (emoji.isNotEmpty) {
        inlines.add(TiebaInline.emoji(emoji));
      } else if (node['c'] != null) {
        inlines.add(TiebaInline.text('[${node['c']}]', accent: true));
      }
      continue;
    }
    if (type == 1) {
      final rawLink = '${node['link'] ?? ''}';
      final text = '${node['text'] ?? node['title'] ?? rawLink}';
      if (text.isNotEmpty) {
        inlines.add(TiebaInline.text(
          text,
          link: rawLink.startsWith('http') ? rawLink : '',
        ));
      }
      continue;
    }
    if (type == 4) {
      final text = '${node['text'] ?? (node['c'] != null ? '@${node['c']}' : '')}';
      if (text.isNotEmpty) inlines.add(TiebaInline.text(text, accent: true));
      continue;
    }
    if (node['text'] != null) inlines.add(TiebaInline.text('${node['text']}'));
  }
  flushText();
  flushImages();
  return blocks;
}

class TiebaPost {
  TiebaPost({
    required this.id,
    required this.floor,
    required this.title,
    required this.author,
    required this.authorId,
    required this.time,
    required this.blocks,
    required this.images,
    required this.agreeCount,
    required this.hasAgreed,
    required this.subPostNumber,
  });

  int id;
  int floor;
  String title;
  TiebaUser author;
  int authorId;
  int time;
  List<TiebaContentBlock> blocks;
  List<TiebaImage> images;
  int agreeCount;
  bool hasAgreed;
  int subPostNumber;
  List<TiebaSubPost> subPosts = [];
  bool subsLoaded = false;
  bool subsLoading = false;
  bool subsExpanded = false;
  int subsPage = 1;
  bool subsMoreLoading = false;
}

TiebaPost? mapTiebaPost(Map? post, Map<int, TiebaUser> users) {
  if (post == null) return null;
  final authorId = tiebaInt(post['author_id']);
  final blocks = tiebaContentBlocks(post['content'] is List ? post['content'] as List : null);
  final images = blocks.expand((block) => block.images).toList();
  final agree = post['agree'] is Map ? post['agree'] as Map : const {};
  return TiebaPost(
    id: tiebaInt(post['id']),
    floor: tiebaInt(post['floor']),
    title: '${post['title'] ?? ''}',
    author: users[authorId] ?? mapTiebaUser(post['author'] is Map ? post['author'] as Map : null),
    authorId: authorId,
    time: tiebaInt(post['time']),
    blocks: blocks,
    images: images,
    agreeCount: tiebaInt(agree['agree_num']),
    hasAgreed: '${agree['has_agree'] ?? 0}' == '1',
    subPostNumber: tiebaInt(post['sub_post_number']),
  );
}

class TiebaSubPost {
  TiebaSubPost({
    required this.id,
    required this.author,
    required this.authorId,
    required this.time,
    required this.inlines,
    required this.images,
    this.agreeCount = 0,
    this.hasAgreed = false,
  });

  int id;
  TiebaUser author;
  int authorId;
  int time;
  List<TiebaInline> inlines;
  List<TiebaImage> images;
  int agreeCount;
  bool hasAgreed;
}

TiebaSubPost? mapTiebaSubPost(Map? sub, Map<int, TiebaUser> users) {
  if (sub == null) return null;
  final authorId = tiebaInt(sub['author_id']);
  final blocks = tiebaContentBlocks(sub['content'] is List ? sub['content'] as List : null);
  final inlines = <TiebaInline>[
    for (final block in blocks) ...block.inlines,
  ];
  final agree = sub['agree'] is Map ? sub['agree'] as Map : const {};
  return TiebaSubPost(
    id: tiebaInt(sub['id']),
    author: users[authorId] ?? mapTiebaUser(sub['author'] is Map ? sub['author'] as Map : null),
    authorId: authorId,
    time: tiebaInt(sub['time']),
    inlines: inlines,
    images: blocks.expand((block) => block.images).toList(),
    agreeCount: tiebaInt(agree['agree_num']),
    hasAgreed: '${agree['has_agree'] ?? 0}' == '1',
  );
}

class TiebaThreadPage {
  TiebaThreadPage({
    required this.forum,
    required this.threadTitle,
    required this.posts,
    required this.replies,
    required this.firstPost,
    required this.collectStatus,
  });

  TiebaForum forum;
  String threadTitle;
  List<TiebaPost> posts;
  List<TiebaPost> replies;
  TiebaPost? firstPost;
  int collectStatus;
}

TiebaThreadPage mapTiebaThreadPage(Map<String, dynamic> json) {
  final users = buildTiebaUserMap(json['user_list'] is List ? json['user_list'] as List : null);
  final posts = (json['post_list'] as List? ?? const [])
      .whereType<Map>()
      .map((e) => mapTiebaPost(e, users))
      .whereType<TiebaPost>()
      .toList()
    ..sort((a, b) => a.floor.compareTo(b.floor));
  final first = posts.where((post) => post.floor == 1).firstOrNull ?? posts.firstOrNull;
  return TiebaThreadPage(
    forum: mapTiebaForum(json['forum'] is Map ? json['forum'] as Map : null),
    threadTitle: first?.title ?? '',
    posts: posts,
    replies: posts.where((post) => post != first).toList(),
    firstPost: first,
    collectStatus: json['thread'] is Map ? tiebaInt((json['thread'] as Map)['collect_status']) : 0,
  );
}

class TiebaSearchForum {
  TiebaSearchForum({
    required this.id,
    required this.name,
    required this.avatar,
    required this.slogan,
    required this.concernNum,
    required this.postNum,
    required this.isLiked,
  });

  int id;
  String name;
  String avatar;
  String slogan;
  String concernNum;
  String postNum;
  bool isLiked;
}

TiebaSearchForum mapTiebaSearchForum(Map raw) => TiebaSearchForum(
  id: tiebaFirstInt(raw['forum_id'], raw['id']),
  name: '${raw['forum_name'] ?? raw['forum_name_show'] ?? raw['name'] ?? '贴吧'}',
  avatar: tiebaAvatarUrl('${raw['avatar'] ?? ''}'),
  slogan: '${raw['slogan'] ?? raw['intro'] ?? ''}',
  concernNum: '${raw['concern_num'] ?? raw['concern_num_ori'] ?? ''}',
  postNum: '${raw['post_num'] ?? raw['post_num_ori'] ?? ''}',
  isLiked: raw['has_concerned'] == true ||
      '${raw['has_concerned'] ?? 0}' == '1' ||
      raw['is_like'] == true,
);

class TiebaSearchThread {
  TiebaSearchThread({
    required this.tid,
    required this.title,
    required this.content,
    required this.forumName,
    required this.forumId,
    required this.author,
    required this.time,
    required this.replyCount,
    required this.agreeCount,
  });

  int tid;
  String title;
  String content;
  String forumName;
  int forumId;
  TiebaUser author;
  int time;
  int replyCount;
  int agreeCount;
}

TiebaSearchThread mapTiebaSearchThread(Map raw) {
  final forum = raw['forum_info'] is Map ? raw['forum_info'] as Map : const {};
  return TiebaSearchThread(
    tid: tiebaFirstInt(raw['tid'], raw['thread_id']),
    title: _stripTags('${raw['title'] ?? '无标题'}'),
    content: _stripTags('${raw['content'] ?? ''}'),
    forumName: '${raw['fname'] ?? forum['forum_name'] ?? ''}',
    forumId: tiebaFirstInt(raw['fid'], forum['forum_id']),
    author: mapTiebaUser(raw['user'] is Map ? raw['user'] as Map : null),
    time: tiebaInt(raw['time']),
    replyCount: tiebaFirstInt(raw['post_num'], raw['reply_num']),
    agreeCount: tiebaFirstInt(raw['like_num'], raw['agree_num']),
  );
}

class TiebaFollowedForum {
  TiebaFollowedForum({
    required this.forumId,
    required this.forumName,
    required this.avatar,
    required this.level,
    required this.levelName,
    required this.isSign,
  });

  int forumId;
  String forumName;
  String avatar;
  int level;
  String levelName;
  bool isSign;
}

TiebaFollowedForum mapTiebaFollowedForum(Map raw) => TiebaFollowedForum(
  forumId: tiebaFirstInt(raw['forum_id'], raw['id']),
  forumName: '${raw['forum_name'] ?? raw['name'] ?? ''}',
  avatar: tiebaAvatarUrl('${raw['avatar'] ?? ''}'),
  level: tiebaInt(raw['level_id']),
  levelName: '${raw['level_name'] ?? ''}',
  isSign: raw['is_sign'] == true || '${raw['is_sign'] ?? 0}' == '1',
);

class TiebaStoreThread {
  TiebaStoreThread({
    required this.threadId,
    required this.title,
    required this.forumName,
    required this.author,
    required this.isDeleted,
    required this.count,
  });

  int threadId;
  String title;
  String forumName;
  TiebaUser author;
  bool isDeleted;
  int count;
}

TiebaStoreThread mapTiebaStoreThread(Map raw) => TiebaStoreThread(
  threadId: tiebaInt(raw['thread_id']),
  title: _stripTags('${raw['title'] ?? '无标题'}'),
  forumName: '${raw['forum_name'] ?? ''}',
  author: mapTiebaUser(raw['author'] is Map ? raw['author'] as Map : null),
  isDeleted: raw['is_deleted'] == true || '${raw['is_deleted'] ?? 0}' == '1',
  count: tiebaInt(raw['count']),
);

String tiebaEscapeHtml(String value) => _escapeHtml(value);