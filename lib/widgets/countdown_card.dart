import 'dart:io';

import 'package:flutter/material.dart';

import '../data/cap_store.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import 'cap_icon.dart';
import 'pressable.dart';

class CountdownSkin {
  const CountdownSkin({
    required this.background,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.dot,
  });

  final List<Color> background;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color dot;
}

CountdownSkin skinFor(String id) {
  switch (id) {
    case 'mint':
      return const CountdownSkin(
        background: [Color(0xFFE9F3EB), Color(0xFFD8EADF), Color(0xFFC7DFD3)],
        ink: Color(0xFF163D35),
        muted: Color(0x9E163D35),
        accent: Color(0xFF2D7867),
        dot: Color(0x2E163D35),
      );
    case 'blossom':
      return const CountdownSkin(
        background: [Color(0xFFFAECEC), Color(0xFFF6DCDC), Color(0xFFEFCBCB)],
        ink: Color(0xFF572A33),
        muted: Color(0x9E572A33),
        accent: Color(0xFFB24A5A),
        dot: Color(0x2E572A33),
      );
    case 'night':
      return const CountdownSkin(
        background: [Color(0xFF25324B), Color(0xFF16223A), Color(0xFF0E182B)],
        ink: Color(0xFFFFF8EA),
        muted: Color(0xADFFF8EA),
        accent: Color(0xFFE7C27C),
        dot: Color(0x42FFF8EA),
      );
    case 'sky':
      return const CountdownSkin(
        background: [Color(0xFFEAF1FA), Color(0xFFD9E7F6), Color(0xFFC7D9F0)],
        ink: Color(0xFF1B3353),
        muted: Color(0x9E1B3353),
        accent: Color(0xFF326EAF),
        dot: Color(0x2E1B3353),
      );
    default:
      return const CountdownSkin(
        background: [Color(0xFFFBF3E4), Color(0xFFF6E8D2), Color(0xFFF1DEC4)],
        ink: Color(0xFF4A2E25),
        muted: Color(0xA34A2E25),
        accent: Color(0xFFB85A3D),
        dot: Color(0x334A2E25),
      );
  }
}

enum CountdownVariant { list, compact, hero }

class CountdownCard extends StatelessWidget {
  const CountdownCard({
    super.key,
    required this.item,
    this.variant = CountdownVariant.list,
    this.onTap,
  });

  final CapCountdown item;
  final CountdownVariant variant;
  final VoidCallback? onTap;

  bool get _hasImage => item.skin == 'custom' && item.customImage.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final skin = _hasImage
        ? const CountdownSkin(
            background: [Color(0xFF0D1A2E), Color(0xFF0D1A2E)],
            ink: Colors.white,
            muted: Color(0xC7FFFFFF),
            accent: Color(0xFFF3CF8B),
            dot: Color(0x57FFFFFF),
          )
        : skinFor(item.skin);
    final timing = countdownText(item.targetDate);
    final isToday = timing.state == 'today';
    final label = timing.label;
    final unit = isToday ? '今天' : '天';
    final number = isToday ? '今' : '${timing.days}';
    final targetDate = parseDateKey(item.targetDate);
    final targetLine =
        '${targetDate == null ? item.targetDate : formatDateCN(targetDate, withWeekday: true)}${item.targetTime.isEmpty ? '' : ' · ${item.targetTime}'}';

