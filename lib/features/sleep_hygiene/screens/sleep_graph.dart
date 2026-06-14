// sleep_graph_screen.dart
// Shows the user's actual sleep quality progression over the last 14 days.
// Dependency: fl_chart: ^0.68.0

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sleep_record.dart';
import '../repository/sleep_repository.dart';


class SleepGraphScreen extends StatefulWidget {
  const SleepGraphScreen({super.key});

  @override
  State<SleepGraphScreen> createState() => _SleepGraphScreenState();
}

class _SleepGraphScreenState extends State<SleepGraphScreen> {
  static const Color _accent  = Color(0xFF3F51B5);
  static const Color _avgLine = Color(0xFF7C83D1);
  static const Color _good    = Color(0xFF66BB6A);
  static const Color _mid     = Color(0xFFFFB300);
  static const Color _bad     = Color(0xFFEF5350);

  // Tool colours
  static const Color _cRelax   = Color(0xFF42A5F5);
  static const Color _cPmr     = Color(0xFF66BB6A);
  static const Color _cWindown = Color(0xFF5C6BC0);

  List<SleepRecord> _records = [];
  bool              _loading = true;
  bool _usingDummyData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SleepRepository.loadLast(days: 14);
    final rated = data.where((r) => r.quality != null).toList();

    setState(() {
      if (rated.length >= 2) {
        // Enough real data — use it purely
        _records = data;
        _usingDummyData = false;
      } else {
        // Not enough real data — pad with dummy
        _records = _buildDummyRecords(realRecords: data);
        _usingDummyData = true;
      }
      _loading = false;
    });
  }

  List<SleepRecord> _buildDummyRecords({required List<SleepRecord> realRecords}) {
    final now = DateTime.now();

    // 14 days of plausible dummy scores
    final dummyScores = [3, 2, 3, 4, 3, 4, 5, 3, 4, 4, 3, 5, 4, 3];

    final dummyRecords = List.generate(14, (i) {
      final date = now.subtract(Duration(days: 13 - i));
      return SleepRecord(
        id:       'dummy_$i',
        date:     date,
        quality:  dummyScores[i],
        issue:    'quality',
        bedtime:  '',
        wakeTime: '',
        tools:    [],
      );
    });

    // Overlay any real records on top of matching dummy dates
    for (final real in realRecords) {
      final idx = dummyRecords.indexWhere((d) =>
      d.date.year  == real.date.year &&
          d.date.month == real.date.month &&
          d.date.day   == real.date.day);
      if (idx != -1) dummyRecords[idx] = real;
    }

    return dummyRecords;
  }

  // ── Derived data ───────────────────────────────────────────────────────────

  List<SleepRecord> get _rated =>
      _records.where((r) => r.quality != null).toList();

  double get _avg => SleepRepository.averageQuality(_rated);

  int get _streak => SleepRepository.goodSleepStreak(_rated);

  int? get _best => _rated.isEmpty
      ? null
      : _rated.map((r) => r.quality!).reduce((a, b) => a > b ? a : b);

  // ── Chart spots ────────────────────────────────────────────────────────────

  List<FlSpot> get _qualitySpots {
    final spots = <FlSpot>[];
    for (int i = 0; i < _records.length; i++) {
      final r = _records[i];
      if (r.quality != null) {
        spots.add(FlSpot(i.toDouble(), r.quality!.toDouble()));
      }
    }
    return spots;
  }

  List<FlSpot> get _avgSpots {
    final ma     = SleepRepository.movingAverage(_records);
    final spots  = <FlSpot>[];
    for (int i = 0; i < ma.length; i++) {
      if (ma[i] != null) spots.add(FlSpot(i.toDouble(), ma[i]!));
    }
    return spots;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Progress',
                  style: TextStyle(
                    fontSize:   24,
                    fontWeight: FontWeight.bold,
                    color:      _accent,
                  ),
                ),
                Text(
                  'Last 14 days',
                  style: TextStyle(
                    fontSize: 13,
                    color:    Color(0xFF9FA8DA),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: Colors.black.withOpacity(0.12)),
            const SizedBox(height: 24),
            Text(
              'Not enough data yet',
              style: TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.bold,
                color:      Colors.black.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Rate your sleep for at least 2 nights and your progress chart will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:    Colors.black.withOpacity(0.30),
                height:   1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Dummy data notice ─────────────────────────────
          if (_usingDummyData)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFFFB300)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing sample data. Rate your sleep for 2+ nights to see your real progress.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF795548),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _buildStatCards(),
          const SizedBox(height: 16),
          _buildChartCard(),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 16),
          _buildToolUsageSummary(),
        ],
      ),
    );
  }

  // ── Stat summary cards ─────────────────────────────────────────────────────

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Avg quality',
          value: _avg > 0 ? _avg.toStringAsFixed(1) : '—',
          sub:   'out of 5',
          icon:  Icons.show_chart_rounded,
          color: _accent,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: 'Best night',
          value: _best != null ? '$_best/5' : '—',
          sub:   _bestLabel,
          icon:  Icons.star_rounded,
          color: _good,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: 'Good streak',
          value: '$_streak',
          sub:   _streak == 1 ? 'night' : 'nights',
          icon:  Icons.local_fire_department_rounded,
          color: _mid,
        )),
      ],
    );
  }

  String get _bestLabel {
    if (_best == null) return '';
    switch (_best) {
      case 5: return 'Great sleep';
      case 4: return 'Good sleep';
      case 3: return 'Okay';
      default: return '';
    }
  }

  // ── Chart card ─────────────────────────────────────────────────────────────

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              'Nightly sleep quality',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      Colors.black.withOpacity(0.45),
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: LineChart(_buildChartData()),
          ),
          const SizedBox(height: 8),
          _buildXLabels(),
        ],
      ),
    );
  }

  LineChartData _buildChartData() {
    return LineChartData(
      minY: 0.5,
      maxY: 5.5,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (v) => FlLine(
          color:       Colors.black.withOpacity(0.05),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (v, _) {
              if (v < 1 || v > 5 || v != v.roundToDouble()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  v.toInt().toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.30),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineBarsData: [
        // ── Quality line ──────────────────────────────────────────────────
        LineChartBarData(
          spots:          _qualitySpots,
          isCurved:       true,
          curveSmoothness: 0.3,
          color:          _accent,
          barWidth:       2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) {
              final q = spot.y.round();
              final color = q >= 4 ? _good : q == 3 ? _mid : _bad;
              return FlDotCirclePainter(
                radius:          5,
                color:           color,
                strokeWidth:     2,
                strokeColor:     Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                _accent.withOpacity(0.18),
                _accent.withOpacity(0.01),
              ],
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
            ),
          ),
        ),
        // ── Moving average line ───────────────────────────────────────────
        if (_avgSpots.length >= 2)
          LineChartBarData(
            spots:          _avgSpots,
            isCurved:       true,
            curveSmoothness: 0.5,
            color:          _avgLine,
            barWidth:       2,
            dashArray:      [6, 4],
            dotData:        const FlDotData(show: false),
            belowBarData:   BarAreaData(show: false),
          ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) {
            if (s.barIndex == 1) return null; // skip avg line tooltip
            final idx = s.x.toInt();
            final record = idx < _records.length ? _records[idx] : null;
            final label  = record?.qualityLabel ?? '';
            return LineTooltipItem(
              '${s.y.toInt()}/5\n$label',
              const TextStyle(
                color:      Colors.white,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildXLabels() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_records.length, (i) {
        final r = _records[i];
        // Only show every 2nd label to avoid crowding
        if (i % 2 != 0 && i != _records.length - 1) return const Expanded(child: SizedBox());
        return Expanded(
          child: Text(
            _shortDate(r.date),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color:    Colors.black.withOpacity(0.28),
            ),
          ),
        );
      }),
    );
  }

  String _shortDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  // ── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: _accent,   label: 'Nightly score'),
        const SizedBox(width: 16),
        _LegendDashed(color: _avgLine, label: '3-day trend'),
        const SizedBox(width: 16),
        _LegendDot(color: _good,     label: '≥ 4'),
        const SizedBox(width: 8),
        _LegendDot(color: _mid,      label: '3'),
        const SizedBox(width: 8),
        _LegendDot(color: _bad,      label: '≤ 2'),
      ],
    );
  }

  // ── Tool usage summary ─────────────────────────────────────────────────────

  Widget _buildToolUsageSummary() {
    int relax   = 0, pmr = 0, windDown = 0;
    for (final r in _records) {
      if (r.tools.contains('relax'))    relax++;
      if (r.tools.contains('pmr'))      pmr++;
      if (r.tools.contains('winddown')) windDown++;
    }
    if (relax + pmr + windDown == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tools used',
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      Colors.black.withOpacity(0.45),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (relax > 0)
                Expanded(child: _ToolUsageTile(
                  icon:  Icons.blur_circular_rounded,
                  label: 'Relaxation',
                  count: relax,
                  color: _cRelax,
                )),
              if (relax > 0 && (pmr > 0 || windDown > 0))
                const SizedBox(width: 8),
              if (pmr > 0)
                Expanded(child: _ToolUsageTile(
                  icon:  Icons.self_improvement_rounded,
                  label: 'PMR',
                  count: pmr,
                  color: _cPmr,
                )),
              if (pmr > 0 && windDown > 0)
                const SizedBox(width: 8),
              if (windDown > 0)
                Expanded(child: _ToolUsageTile(
                  icon:  Icons.bedtime_rounded,
                  label: 'Wind-Down',
                  count: windDown,
                  color: _cWindown,
                )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });
  final String   label;
  final String   value;
  final String   sub;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color:    Colors.black.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w600,
              color:      Colors.black.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color  color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 10,
              color:    Colors.black.withOpacity(0.40),
            )),
      ],
    );
  }
}

class _LegendDashed extends StatelessWidget {
  const _LegendDashed({required this.color, required this.label});
  final Color  color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(3, (i) => Container(
          margin: EdgeInsets.only(right: i < 2 ? 2 : 0),
          width: 5, height: 2,
          color: color,
        )),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 10,
              color:    Colors.black.withOpacity(0.40),
            )),
      ],
    );
  }
}

class _ToolUsageTile extends StatelessWidget {
  const _ToolUsageTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final int      count;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      color,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count×',
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.bold,
                color:      color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}