import 'package:flutter/material.dart';
import '../models/match_result.dart';

/// 匹配理由卡片组件
/// 展示符合项、风险项、不符项分区
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：岗位名称 + 匹配分
          _buildHeader(context),
          const Divider(height: 1),
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
                    Colors.green,
                    result.matchedItems,
                  ),
                // 风险项
                if (result.riskItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSection(
                    context,
                    '风险项',
                    Icons.warning_amber_outlined,
                    Colors.orange,
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
                    Colors.red,
                    result.unmatchedItems,
                  ),
                ],
                // 建议
                if (result.advice != null && result.advice!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            result.advice!,
                            style: const TextStyle(fontSize: 12, height: 1.4),
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
                      OutlinedButton.icon(
                        onPressed: onSetTarget,
                        icon: Icon(
                          result.isTarget ? Icons.bookmark : Icons.bookmark_outline,
                          size: 16,
                        ),
                        label: Text(result.isTarget ? '已选为目标' : '设为目标岗位'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: result.isTarget ? Colors.green : null,
                          side: BorderSide(
                            color: result.isTarget ? Colors.green : Colors.grey,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
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
    final scoreColor = result.matchScore >= 80
        ? Colors.green
        : result.matchScore >= 60
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.positionName ?? '未知岗位',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (result.department != null || result.city != null)
                  Text(
                    [result.department, result.city].whereType<String>().join(' · '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          // 匹配度分数
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${result.matchScore}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                Text(
                  '分',
                  style: TextStyle(fontSize: 10, color: scoreColor),
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
    Color color,
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$title（${items.length}）',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 2),
              child: Text(
                '• $item',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            )),
      ],
    );
  }
}
