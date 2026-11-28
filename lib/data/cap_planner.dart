import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../utils/cap_date.dart';

class PlannerTask {
  PlannerTask({
    required this.title,
    this.note = '',
    this.dueDate = '',
    this.tags = const [],
    this.source = 'local',
    this.selected = true,
  });

  String title;
  String note;
  String dueDate;
  List<String> tags;
  String source;
  bool selected;
}

class PlannerResult {
  PlannerResult({
    required this.ok,
    this.tasks = const [],
    this.source = 'local',
    this.notice = '',
    this.error = '',
  });

  final bool ok;
  final List<PlannerTask> tasks;
  final String source;
  final String notice;
  final String error;
}

class _Template {
  const _Template(this.category, this.tasks);

  final String category;
  final List<List<String>> tasks;
}

_Template _templatesFor(String goal) {
  final text = goal.toLowerCase();
  if (RegExp(r'四级|cet-?4|六级|cet-?6|雅思|托福|考研英语|英语').hasMatch(text)) {
    return const _Template('英语备考', [
      ['明确考试目标与当前水平', '记录目标分数、考试日期，做一次摸底并记下薄弱项'],
      ['准备近五年真题与高频词表', '整理真题、听力音频和错题本，确定每周固定学习时段'],
      ['完成第一轮高频词与长难句', '每天 30 个高频词，配合 2 个长难句拆解'],
      ['精听两套真题听力', '逐句听写并跟读，整理连读和同义替换'],
      ['限时完成两套阅读', '记录每篇用时与错题原因，复盘定位句'],
      ['各完成两篇写作与翻译', '对照范文修改，积累可迁移的句型和表达'],
      ['进行一次全真模拟', '按考试时间完整做一套题，整理最后一周复习清单'],
    ]);
  }
  if (RegExp(r'健身|减脂|增肌|跑步|马拉松|体测|运动').hasMatch(text)) {
    return const _Template('运动计划', [
      ['确定可量化的身体目标', '记录当前体重/围度/配速，选定一个 4 周后可验证的指标'],
      ['排出每周三次训练时间', '把训练写进日历，优先选择能坚持的时段'],
      ['完成第一次基础训练', '从低强度开始，记录动作、组数和身体感受'],
      ['准备一周的饮食与补水', '规划三餐和训练前后补给，减少临时决策'],
      ['完成本周第三次训练', '逐步增加一点强度，结束后做 10 分钟拉伸'],
      ['记录一周数据并复盘', '对比体重、围度和训练完成度，调整下周计划'],
    ]);
  }
  if (RegExp(r'论文|毕业设计|项目|作品集|设计|开发|比赛|答辩').hasMatch(text)) {
    return const _Template('项目推进', [
      ['写清楚最终交付物与验收标准', '用三句话说明要交什么、给谁看、怎样算完成'],
      ['收集资料并建立参考清单', '整理 5 个高质量参考，标注可借鉴的部分'],
      ['搭出目录或功能骨架', '先完成结构，不急着打磨细节'],
      ['完成第一版粗稿', '允许不完美，把核心内容全部落下来'],
      ['找一次外部反馈', '请同学或老师指出最影响完成度的三个问题'],
      ['根据反馈完成第二轮修改', '逐条处理反馈，并记录取舍'],
      ['做最终检查并提交', '检查格式、命名、引用和交付入口'],
    ]);
  }
  if (RegExp(r'旅行|旅游|出游|出发|行程|露营').hasMatch(text)) {
    return const _Template('旅行准备', [
      ['确定目的地与预算上限', '把交通、住宿、餐饮和门票写进一个总预算'],
      ['排出三天核心行程', '只安排每天两个重点，其余留白'],
      ['订好往返交通', '确认时间、退改规则和到达后的接驳方式'],
      ['订好住宿并保存地址', '核对入住时间、位置和紧急联系方式'],
      ['整理证件与随身清单', '身份证、学生证、充电器、常用药和雨具'],
      ['出发前检查天气与通知', '确认天气、课程请假和重要联系人'],
    ]);
  }
  if (RegExp(r'生日|纪念日|礼物|表白|聚会').hasMatch(text)) {
    return const _Template('重要日子', [
      ['确定日子与参与的人', '确认时间、地点和对方真正想要的庆祝方式'],
      ['准备一份有心意的礼物', '设定预算，提前下单或亲手准备'],
      ['预订餐厅或场地', '确认人数、时间和是否需要定金'],
      ['写一张卡片', '写下一个具体的小回忆和想说的话'],
      ['当天提前确认一次', '确认时间、路线和所有准备工作'],
    ]);
  }
  return const _Template('目标拆解', [
    ['写清楚这件事的完成标准', '用一句话描述做完时是什么样子，尽量可验证'],
    ['找到最小可执行的第一步', '把第一步压缩到 25 分钟内可以开始'],
    ['收集必要的资料和工具', '只找当前这一步需要的东西，避免无限准备'],
    ['完成一个 25 分钟专注块', '先做出一个粗糙版本，不评价、不返工'],
    ['处理最难的一个环节', '把最不想做的部分提前，拆成更小的动作'],
    ['请一个人帮你检查', '获得一次具体反馈，而不是泛泛的评价'],
    ['收尾并记录下一步', '整理成果，写下一个可以继续的小动作'],
  ]);
}

