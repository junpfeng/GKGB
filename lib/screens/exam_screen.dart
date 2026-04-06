import 'package:flutter/material.dart';

class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模拟考试')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '模拟考试',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '按真实考试时间和题量模拟',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // TODO: 开始模拟考试
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始模考'),
            ),
          ],
        ),
      ),
    );
  }
}
