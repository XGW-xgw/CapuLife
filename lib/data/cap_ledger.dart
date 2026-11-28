import 'dart:math' as math;

import '../utils/cap_date.dart';

/// The original app stores every ledger value in cents with a local-time
/// accounting month. These helpers are a direct port of `src/utils/ledger.js`.
const ledgerCategoriesSeed = <Map<String, Object>>[
  {'id': 'cat_food', 'name': '餐饮', 'type': 'expense', 'icon': 'utensils', 'color': '#B5762C'},
  {'id': 'cat_transport', 'name': '交通', 'type': 'expense', 'icon': 'bus', 'color': '#2C5BC7'},
  {'id': 'cat_shopping', 'name': '购物', 'type': 'expense', 'icon': 'tag', 'color': '#8E5CA0'},
  {'id': 'cat_daily', 'name': '日用', 'type': 'expense', 'icon': 'layers', 'color': '#2C8069'},
  {'id': 'cat_home', 'name': '居住', 'type': 'expense', 'icon': 'home', 'color': '#255E6B'},
  {'id': 'cat_fun', 'name': '娱乐', 'type': 'expense', 'icon': 'music', 'color': '#C25E49'},
  {'id': 'cat_health', 'name': '医疗', 'type': 'expense', 'icon': 'heart', 'color': '#B04A5A'},
  {'id': 'cat_study', 'name': '学习', 'type': 'expense', 'icon': 'book-open', 'color': '#815317'},
  {'id': 'cat_social', 'name': '人情', 'type': 'expense', 'icon': 'users', 'color': '#6A3B7A'},
  {'id': 'cat_other', 'name': '其他', 'type': 'expense', 'icon': 'folder', 'color': '#747B82'},
  {'id': 'inc_living', 'name': '生活费', 'type': 'income', 'icon': 'wallet', 'color': '#2C8069'},
  {'id': 'inc_salary', 'name': '工资', 'type': 'income', 'icon': 'wallet', 'color': '#2C5BC7'},
  {'id': 'inc_part', 'name': '兼职', 'type': 'income', 'icon': 'timer', 'color': '#815317'},
  {'id': 'inc_scholar', 'name': '奖学金', 'type': 'income', 'icon': 'star', 'color': '#B5762C'},
  {'id': 'inc_gift', 'name': '红包', 'type': 'income', 'icon': 'heart', 'color': '#C25E49'},
  {'id': 'inc_refund', 'name': '退款', 'type': 'income', 'icon': 'rotate-ccw', 'color': '#255E6B'},
  {'id': 'inc_other', 'name': '其他', 'type': 'income', 'icon': 'folder', 'color': '#747B82'},
];

const ledgerTones = <String, String>{
  'ok': '充裕',
  'mid': '留意',
  'low': '偏紧',
};

int clampStartDay(num? value) {
  final day = (value ?? 1).round();
  return day.clamp(1, 28);
}

int amountToCents(String? text) {
  final raw = (text ?? '').replaceAll(RegExp(r'[^\d.]'), '');
  if (raw.isEmpty) return 0;
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite || value < 0) return 0;
  return (value * 100).round();
}

String formatMoney(int cents, {bool compact = false, bool sign = false}) {
  final value = cents / 100;
  if (compact && value.abs() >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  final body = parts[1] == '00' && compact ? grouped : '$grouped.${parts[1]}';
  return '${value < 0 ? '-' : sign ? '+' : ''}$body';
}

String formatMoneyCompact(int cents) => formatMoney(cents, compact: true);

class LedgerCategory {
  LedgerCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
    this.builtin = true,
  });

  String id;
  String name;
  String type;
  String icon;
  String color;
  int sortOrder;
  bool builtin;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'icon': icon,
    'color': color,
    'sortOrder': sortOrder,
    'builtin': builtin,
  };

  factory LedgerCategory.fromJson(Map<String, dynamic> json) => LedgerCategory(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    type: '${json['type'] ?? 'expense'}',
    icon: '${json['icon'] ?? 'tag'}',
    color: '${json['color'] ?? '#747B82'}',
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    builtin: json['builtin'] as bool? ?? false,
  );

  factory LedgerCategory.seed(Map<String, Object> json, int index) =>
      LedgerCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        icon: json['icon'] as String,
        color: json['color'] as String,
        sortOrder: index,
      );

  LedgerCategory copy() => LedgerCategory(
    id: id,
    name: name,
    type: type,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
    builtin: builtin,
  );
}

