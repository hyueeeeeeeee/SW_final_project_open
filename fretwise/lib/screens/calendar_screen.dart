import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/album_art.dart';
import '../widgets/section_header.dart';
import '../widgets/progress_bar.dart';

class CalendarScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;

  const CalendarScreen({super.key, required this.t, required this.navigate});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _today = DateTime.now();
  late int _month;
  late int _year;
  bool _showTodayDetail = false;

  @override
  void initState() {
    super.initState();
    _month = _today.month;
    _year = _today.year;
  }

  AppTheme get t => widget.t;

  static const _practiced = {1,2,3,4,7,8,9,10,11,14,15,16,17,18,21,22,23,24,25,28,29,30};
  static const _missed = {5,6,12,13,19,20};
  static const _upcoming = {4,5,6,7,8,9,10};

  Color _dayColor(int day) {
    final isToday = day == _today.day && _month == _today.month && _year == _today.year;
    final isPast = day < _today.day || _month < _today.month || _year < _today.year;
    if (isToday) return t.accent;
    if (isPast && _practiced.contains(day)) return const Color(0xFF7A9E7A);
    if (isPast && _missed.contains(day)) return const Color(0xFFB07868);
    if (!isPast && _upcoming.contains(day - _today.day)) return t.accent;
    return Colors.transparent;
  }

  Color _dayTextColor(int day) {
    final isToday = day == _today.day && _month == _today.month && _year == _today.year;
    final isPast = day < _today.day;
    if (isToday) return Colors.white;
    if (isPast && _practiced.contains(day)) return Colors.white;
    if (isPast && _missed.contains(day)) return Colors.white;
    if (!isPast && _upcoming.contains(day - _today.day)) return t.accent;
    return day > _today.day ? t.textMuted : t.text;
  }

  bool _hasBorder(int day) {
    final isToday = day == _today.day && _month == _today.month && _year == _today.year;
    if (isToday) return false;
    final isPast = day < _today.day;
    return (isPast && (_practiced.contains(day) || _missed.contains(day))) ||
        (!isPast && _upcoming.contains(day - _today.day));
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstDay = DateTime(_year, _month, 1).weekday % 7;
    final monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Text('Calendar',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: t.text, fontFamily: 'Georgia')),
              ),

              // Today's Plan
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(label: "Today's Plan", t: t),
                    GestureDetector(
                      onTap: () => setState(() => _showTodayDetail = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: t.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                              children: [
                                Row(
                                  children: [
                                    const AlbumArt(seed: 0, size: 48, radius: 14),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Today's practice",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted, letterSpacing: 0.7)),
                                        const SizedBox(height: 2),
                                        Text('Wonderwall', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.text)),
                                        Text('Oasis · 87 BPM', style: TextStyle(fontSize: 13, color: t.textSec)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ProgressBar(progress: 0, t: t),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('20 min planned', style: TextStyle(fontSize: 12, color: t.textSec)),
                                    Container(
                                      decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.play_arrow, size: 12, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Coming Up
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(label: 'Coming Up', t: t),
                    Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.border),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const AlbumArt(seed: 1, size: 40, radius: 12),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Blackbird', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
                                Text('The Beatles', style: TextStyle(fontSize: 12, color: t.textSec)),
                                const SizedBox(height: 2),
                                Text('Bars 1–8 fingerpicking', style: TextStyle(fontSize: 11, color: t.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('In 3 days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.accent)),
                              Text('2:18', style: TextStyle(fontSize: 11, color: t.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Calendar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(label: 'History', t: t),

                    // Legend
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _LegendDot(color: const Color(0xFF7A9E7A), label: 'Practiced', soft: false, t: t),
                          _LegendDot(color: const Color(0xFFB07868), label: 'Missed', soft: false, t: t),
                          _LegendDot(color: t.accent, label: 'Today', soft: false, t: t),
                          _LegendDot(color: t.accentMid, label: 'Upcoming', soft: true, t: t),
                        ],
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: t.border),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Month nav
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() {
                                  if (_month == 1) { _month = 12; _year--; } else { _month--; }
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Text('‹', style: TextStyle(fontSize: 20, color: t.textSec)),
                                ),
                              ),
                              Text('${monthNames[_month - 1]} $_year',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.text)),
                              GestureDetector(
                                onTap: () => setState(() {
                                  if (_month == 12) { _month = 1; _year++; } else { _month++; }
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Text('›', style: TextStyle(fontSize: 20, color: t.textSec)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Day headers
                          Row(
                            children: ['S','M','T','W','T','F','S']
                                .map((d) => Expanded(
                                      child: Center(
                                        child: Text(d,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: t.textMuted,
                                            )),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 6),

                          // Days grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                              childAspectRatio: 1,
                            ),
                            itemCount: firstDay + daysInMonth,
                            itemBuilder: (ctx, i) {
                              if (i < firstDay) return const SizedBox();
                              final day = i - firstDay + 1;
                              final bgColor = _dayColor(day);
                              final textColor = _dayTextColor(day);
                              final border = _hasBorder(day);
                              return Center(
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: bgColor == Colors.transparent ? null : bgColor.withValues(
                                      alpha: bgColor == t.accent && !(day == _today.day && _month == _today.month) ? 0.13 : 1.0,
                                    ),
                                    shape: BoxShape.circle,
                                    border: border ? Border.all(
                                      color: bgColor.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ) : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: day == _today.day && _month == _today.month ? FontWeight.w700 : FontWeight.w400,
                                        color: day == _today.day && _month == _today.month ? Colors.white : textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Today's detail bottom sheet
        if (_showTodayDetail) _TodayDetailSheet(t: t, navigate: widget.navigate, onClose: () => setState(() => _showTodayDetail = false)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool soft;
  final AppTheme t;

  const _LegendDot({required this.color, required this.label, required this.soft, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: soft ? color.withValues(alpha: 0.2) : color,
            borderRadius: BorderRadius.circular(3),
            border: soft ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: t.textSec)),
      ],
    );
  }
}

class _TodayDetailSheet extends StatelessWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final VoidCallback onClose;

  const _TodayDetailSheet({required this.t, required this.navigate, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const AlbumArt(seed: 1, size: 56, radius: 16),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Today's Practice",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted, letterSpacing: 0.7)),
                        const SizedBox(height: 2),
                        Text('Wonderwall', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.text)),
                        Text('Oasis · 87 BPM', style: TextStyle(fontSize: 14, color: t.textSec)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FOCUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.textMuted, letterSpacing: 0.7)),
                      const SizedBox(height: 6),
                      Text('Focus on chord transitions, bars 9–16', style: TextStyle(fontSize: 14, color: t.text, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text('20 min', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
                            const SizedBox(height: 2),
                            Text('Planned', style: TextStyle(fontSize: 11, color: t.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text('87', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
                            const SizedBox(height: 2),
                            Text('BPM', style: TextStyle(fontSize: 11, color: t.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onClose();
                      navigate('practicing', props: {'title': 'Wonderwall', 'artist': 'Oasis', 'bpm': 87});
                    },
                    icon: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                    label: const Text('Start Practice', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
