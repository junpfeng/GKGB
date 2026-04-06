import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('点击完善个人信息', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('完善信息以获取精准岗位匹配', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(context, Icons.school, '学历信息', '未填写'),
          _buildMenuItem(context, Icons.work, '工作经历', '未填写'),
          _buildMenuItem(context, Icons.location_city, '目标城市', '未设置'),
          _buildMenuItem(context, Icons.card_membership, '资格证书', '未填写'),
          const Divider(height: 32),
          _buildMenuItem(context, Icons.smart_toy, 'AI 模型设置', ''),
          _buildMenuItem(context, Icons.cloud_sync, '数据同步', ''),
          _buildMenuItem(context, Icons.settings, '设置', ''),
          _buildMenuItem(context, Icons.info_outline, '关于', ''),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        // TODO: 导航到对应设置页
      },
    );
  }
}
