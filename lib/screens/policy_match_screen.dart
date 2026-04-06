import 'package:flutter/material.dart';

class PolicyMatchScreen extends StatelessWidget {
  const PolicyMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('岗位匹配'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: 刷新公告
            },
            tooltip: '刷新公告',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: 筛选条件
            },
            tooltip: '筛选',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无匹配岗位',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请先完善个人信息，系统将自动匹配适合你的岗位',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // TODO: 跳转到个人信息页
              },
              icon: const Icon(Icons.edit),
              label: const Text('完善个人信息'),
            ),
          ],
        ),
      ),
    );
  }
}