class CapTransaction {
  CapTransaction({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    this.note = '',
    this.payee = '',
    required this.timestamp,
    this.budgetExcluded = false,
    this.aaShares = 0,
    this.source = 'manual',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  String id;
  String type;
  int amountCents;
  String categoryId;
  String note;
  String payee;
  int timestamp;
  bool budgetExcluded;
  int aaShares;
  String source;
  int createdAt;
  int updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amountCents': amountCents,
    'categoryId': categoryId,
    'note': note,
    'payee': payee,
    'timestamp': timestamp,
    'budgetExcluded': budgetExcluded,
    'aaShares': aaShares,
    'source': source,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory CapTransaction.fromJson(Map<String, dynamic> json) => CapTransaction(
    id: '${json['id'] ?? ''}',
    type: json['type'] == 'income' ? 'income' : 'expense',
    amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
    categoryId: '${json['categoryId'] ?? 'cat_food'}',
    note: '${json['note'] ?? ''}',
    payee: '${json['payee'] ?? ''}',
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    budgetExcluded: json['budgetExcluded'] as bool? ?? false,
    aaShares: (json['aaShares'] as num?)?.toInt() ?? 0,
    source: '${json['source'] ?? 'manual'}',
    createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
  );
}

class LedgerPeriod {
  const LedgerPeriod({
    required this.start,
    required this.end,
    required this.nextStart,
    required this.days,
    required this.daysLeft,
    required this.startDay,
    required this.key,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final DateTime nextStart;
  final int days;
  final int daysLeft;
  final int startDay;
  final String key;
  final String label;
}

class CapLedgerSummary {
  const CapLedgerSummary({
    required this.period,
    required this.monthLabel,
    required this.budgetCents,
    required this.spentCents,
    required this.incomeCents,
    required this.excludedCents,
    required this.todaySpentCents,
    required this.remainingCents,
    required this.percent,
    required this.tone,
    required this.dailySuggestCents,
    required this.daysLeft,
    required this.hint,
    required this.count,
    required this.hasBudget,
  });

  final LedgerPeriod period;
  final String monthLabel;
  final int budgetCents;
  final int spentCents;
  final int incomeCents;
  final int excludedCents;
  final int todaySpentCents;
  final int remainingCents;
  final int percent;
  final String tone;
  final int dailySuggestCents;
  final int daysLeft;
  final String hint;
  final int count;
  final bool hasBudget;
}

class CapLedger {
  CapLedger({
    required this.transactions,
    required this.categories,
    required this.budget,
    required this.meta,
    required this.pending,
    required this.merchantRules,
  });

  List<CapTransaction> transactions;
  List<LedgerCategory> categories;
  Map<String, dynamic> budget;
  Map<String, dynamic> meta;
  List<Map<String, dynamic>> pending;
  Map<String, String> merchantRules;

  factory CapLedger.defaults() => CapLedger(
    transactions: [],
    categories: [
      for (var i = 0; i < ledgerCategoriesSeed.length; i += 1)
        LedgerCategory.seed(ledgerCategoriesSeed[i], i),
    ],
    budget: {
      'mode': 'month',
      'monthlyCents': 0,
      'dailyCents': 0,
      'startDay': 1,
    },
    meta: {'lastCategoryId': 'cat_food', 'updatedAt': 0},
    pending: [],
    merchantRules: {},
  );

  factory CapLedger.fromJson(Map<String, dynamic>? json) {
    final base = CapLedger.defaults();
    if (json == null) return base;
    final rawCategories = json['categories'];
    final rawTx = json['transactions'];
    final rawPending = json['pending'];
    final rawRules = json['merchantRules'];
    return CapLedger(
      transactions: rawTx is List
          ? rawTx
                .whereType<Map>()
                .map(
                  (e) => CapTransaction.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : base.transactions,
      categories: rawCategories is List && rawCategories.isNotEmpty
          ? rawCategories
                .whereType<Map>()
                .map(
                  (e) => LedgerCategory.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : base.categories,
      budget: Map<String, dynamic>.from(
        json['budget'] is Map ? json['budget'] as Map : base.budget,
      ),
      meta: Map<String, dynamic>.from(
        json['meta'] is Map ? json['meta'] as Map : base.meta,
      ),
      pending: rawPending is List
          ? rawPending
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : base.pending,
      merchantRules: rawRules is Map
          ? rawRules.map((key, value) => MapEntry('$key', '$value'))
          : base.merchantRules,
    );
  }

  Map<String, dynamic> toJson() => {
    'transactions': transactions.map((item) => item.toJson()).toList(),
    'categories': categories.map((item) => item.toJson()).toList(),
    'budget': budget,
    'meta': meta,
    'pending': pending,
    'merchantRules': merchantRules,
  };

  LedgerCategory? categoryOf(String id) {
    for (final item in categories) {
      if (item.id == id) return item;
    }
    return null;
  }
}

int transactionEffectiveCents(CapTransaction tx) {
  final cents = tx.amountCents.abs();
  if (tx.type != 'expense') return cents;
  if (tx.budgetExcluded) return 0;
  final shares = math.max(0, tx.aaShares.round());
  if (shares > 1) return (cents / shares).round();
  return cents;
}

LedgerPeriod budgetPeriod(Map<String, dynamic> budget, {DateTime? now}) {
  final startDay = clampStartDay((budget['startDay'] as num?)?.toInt());
  final today = startOfDay(now ?? DateTime.now());
  var year = today.year;
  var month = today.month;
  if (today.day < startDay) {
    month -= 1;
    if (month < 1) {
      month = 12;
      year -= 1;
    }
  }
  final start = DateTime(year, month, startDay);
  final nextStart = DateTime(year, month + 1, startDay);
  final end = nextStart.subtract(const Duration(milliseconds: 1));
  final days = math.max(
    1,
    startOfDay(nextStart).difference(start).inDays,
  );
  final daysLeft = math.max(
    0,
    math.min(
      days,
      startOfDay(end).difference(today).inDays + 1,
    ),
  );
  return LedgerPeriod(
    start: start,
    end: end,
    nextStart: nextStart,
    days: days,
    daysLeft: daysLeft,
    startDay: startDay,
    key: formatDateKey(start),
    label: '${start.month} 月 ${start.day} 日起',
  );
}

List<CapTransaction> transactionsInPeriod(
  CapLedger ledger,
  LedgerPeriod period,
) {
  return ledger.transactions.where((tx) {
    final at = tx.timestamp;
    return at >= period.start.millisecondsSinceEpoch &&
        at <= period.end.millisecondsSinceEpoch;
  }).toList();
}

CapLedgerSummary ledgerSummary(CapLedger ledger, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final budget = ledger.budget;
  final period = budgetPeriod(budget, now: current);
  final list = transactionsInPeriod(ledger, period);
  final monthlyCents = math.max(
    0,
    (budget['monthlyCents'] as num?)?.toInt() ?? 0,
  );
  final dailyCents = math.max(0, (budget['dailyCents'] as num?)?.toInt() ?? 0);
  final budgetCents = budget['mode'] == 'daily' && dailyCents > 0
      ? dailyCents * period.days
      : monthlyCents;

  var spentCents = 0;
  var incomeCents = 0;
  var excludedCents = 0;
  var todaySpentCents = 0;
  final todayKey = formatDateKey(current);
  for (final tx in list) {
    if (tx.type == 'income') {
      incomeCents += tx.amountCents.abs();
      continue;
    }
    final effective = transactionEffectiveCents(tx);
    spentCents += effective;
    final raw = tx.amountCents.abs();
    excludedCents += math.max(0, raw - effective);
    if (formatDateKey(
          DateTime.fromMillisecondsSinceEpoch(tx.timestamp),
        ) ==
        todayKey) {
      todaySpentCents += effective;
    }
  }

  final remainingCents = budgetCents > 0 ? budgetCents - spentCents : 0;
  final percent = budgetCents > 0
      ? math.min(100, ((spentCents / budgetCents) * 100).round())
      : 0;
  final remainingRatio = budgetCents > 0 ? remainingCents / budgetCents : 1.0;
  final greenAbove = period.days > 0
      ? math.max(0.0, (period.daysLeft - 1) / period.days)
      : 0.0;
  final redBelow = period.days > 0
      ? period.daysLeft / 2 / period.days
      : 0.0;
  var tone = 'ok';
  if (remainingCents < 0 || remainingRatio < redBelow) {
    tone = 'low';
  } else if (remainingRatio <= greenAbove) {
    tone = 'mid';
  }

  final daysLeft = math.max(1, period.daysLeft);
  final dailySuggestCents = budgetCents > 0
      ? math.max(0, (remainingCents / daysLeft).round())
      : 0;

  var hint = '还没有设置预算，点开记一笔开始';
  if (budgetCents > 0) {
    if (remainingCents < 0) {
      hint = '已超出预算 ${formatMoney(remainingCents.abs())} 元';
    } else if (percent >= 75) {
      hint = '预算已用 $percent%，放慢一点';
    } else {
      hint = '今天最多建议花 ${formatMoney(dailySuggestCents)} 元';
    }
  }

  return CapLedgerSummary(
    period: period,
    monthLabel: '${period.start.year} 年 ${period.start.month} 月',
    budgetCents: budgetCents,
    spentCents: spentCents,
    incomeCents: incomeCents,
    excludedCents: excludedCents,
    todaySpentCents: todaySpentCents,
    remainingCents: remainingCents,
    percent: percent,
    tone: tone,
    dailySuggestCents: dailySuggestCents,
    daysLeft: daysLeft,
    hint: hint,
    count: list.length,
    hasBudget: budgetCents > 0,
  );
}

class LedgerDayGroup {
  const LedgerDayGroup({
    required this.key,
    required this.label,
    required this.weekday,
    required this.totalCents,
    required this.items,
  });

  final String key;
  final String label;
  final String weekday;
  final int totalCents;
  final List<CapTransaction> items;
}

List<LedgerDayGroup> groupTransactionsByDay(
  List<CapTransaction> transactions, {
  DateTime? now,
}) {
  final map = <String, List<CapTransaction>>{};
  for (final tx in transactions) {
    final key = formatDateKey(DateTime.fromMillisecondsSinceEpoch(tx.timestamp));
    map.putIfAbsent(key, () => []).add(tx);
  }
  final today = now ?? DateTime.now();
  final todayKey = formatDateKey(today);
  final yesterdayKey = formatDateKey(
    today.subtract(const Duration(days: 1)),
  );
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      LedgerDayGroup(
        key: key,
        label: key == todayKey
            ? '今天'
            : key == yesterdayKey
            ? '昨天'
            : '${int.parse(key.substring(5, 7))} 月 ${int.parse(key.substring(8, 10))} 日',
        weekday:
            '周${['日', '一', '二', '三', '四', '五', '六'][DateTime.parse(key).weekday % 7]}',
        totalCents: map[key]!
            .where((tx) => tx.type != 'income')
            .fold<int>(0, (sum, tx) => sum + tx.amountCents.abs()),
        items: (map[key]!..sort((a, b) => b.timestamp.compareTo(a.timestamp))),
      ),
  ];
}

class LedgerCategoryStat {
  const LedgerCategoryStat({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.cents,
    required this.percent,
  });

  final String id;
  final String name;
  final String icon;
  final String color;
  final int cents;
  final int percent;
}

class LedgerBreakdown {
  const LedgerBreakdown({required this.total, required this.list});

  final int total;
  final List<LedgerCategoryStat> list;
}

LedgerBreakdown categoryBreakdown(
  CapLedger ledger,
  List<CapTransaction> transactions,
) {
  final categories = ledger.categories.isEmpty
      ? [
          for (var i = 0; i < ledgerCategoriesSeed.length; i += 1)
            LedgerCategory.seed(ledgerCategoriesSeed[i], i),
        ]
      : ledger.categories;
  final totals = <String, int>{};
  var total = 0;
  for (final tx in transactions) {
    if (tx.type == 'income') continue;
    final cents = transactionEffectiveCents(tx);
    if (cents == 0) continue;
    totals[tx.categoryId] = (totals[tx.categoryId] ?? 0) + cents;
    total += cents;
  }
  final list = categories
      .where((cat) => cat.type == 'expense')
      .map((cat) {
        final cents = totals[cat.id] ?? 0;
        return LedgerCategoryStat(
          id: cat.id,
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          cents: cents,
          percent: total > 0 ? ((cents / total) * 100).round() : 0,
        );
      })
      .where((item) => item.cents > 0)
      .toList()
    ..sort((a, b) => b.cents.compareTo(a.cents));
  return LedgerBreakdown(total: total, list: list);
}

class LedgerTrendBar {
  const LedgerTrendBar({
    required this.key,
    required this.date,
    required this.cents,
    required this.weekday,
    required this.percent,
  });

  final String key;
  final DateTime date;
  final int cents;
  final String weekday;
  final int percent;
}

class LedgerTrend {
  const LedgerTrend({required this.max, required this.list});

  final int max;
  final List<LedgerTrendBar> list;
}

LedgerTrend expenseTrend(
  CapLedger ledger, {
  int days = 7,
  DateTime? now,
}) {
  final base = startOfDay(now ?? DateTime.now());
  final buckets = <String, int>{};
  final dates = <String, DateTime>{};
  for (var offset = days - 1; offset >= 0; offset -= 1) {
    final date = base.subtract(Duration(days: offset));
    final key = formatDateKey(date);
    buckets[key] = 0;
    dates[key] = date;
  }
  for (final tx in ledger.transactions) {
    if (tx.type != 'expense') continue;
    final key = formatDateKey(DateTime.fromMillisecondsSinceEpoch(tx.timestamp));
    if (!buckets.containsKey(key)) continue;
    buckets[key] = buckets[key]! + transactionEffectiveCents(tx);
  }
  final max = buckets.values.fold<int>(0, math.max);
  return LedgerTrend(
    max: max,
    list: [
      for (final entry in buckets.entries)
        LedgerTrendBar(
          key: entry.key,
          date: dates[entry.key]!,
          cents: entry.value,
          weekday: '${['日', '一', '二', '三', '四', '五', '六'][dates[entry.key]!.weekday % 7]}',
          percent: max > 0
              ? math.max(4, ((entry.value / max) * 100).round())
              : 0,
        ),
    ],
  );
}

String transactionTitle(CapTransaction tx, List<LedgerCategory> categories) {
  final note = tx.note.trim();
  if (note.isNotEmpty) return note;
  for (final cat in categories) {
    if (cat.id == tx.categoryId) return cat.name;
  }
  return '未分类';
}

const _categoryKeywords = <String, List<String>>{
  'cat_food': ['食堂', '餐厅', '餐', '饭', '面', '粉', '奶茶', '咖啡', '烧烤', '火锅', '外卖', '麦当劳', '肯德基', '瑞幸', '蜜雪', '美团', '饿了么'],
  'cat_transport': ['地铁', '公交', '打车', '滴滴', '出租', '高铁', '火车', '机票', '航空', '加油', '停车', '单车'],
  'cat_shopping': ['超市', '便利店', '京东', '淘宝', '拼多多', '天猫', '商城', '旗舰店', '百货', '小米'],
  'cat_health': ['药', '医院', '诊所', '体检', '口腔', '眼镜'],
  'cat_fun': ['电影', '游戏', '演出', '门票', 'KTV', '健身', '球馆'],
  'cat_daily': ['话费', '流量', '宽带', '水电', '物业', '快递'],
  'cat_study': ['书店', '图书', '文具', '打印', '课程', '学费'],
  'cat_home': ['房租', '宿舍', '住宿', '酒店'],
};

String suggestLedgerCategory(
  CapLedger ledger,
  String merchant, {
  String text = '',
}) {
  final categories = ledger.categories.isEmpty
      ? [
          for (var i = 0; i < ledgerCategoriesSeed.length; i += 1)
            LedgerCategory.seed(ledgerCategoriesSeed[i], i),
        ]
      : ledger.categories;
  bool has(String id) => categories.any((item) => item.id == id);
  final key = merchant.trim().toLowerCase();
  final rule = ledger.merchantRules[key];
  if (key.isNotEmpty && rule != null && has(rule)) return rule;
  final haystack = '$merchant $text';
  for (final entry in _categoryKeywords.entries) {
    if (has(entry.key) &&
        entry.value.any((keyword) => haystack.contains(keyword))) {
      return entry.key;
    }
  }
  if (has('cat_other')) return 'cat_other';
  final first = categories.where((item) => item.type == 'expense');
  return first.isEmpty ? 'cat_food' : first.first.id;
}

String hexToRgba(String hex, double alpha) {
  final value = hex.replaceAll('#', '');
  final r = int.tryParse(value.substring(0, 2), radix: 16) ?? 116;
  final g = int.tryParse(
        value.length >= 4 ? value.substring(2, 4) : '7B',
        radix: 16,
      ) ??
      123;
  final b = int.tryParse(
        value.length >= 6 ? value.substring(4, 6) : '82',
        radix: 16,
      ) ??
      130;
  return 'rgba($r, $g, $b, $alpha)';
}
