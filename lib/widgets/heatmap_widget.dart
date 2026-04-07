import 'package:flutter/material.dart';

/// 学习热力图组件（类 GitHub 贡献图）
/// 使用 GridView + 绿色系颜色渐变
class HeatmapWidget extends StatelessWidget {
  /// 日期 → 当日答题量
  final Map<DateTime, int> data;

  /// 展示天数
  final int days;

  const HeatmapWidget({
    super.key,
    required this.data,
    this.days = 90,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 计算起始日期，对齐到周一
    final rawStart = today.subtract(Duration(days: days - 1));
    final startDate = rawStart.subtract(Duration(days: rawStart.weekday - 1));
    final totalDays = today.difference(startDate).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    // 找最大值用于颜色分级
    int maxCount = 1;
    for (final entry in data.entries) {
      if (entry.value > maxCount) maxCount = entry.value;
    }

    // 星期标签
    const weekLabels = ['一', '', '三', '', '五', '', '日'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('少', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(width: 4),
            for (int i = 0; i <= 4; i++) ...[
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: _getColor(i, 4, isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Text('多', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        // 热力图主体
        SizedBox(
          height: 7 * 14.0, // 7 行 × (10 + 4 间距)
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 星期标签列
              Column(
                children: weekLabels.map((label) {
                  return SizedBox(
                    height: 14,
                    width: 16,
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // 格子区域
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: weeks,
                  itemBuilder: (context, weekIndex) {
                    return Column(
                      children: List.generate(7, (dayIndex) {
                        final date = startDate.add(
                          Duration(days: weekIndex * 7 + dayIndex),
                        );
                        if (date.isAfter(today)) {
                          return const SizedBox(width: 14, height: 14);
                        }
                        final normalizedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                        );
                        final count = data[normalizedDate] ?? 0;
                        final level = maxCount == 0
                            ? 0
                            : (count / maxCount * 4).ceil().clamp(0, 4);
                        return Tooltip(
                          message: '${normalizedDate.month}/${normalizedDate.day}: $count 题',
                          child: Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _getColor(count == 0 ? 0 : level, 4, isDark),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 绿色系渐变色（类 GitHub）
  Color _getColor(int level, int maxLevel, bool isDark) {
    if (level == 0) {
      return isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFEBEDF0);
    }
    const greens = [
      Color(0xFF9BE9A8), // level 1
      Color(0xFF40C463), // level 2
      Color(0xFF30A14E), // level 3
      Color(0xFF216E39), // level 4
    ];
    return greens[(level - 1).clamp(0, greens.length - 1)];
  }
}
