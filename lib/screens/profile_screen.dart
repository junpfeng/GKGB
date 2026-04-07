import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'baseline_test_screen.dart';
import 'llm_settings_screen.dart';
import 'study_plan_screen.dart';

/// 个人信息页（我的）
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileService>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Consumer<ProfileService>(
        builder: (context, service, _) {
          final profile = service.profile;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 顶部头像区（渐变圆形头像框）
              _buildAvatarSection(context, profile, service),
              const SizedBox(height: 16),
              // 个人信息摘要（已填写时显示）
              if (profile != null && profile.education != null) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '画像摘要',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow('学历', profile.education ?? '-'),
                      _InfoRow('专业', profile.major ?? '-'),
                      _InfoRow('院校', profile.university ?? '-'),
                      _InfoRow('政治面貌', profile.politicalStatus ?? '-'),
                      _InfoRow(
                        '目标城市',
                        profile.targetCities.join('、').isNotEmpty
                            ? profile.targetCities.join('、')
                            : '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // 功能菜单（GlassCard 列表）
              _buildMenuItem(
                context,
                Icons.quiz,
                '摸底测试',
                '快速评估基础水平，生成个性化计划',
                AppTheme.primaryGradient,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BaselineTestScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                context,
                Icons.smart_toy,
                'AI 模型设置',
                '配置 DeepSeek、Claude 等模型',
                AppTheme.infoGradient,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LlmSettingsScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                context,
                Icons.route,
                '我的学习计划',
                '查看和管理学习计划',
                AppTheme.successGradient,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyPlanScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                context,
                Icons.info_outline,
                '关于本应用',
                '考公考编智能助手 v1.0',
                AppTheme.warmGradient,
                () => showAboutDialog(
                  context: context,
                  applicationName: '考公考编智能助手',
                  applicationVersion: '1.0.0',
                  children: const [
                    Text('基于 Flutter 开发的跨平台考公备考助手，支持 Windows 和 Android。'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(
    BuildContext context,
    UserProfile? profile,
    ProfileService service,
  ) {
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
      ).then((_) => service.loadProfile()),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 渐变圆形头像框
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 32,
                color: const Color(0xFF667eea),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.education != null ? '个人信息已完善' : '点击完善个人信息',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile != null && profile.education != null
                      ? '${profile.education} · ${profile.major ?? "专业未填写"}'
                      : '完善信息以获取精准岗位匹配',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return AccentCard(
      accentGradient: gradient,
      accentWidth: 4,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient.colors
                    .map((c) => c.withValues(alpha: 0.15))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: gradient.colors.first, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// 个人信息编辑页
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _majorController = TextEditingController();
  final _universityController = TextEditingController();
  final _majorCodeController = TextEditingController();
  final _ageController = TextEditingController();
  final _workYearsController = TextEditingController();
  final _targetCitiesController = TextEditingController();
  final _certificatesController = TextEditingController();

  String? _education;
  String? _degree;
  String? _politicalStatus;
  String? _gender;
  String? _hukouProvince;
  bool _is985 = false;
  bool _is211 = false;
  bool _hasGrassrootsExp = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _majorController.dispose();
    _universityController.dispose();
    _majorCodeController.dispose();
    _ageController.dispose();
    _workYearsController.dispose();
    _targetCitiesController.dispose();
    _certificatesController.dispose();
    super.dispose();
  }

  void _loadExisting() {
    final profile = context.read<ProfileService>().profile;
    if (profile == null) return;
    setState(() {
      _education = profile.education;
      _degree = profile.degree;
      _majorController.text = profile.major ?? '';
      _majorCodeController.text = profile.majorCode ?? '';
      _universityController.text = profile.university ?? '';
      _is985 = profile.is985;
      _is211 = profile.is211;
      _workYearsController.text =
          profile.workYears == 0 ? '' : '${profile.workYears}';
      _hasGrassrootsExp = profile.hasGrassrootsExp;
      _politicalStatus = profile.politicalStatus;
      _certificatesController.text = profile.certificates.join('，');
      _ageController.text = profile.age == null ? '' : '${profile.age}';
      _gender = profile.gender;
      _hukouProvince = profile.hukouProvince;
      _targetCitiesController.text = profile.targetCities.join('，');
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = UserProfile(
      education: _education,
      degree: _degree,
      major: _majorController.text.trim().isEmpty
          ? null
          : _majorController.text.trim(),
      majorCode: _majorCodeController.text.trim().isEmpty
          ? null
          : _majorCodeController.text.trim(),
      university: _universityController.text.trim().isEmpty
          ? null
          : _universityController.text.trim(),
      is985: _is985,
      is211: _is211,
      workYears: int.tryParse(_workYearsController.text) ?? 0,
      hasGrassrootsExp: _hasGrassrootsExp,
      politicalStatus: _politicalStatus,
      certificates: _certificatesController.text.isNotEmpty
          ? _certificatesController.text
              .split(RegExp(r'[，,]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [],
      age: int.tryParse(_ageController.text),
      gender: _gender,
      hukouProvince: _hukouProvince,
      targetCities: _targetCitiesController.text.isNotEmpty
          ? _targetCitiesController.text
              .split(RegExp(r'[，,]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [],
    );

    await context.read<ProfileService>().saveProfile(profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('完善个人信息'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('学历信息'),
            DropdownButtonFormField<String>(
              initialValue: _education,
              decoration: const InputDecoration(labelText: '学历'),
              items: const [
                DropdownMenuItem(value: '大专', child: Text('大专')),
                DropdownMenuItem(value: '本科', child: Text('本科')),
                DropdownMenuItem(value: '硕士', child: Text('硕士')),
                DropdownMenuItem(value: '博士', child: Text('博士')),
              ],
              onChanged: (v) => setState(() => _education = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _degree,
              decoration: const InputDecoration(labelText: '学位'),
              items: const [
                DropdownMenuItem(value: '学士', child: Text('学士')),
                DropdownMenuItem(value: '硕士', child: Text('硕士')),
                DropdownMenuItem(value: '博士', child: Text('博士')),
              ],
              onChanged: (v) => setState(() => _degree = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _majorController,
              decoration: const InputDecoration(
                  labelText: '专业名称', hintText: '如：计算机科学与技术'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _majorCodeController,
              decoration:
                  const InputDecoration(labelText: '专业编码（可选）', hintText: '如：0812'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _universityController,
              decoration: const InputDecoration(labelText: '毕业院校'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _is985,
                    onChanged: (v) => setState(() => _is985 = v!),
                    title: const Text('985院校', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    value: _is211,
                    onChanged: (v) => setState(() => _is211 = v!),
                    title: const Text('211院校', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle('工作经历'),
            TextFormField(
              controller: _workYearsController,
              decoration: const InputDecoration(labelText: '工作年限（年）'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _hasGrassrootsExp,
              onChanged: (v) => setState(() => _hasGrassrootsExp = v!),
              title: const Text('有基层工作经历'),
              subtitle: const Text('村/社区/乡镇工作经历',
                  style: TextStyle(fontSize: 11)),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            _SectionTitle('个人信息'),
            DropdownButtonFormField<String>(
              initialValue: _politicalStatus,
              decoration: const InputDecoration(labelText: '政治面貌'),
              items: const [
                DropdownMenuItem(value: '群众', child: Text('群众')),
                DropdownMenuItem(value: '共青团员', child: Text('共青团员')),
                DropdownMenuItem(value: '中共党员', child: Text('中共党员')),
                DropdownMenuItem(value: '中共预备党员', child: Text('中共预备党员')),
              ],
              onChanged: (v) => setState(() => _politicalStatus = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: '年龄'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: '性别'),
              items: const [
                DropdownMenuItem(value: '男', child: Text('男')),
                DropdownMenuItem(value: '女', child: Text('女')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _hukouProvince,
              decoration: const InputDecoration(labelText: '户籍省份'),
              items: const [
                DropdownMenuItem(value: '北京', child: Text('北京')),
                DropdownMenuItem(value: '上海', child: Text('上海')),
                DropdownMenuItem(value: '广东', child: Text('广东')),
                DropdownMenuItem(value: '浙江', child: Text('浙江')),
                DropdownMenuItem(value: '江苏', child: Text('江苏')),
                DropdownMenuItem(value: '四川', child: Text('四川')),
                DropdownMenuItem(value: '湖南', child: Text('湖南')),
                DropdownMenuItem(value: '湖北', child: Text('湖北')),
                DropdownMenuItem(value: '河南', child: Text('河南')),
                DropdownMenuItem(value: '山东', child: Text('山东')),
                DropdownMenuItem(value: '其他', child: Text('其他')),
              ],
              onChanged: (v) => setState(() => _hukouProvince = v),
            ),
            const SizedBox(height: 16),
            _SectionTitle('报考偏好'),
            TextFormField(
              controller: _targetCitiesController,
              decoration: const InputDecoration(
                labelText: '目标城市（多个用逗号分隔）',
                hintText: '如：北京，上海，广州',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _certificatesController,
              decoration: const InputDecoration(
                labelText: '资格证书（多个用逗号分隔）',
                hintText: '如：法律职业资格，CPA，教师资格证',
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: _save,
              label: '保存个人信息',
              width: double.infinity,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