    final card = SizedBox(
      height: capRpx(
        context,
        variant == CountdownVariant.compact
            ? 254
            : variant == CountdownVariant.hero
            ? 476
            : 414,
      ),
      child: Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, variant == CountdownVariant.list ? 30 : 28),
        capRpx(context, variant == CountdownVariant.hero ? 30 : 26),
        capRpx(context, variant == CountdownVariant.list ? 30 : 28),
        capRpx(context, variant == CountdownVariant.hero ? 28 : 24),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capRpx(context, 34)),
        gradient: _hasImage
            ? const LinearGradient(colors: [Color(0xFF0D1A2E), Color(0xFF0D1A2E)])
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: skin.background,
              ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1A2E).withValues(alpha: 0.18),
            blurRadius: capRpx(context, 52),
            offset: Offset(0, capRpx(context, 24)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(capRpx(context, 34)),
        child: Stack(
          children: [
            if (_hasImage)
              Positioned.fill(
                child: Image.file(
                  File(item.customImage),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const ColoredBox(
                    color: Color(0xFF0D1A2E),
                  ),
                ),
              ),
            if (_hasImage)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0x0F07101E),
                        const Color(0x5707101E).withValues(alpha: 0.34),
                        const Color(0xD607101E).withValues(alpha: 0.84),
                      ],
                      stops: const [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -capRpx(context, 90),
              top: -capRpx(context, 150),
              child: Container(
                width: capRpx(context, 360),
                height: capRpx(context, 360),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.17),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.035),
                      blurRadius: 0,
                      spreadRadius: capRpx(context, 34),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.02),
                      blurRadius: 0,
                      spreadRadius: capRpx(context, 88),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  children: [
                    if (item.tag.isNotEmpty)
                      Container(
                        height: capRpx(context, 46),
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 18),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: capRpx(context, 8),
                              height: capRpx(context, 8),
                              decoration: BoxDecoration(
                                color: skin.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: capRpx(context, 8)),
                            Text(
                              item.tag,
                              style: TextStyle(
                                fontSize: capRpx(context, 20),
                                fontWeight: FontWeight.w700,
                                letterSpacing: capRpx(context, 0.4),
                                color: skin.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (item.pinned) ...[
                      SizedBox(width: capRpx(context, 12)),
                      Text(
                        '置顶',
                        style: TextStyle(
                          fontSize: capRpx(context, 19),
                          fontWeight: FontWeight.w600,
                          letterSpacing: capRpx(context, 0.8),
                          color: skin.muted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (variant == CountdownVariant.hero)
                      Text(
                        'COUNTDOWN',
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          fontWeight: FontWeight.w700,
                          letterSpacing: capRpx(context, 4.4),
                          color: skin.muted,
                        ),
                      ),
                  ],
                ),
                if (variant == CountdownVariant.compact)
                  Padding(
                    padding: EdgeInsets.only(top: capRpx(context, 24)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.subtitle.isNotEmpty) ...[
                                Text(
                                  item.subtitle.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: capRpx(context, 20),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: capRpx(context, 3.2),
                                    color: skin.muted,
                                  ),
                                ),
                                SizedBox(height: capRpx(context, 4)),
                              ],
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: capRpx(context, 36),
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  letterSpacing: capRpx(context, -0.7),
                                  color: skin.ink,
                                ),
                              ),
                              SizedBox(height: capRpx(context, 12)),
                              _dateLine(context, skin, targetLine),
                            ],
                          ),
                        ),
                        SizedBox(width: capRpx(context, 20)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: capRpx(context, 19),
                                fontWeight: FontWeight.w600,
                                letterSpacing: capRpx(context, 2.3),
                                color: skin.muted,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  number,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: capRpx(context, 100),
                                    fontWeight: FontWeight.w800,
                                    height: 0.86,
                                    letterSpacing: capRpx(context, -7.5),
                                    color: skin.ink,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF081221)
                                            .withValues(alpha: 0.20),
                                        blurRadius: capRpx(context, 20),
                                        offset: Offset(0, capRpx(context, 2)),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: capRpx(context, 8)),
                                Text(
                                  unit,
                                  style: TextStyle(
                                    fontSize: capRpx(context, 22),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: capRpx(context, 0.4),
                                    color: skin.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: capRpx(context, variant == CountdownVariant.hero ? 38 : 30),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.subtitle.isNotEmpty) ...[
                                Text(
                                  item.subtitle.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: capRpx(context, 20),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: capRpx(context, 3.2),
                                    color: skin.muted,
                                  ),
                                ),
                                SizedBox(height: capRpx(context, 4)),
                              ],
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: capRpx(
                                    context,
                                    variant == CountdownVariant.hero ? 42 : 35,
                                  ),
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  letterSpacing: capRpx(context, -0.7),
                                  color: skin.ink,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: capRpx(context, 34),
                                    height: 1,
                                    color: skin.dot,
                                  ),
                                  SizedBox(width: capRpx(context, 12)),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: capRpx(context, 19),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: capRpx(context, 2.6),
                                      color: skin.muted,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: capRpx(context, 12)),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    number,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: capRpx(
                                        context,
                                        variant == CountdownVariant.hero
                                            ? 170
                                            : 148,
                                      ),
                                      fontWeight: FontWeight.w800,
                                      height: 0.86,
                                      letterSpacing: capRpx(context, -11),
                                      color: skin.ink,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFF081221)
                                              .withValues(alpha: 0.20),
                                          blurRadius: capRpx(context, 20),
                                          offset: Offset(0, capRpx(context, 2)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: capRpx(context, 8)),
                                  Text(
                                    unit,
                                    style: TextStyle(
                                      fontSize: capRpx(context, 25),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: capRpx(context, 0.4),
                                      color: skin.muted,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: capRpx(context, 12)),
                              _dateLine(context, skin, targetLine),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (variant == CountdownVariant.hero) ...[
                  SizedBox(height: capRpx(context, 22)),
                  Container(
                    padding: EdgeInsets.only(top: capRpx(context, 20)),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.note.isEmpty ? '把日子折成纸飞机，慢慢飞向它' : item.note,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: capRpx(context, 20),
                              color: skin.muted,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(width: capRpx(context, 20)),
                        Container(
                          width: capRpx(context, 58),
                          height: capRpx(context, 58),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: CapIcon(
                              'arrow-up-right',
                              size: capRpx(context, 28),
                              color: skin.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
    );

    final filtered = timing.state == 'past'
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.62, 0, 0, 0, 0, //
              0, 0.62, 0, 0, 0, //
              0, 0, 0.62, 0, 0, //
              0, 0, 0, 1, 0, //
            ]),
            child: card,
          )
        : card;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      borderRadius: BorderRadius.circular(capRpx(context, 34)),
      child: filtered,
    );
  }

  Widget _dateLine(BuildContext context, CountdownSkin skin, String text) {
    return Row(
      children: [
        Opacity(
          opacity: 0.8,
          child: CapIcon(
            'calendar-days',
            size: capRpx(context, 25),
            color: skin.muted,
          ),
        ),
        SizedBox(width: capRpx(context, 9)),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: capRpx(context, 21),
              fontWeight: FontWeight.w500,
              letterSpacing: capRpx(context, 0.2),
              color: skin.muted,
            ),
          ),
        ),
      ],
    );
  }
}
