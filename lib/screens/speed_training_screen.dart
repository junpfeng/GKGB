import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speed_training_service.dart';

/// 速算训练页面
/// 支持每日挑战和自由练习模式
class SpeedTrainingScreen extends StatefulWidget {
  const SpeedTrainingScreen({super.key});

  @override
  State<SpeedTrainingScreen> createState() => _SpeedTrainingScreenState();
}

class _SpeedTrainingScreenState extends State<SpeedTrainingScreen> {
  List<Map<String, dynamic>> _exercises = [];
  int _currentIndex = 0;
  int? _sessionId;
  bool _isLoading = true;
  bool _isFinished = false;

  // 答题统计
  int _correctCount = 0;
  int _totalTimeMs = 0;
  final List<int> _timesMs = [];
  final Stopwatch _stopwatch = Stopwatch();

  // 输入控制
  final TextEditingController _answerController = TextEditingController();
  String? _feedbackText;
  bool? _lastCorrect;

  // 可选筛选
  String? _selectedCalcType;
  List<String> _calcTypes = [];

  @override
  void initState() {
    super.initState();
    _loadCalcTypes();
  }

  Future<void> _loadCalcTypes() async {
    final service = context.read<SpeedTrainingService>();
    final types = await service.getCalcTypes();
    setState(() {
      _calcTypes = types;
      _isLoading = false;
    });
  }

  Future<void> _startTraining({String? calcType}) async {
    final service = context.read<SpeedTrainingService>();
    final exercises = await service.getExercises(
      calcType: calcType,
      limit: 20,
    );

    if (exercises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无练习题')),
        );
      }
      return;
    }

    final sessionId = await service.createSession(
      sessionType: 'daily_challenge',
      calcType: calcType ?? '',
      totalQuestions: exercises.length,
    );

    setState(() {
      _exercises = exercises;
      _sessionId = sessionId;
      _currentIndex = 0;
      _correctCount = 0;
      _totalTimeMs = 0;
      _timesMs.clear();
      _isFinished = false;
      _feedbackText = null;
      _lastCorrect = null;
    });

    _stopwatch.reset();
    _stopwatch.start();
  }

  void _submitAnswer() async {
    if (_exercises.isEmpty || _isFinished) return;

    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    _timesMs.add(elapsed);
    _totalTimeMs += elapsed;

    final exercise = _exercises[_currentIndex];
    final correctAnswer = double.tryParse(exercise['correct_answer'] ?? '0') ?? 0;
    final tolerance = (exercise['tolerance'] as num?)?.toDouble() ?? 0.01;
    final userInput = _answerController.text.trim();
    final userValue = double.tryParse(userInput);

    final isCorrect = userValue != null &&
        (userValue - correctAnswer).abs() <= tolerance;

    if (isCorrect) _correctCount++;

    final service = context.read<SpeedTrainingService>();
    await service.recordAnswer(
      sessionId: _sessionId!,
      exerciseId: exercise['id'] as int,
      userAnswer: userInput,
      isCorrect: isCorrect,
      timeMs: elapsed,
    );

    setState(() {
      _lastCorrect = isCorrect;
      _feedbackText = isCorrect
          ? '正确！用时 ${(elapsed / 1000).toStringAsFixed(1)}s'
          : '答案: ${exercise['correct_answer']}  ${exercise['shortcut_hint'] ?? ''}';
    });

    // 短暂显示反馈后进入下一题
    await Future.delayed(const Duration(milliseconds: 1500));

    if (_currentIndex + 1 >= _exercises.length) {
      await _finishSession();
    } else {
      setState(() {
        _currentIndex++;
        _feedbackText = null;
        _lastCorrect = null;
        _answerController.clear();
      });
      _stopwatch.reset();
      _stopwatch.start();
    }
  }

  Future<void> _finishSession() async {
    final avgTime = _timesMs.isEmpty ? 0 : _totalTimeMs ~/ _timesMs.length;
    final accuracy = _exercises.isEmpty
        ? 0.0
        : _correctCount / _exercises.length;

    final service = context.read<SpeedTrainingService>();
    await service.finishSession(
      sessionId: _sessionId!,
      correctCount: _correctCount,
      totalTimeMs: _totalTimeMs,
      avgTimeMs: avgTime,
      accuracy: accuracy,
    );

    setState(() {
      _isFinished = true;
      _feedbackText = null;
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('速算训练'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessionId == null
              ? _buildStartView()
              : _isFinished
                  ? _buildResultView()
                  : _buildQuizView(),
    );
  }

  // ===== 开始页 =====

  Widget _buildStartView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '选择训练类型',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 全部类型
          _buildTypeCard(
            title: '综合练习',
            subtitle: '随机 20 题限时挑战',
            icon: Icons.shuffle,
            color: const Color(0xFF667eea),
            onTap: () => _startTraining(),
          ),
          const SizedBox(height: 12),
          // 各类型
          ..._calcTypes.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTypeCard(
                  title: _calcTypeLabel(type),
                  subtitle: type,
                  icon: Icons.calculate,
                  color: const Color(0xFFF7971E),
                  onTap: () => _startTraining(calcType: type),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.7),
                  )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  // ===== 答题页 =====

  Widget _buildQuizView() {
    final exercise = _exercises[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 进度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_exercises.length}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                '正确 $_correctCount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _exercises.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF667eea)),
          ),
          const SizedBox(height: 24),
          // 题目
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  exercise['display_text'] ?? exercise['expression'] ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  exercise['expression'] ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 输入
          TextField(
            controller: _answerController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '输入答案',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onSubmitted: (_) => _submitAnswer(),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitAnswer,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('提交', style: TextStyle(fontSize: 16)),
          ),
          // 反馈
          if (_feedbackText != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_lastCorrect == true
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _feedbackText!,
                style: TextStyle(
                  color: _lastCorrect == true
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF5252),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== 结果页 =====

  Widget _buildResultView() {
    final accuracy = _exercises.isEmpty
        ? 0.0
        : _correctCount / _exercises.length * 100;
    final avgSec = _timesMs.isEmpty
        ? 0.0
        : _totalTimeMs / _timesMs.length / 1000;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Color(0xFFFFD200)),
            const SizedBox(height: 16),
            const Text('训练完成！', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 24),
            _buildStatRow('正确率', '${accuracy.toStringAsFixed(1)}%'),
            _buildStatRow('正确数', '$_correctCount / ${_exercises.length}'),
            _buildStatRow('平均用时', '${avgSec.toStringAsFixed(1)}s'),
            _buildStatRow('总用时', '${(_totalTimeMs / 1000).toStringAsFixed(1)}s'),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _sessionId = null;
                    _isFinished = false;
                  }),
                  child: const Text('再来一轮'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }

  String _calcTypeLabel(String type) {
    const labels = {
      'percentage_change': '增长率计算',
      'base_period': '基期计算',
      'proportion': '比重计算',
      'multiple': '倍数计算',
      'average': '平均数计算',
      'interval_growth': '间隔增长率',
      'mixed': '综合运算',
    };
    return labels[type] ?? type;
  }
}
