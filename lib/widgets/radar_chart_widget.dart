import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 能力雷达图组件（基于 fl_chart RadarChart）
/// 展示各科目正确率，无数据科目显示 0
class RadarChartWidget extends StatelessWidget {
  /// 科目名 → 正确率 (0.0 ~ 1.0)
  final Map<String, double> data;
  final double size;

  const RadarChartWidget({
    super.key,
    required this.data,
    this.size = 260,
  });

  /// 确保至少有 3 个维度（RadarChart 最少需要 3 个）
  static const _defaultSubjects = [
    '言语理解',
    '数量关系',
    '判断推理',
    '资料分析',
    '常识判断',
    '申论',
    '公共基础',
  ];

  @override
  Widget build(BuildContext context) {
    // 合并默认科目和实际数据，确保所有维度都有值
    final subjects = <String>[];
    final values = <double>[];
    for (final s in _defaultSubjects) {
      subjects.add(s);
      values.add(data[s] ?? 0.0);
    }
    // 添加不在默认列表中的科目
    for (final entry in data.entries) {
      if (!_defaultSubjects.contains(entry.key)) {
        subjects.add(entry.key);
        values.add(entry.value);
      }
    }

    if (subjects.length < 3) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('数据不足，无法绘制雷达图')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tickColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.15);
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.1);

    return SizedBox(
      height: size,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: values.map((v) => RadarEntry(value: v * 100)).toList(),
              fillColor: const Color(0xFF667eea).withValues(alpha: 0.2),
              borderColor: const Color(0xFF667eea),
              borderWidth: 2,
              entryRadius: 3,
            ),
          ],
          radarShape: RadarShape.polygon,
          radarBorderData: BorderSide(color: gridColor, width: 0.5),
          tickBorderData: BorderSide(color: tickColor, width: 0.5),
          gridBorderData: BorderSide(color: gridColor, width: 0.5),
          tickCount: 4,
          ticksTextStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 8,
          ),
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          getTitle: (index, angle) {
            final name = subjects[index];
            final pct = (values[index] * 100).round();
            return RadarChartTitle(text: '$name\n$pct%');
          },
          titlePositionPercentageOffset: 0.2,
          radarBackgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