DateTime? _clampDeadline(String deadline) {
  final date = parseDateKey(deadline);
  if (date == null) return null;
  final today = startOfDay(DateTime.now());
  if (date.isBefore(today)) return null;
  return date;
}

List<String> _dueDates(int count, String deadline) {
  final base = startOfDay(DateTime.now());
  final end = _clampDeadline(deadline) ?? base.add(const Duration(days: 14));
  final span = math.max(1, end.difference(base).inDays);
  return [
    for (var index = 0; index < count; index += 1)
      formatDateKey(
        base.add(
          Duration(
            days: math.max(
              1,
              math.min(
                span,
                (span * (count <= 1 ? 1 : (index + 1) / count)).round(),
              ),
            ),
          ),
        ),
      ),
  ];
}

List<PlannerTask> localBreakdown(String goal, {String deadline = ''}) {
  final clean = goal.trim();
  if (clean.isEmpty) return [];
  final template = _templatesFor(clean);
  final dates = _dueDates(template.tasks.length, deadline);
  return [
    for (var i = 0; i < template.tasks.length; i += 1)
      PlannerTask(
        title: template.tasks[i][0],
        note: template.tasks[i][1],
        dueDate: dates[i],
        tags: [template.category],
      ),
  ];
}

List<dynamic>? _parseAiPayload(String text) {
  var content = text.trim();
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
  if (fenced != null) content = fenced.group(1)!.trim();
  final first = content.indexOf('{');
  final last = content.lastIndexOf('}');
  if (first >= 0 && last > first) content = content.substring(first, last + 1);
  try {
    final parsed = jsonDecode(content);
    if (parsed is List) return parsed;
    if (parsed is Map && parsed['tasks'] is List) {
      return parsed['tasks'] as List;
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<PlannerResult> _remoteBreakdown({
  required String goal,
  required String deadline,
  required Map<String, dynamic> settings,
}) async {
  final ai = settings['ai'] is Map
      ? Map<String, dynamic>.from(settings['ai'] as Map)
      : <String, dynamic>{};
  if (ai['enabled'] != true ||
      '${ai['baseUrl'] ?? ''}'.isEmpty ||
      '${ai['model'] ?? ''}'.isEmpty) {
    return PlannerResult(ok: false, error: '尚未配置大模型');
  }
  final base = '${ai['baseUrl']}'.replaceAll(RegExp(r'/+$'), '');
  final url = base.endsWith('/chat/completions')
      ? base
      : '$base/chat/completions';
  final prompt = [
    '你是 CapuLife 的任务规划助手。',
    '请把用户的大目标拆成 5-8 个清晰、可执行、按顺序推进的子任务。',
    '只返回 JSON，格式为 {"tasks":[{"title":"...","note":"...","dueDate":"YYYY-MM-DD","tags":["..."]}]}。',
    '不要输出 Markdown，不要输出解释。任务必须具体、短小，避免空泛鼓励。',
    '今天：${formatDateKey()}',
    if (deadline.isNotEmpty) '截止日期：$deadline' else '没有明确截止日期，请把任务安排在未来两周内',
    '大目标：$goal',
  ].join('\n');

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 45);
  try {
    final request = await client.postUrl(Uri.parse(url));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer ${ai['apiKey'] ?? ''}');
    request.write(
      jsonEncode({
        'model': ai['model'],
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': '你只输出合法 JSON，不输出任何多余文字。'},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    final response = await request.close().timeout(const Duration(seconds: 45));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return PlannerResult(ok: false, error: '模型接口返回 ${response.statusCode}');
    }
    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(body);
    } catch (_) {
      decodedBody = body;
    }
    final content =
        decodedBody is Map &&
            decodedBody['choices'] is List &&
            (decodedBody['choices'] as List).isNotEmpty &&
            (decodedBody['choices'] as List).first is Map &&
            ((decodedBody['choices'] as List).first as Map)['message'] is Map
        ? '${(((decodedBody['choices'] as List).first as Map)['message'] as Map)['content'] ?? ''}'
        : decodedBody is String
        ? decodedBody
        : jsonEncode(decodedBody);
    final list = _parseAiPayload(content);
    if (list == null || list.isEmpty) {
      return PlannerResult(ok: false, error: '模型没有返回可解析的任务，请换一种说法重试');
    }
    final tasks = <PlannerTask>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final title = '${raw['title'] ?? raw['task'] ?? raw['content'] ?? ''}'.trim();
      if (title.isEmpty) continue;
      final tagsRaw = raw['tags'];
      tasks.add(
        PlannerTask(
          title: title.length > 80 ? title.substring(0, 80) : title,
          note: '${raw['note'] ?? raw['description'] ?? ''}'.trim(),
          dueDate: '${raw['dueDate'] ?? raw['date'] ?? ''}',
          tags: tagsRaw is List
              ? tagsRaw.take(3).map((e) => '$e').toList()
              : const ['AI 拆解'],
          source: 'ai',
        ),
      );
    }
    if (tasks.isEmpty) {
      return PlannerResult(ok: false, error: '模型返回了空任务列表');
    }
    return PlannerResult(ok: true, tasks: tasks.take(10).toList(), source: 'ai');
  } catch (error) {
    return PlannerResult(ok: false, error: '$error');
  } finally {
    client.close(force: true);
  }
}

Future<PlannerResult> decomposeGoal({
  required String goal,
  required String deadline,
  required Map<String, dynamic> settings,
}) async {
  final clean = goal.trim();
  if (clean.isEmpty) {
    return PlannerResult(ok: false, error: '先写下想完成的大目标');
  }
  final ai = settings['ai'] is Map
      ? settings['ai'] as Map
      : const <String, dynamic>{};
  if (ai['enabled'] == true &&
      '${ai['baseUrl'] ?? ''}'.isNotEmpty &&
      '${ai['model'] ?? ''}'.isNotEmpty) {
    final remote = await _remoteBreakdown(
      goal: clean,
      deadline: deadline,
      settings: settings,
    );
    if (remote.ok) return remote;
    return PlannerResult(
      ok: true,
      tasks: localBreakdown(clean, deadline: deadline),
      source: 'local',
      notice: remote.error.isEmpty ? '在线模型暂不可用，已改用本地智能拆解' : remote.error,
    );
  }
  return PlannerResult(
    ok: true,
    tasks: localBreakdown(clean, deadline: deadline),
    source: 'local',
  );
}
