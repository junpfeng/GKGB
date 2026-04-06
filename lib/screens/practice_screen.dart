import 'package:flutter/material.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('刷题练习')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategoryCard(context, '行测 - 言语理解', Icons.text_fields, Colors.blue),
          _buildCategoryCard(context, '行测 - 数量关系', Icons.calculate, Colors.orange),
          _buildCategoryCard(context, '行测 - 判断推理', Icons.psychology, Colors.purple),
          _buildCategoryCard(context, '行测 - 资料分析', Icons.analytics, Colors.green),
          _buildCategoryCard(context, '行测 - 常识判断', Icons.lightbulb, Colors.amber),
          _buildCategoryCard(context, '申论', Icons.article, Colors.red),
          _buildCategoryCard(context, '公共基础知识', Icons.menu_book, Colors.teal),
          _buildCategoryCard(context, '错题本', Icons.bookmark, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: const Text('0 / 0 题'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: 进入对应科目刷题页
        },
      ),
    );
  }
}
