import 'package:flutter/material.dart';
import '../models/match_result.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import 'gradient_button.dart';

/// 匹配理由卡片组件（GlassCard + 渐变匹配度环）
class MatchReasonCard extends StatelessWidget {
  final MatchResult result;
  final VoidCallback? onSetTarget;
  final VoidCallback? onViewDetail;

  const MatchReasonCard({
    super.key,
    required this.result,
    this.onSetTarget,
    this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：岗位名称 + 渐变匹配度环
          _buildHeader(context),
          Divider(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.dividerDark
                : AppTheme.dividerLight,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 符合项
                if (result.matchedItems.isNotEmpty)
                  _buildSection(
                    context,
                    '符合项',
                    Icons.check_circle_outline,
                    AppTheme.successGradient,
                    result.matchedItems,
                  ),
                // 风险项
                if (result.riskItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSection(
                    context,
                    '风险项',
                    Icons.warning_amber_outlined,
                    AppTheme.warningGradient,
                    result.riskItems,
                  ),
                ],
                // 不符项
                if (result.unmatchedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSection(
                    context,
                    '不符项',
                    Icons.cancel_outlined,
                    AppTheme.warmGradient,
                    result.unmatchedItems,
                  ),
                ],
                // 建议
                if (result.advice != null && result.advice!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF7971E).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 16, color: Color(0xFFF7971E)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            result.advice!,
                            style:
                                const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 操作按钮
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onSetTarget != null)
                      GradientButton(
                        onPressed: onSetTarget,
                        label: result.isTarget ? '已选为目标' : '设为目标岗位',
                        icon: result.isTarget
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                        gradient: result.isTarget
                            ? AppTheme.successGradient
                            : AppTheme.primaryGradient,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        borderRadius: 8,
                        textStyle: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    const Spacer(),
                    if (onViewDetail != null)
                      TextButton(
                        onPressed: onViewDetail,
                        child: const Text('查看详情'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // 根据匹配度选择渐变
    final gradient = result.matchScore >= 80
        ? AppTheme.successGradient
        : result.matchScore >= 60
            ? AppTheme.warningGradient
            : AppTheme.warmGradient;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.positionName ?? '未知岗位',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (result.department != null || result.city != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [result.department, result.city]
                          .whereType<String>()
                          .join(' · '),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                if (result.policyTitle != null)
                  Text(
                    result.policyTitle!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 渐变匹配度圆环
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${result.matchScore}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '分',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    LinearGradient gradient,
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    '$title（${items.length}）',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                '• $item',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            )),
      ],
    );
  }
}
