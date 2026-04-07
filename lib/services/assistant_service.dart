import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;
import '../services/llm/llm_manager.dart';
import '../services/llm/llm_provider.dart';
import '../services/question_service.dart';
import '../services/exam_service.dart';
import '../services/match_service.dart';
import '../services/study_plan_service.dart';
import '../services/profile_service.dart';
import '../services/baseline_service.dart';
import '../widgets/ai_assistant/assistant_tools.dart';

export '../widgets/ai_assistant/assistant_tools.dart';

/// 助手三态枚举
enum AssistantState { hidden, minimized, expanded }

/// 导航回调类型（由 HomeScreen 注册）
typedef NavigationCallback = void Function(int tabIndex);

/// AI 助手核心服务：状态管理、消息历史、system prompt、工具分发
class AssistantService extends ChangeNotifier {
  // ===== 依赖注入 =====
  final LlmManager _llm;
  final QuestionService _questionService;
  final ExamService _examService;
  final MatchService _matchService;
  final StudyPlanService _studyPlanService;
  final ProfileService _profileService;
  final BaselineService _baselineService;

  // ===== 状态 =====
  AssistantState _state = AssistantState.minimized;
  List<AssistantMessage> _messages = [];
  bool _isLoading = false;
  String _currentScreen = 'practice';
  Map<String, dynamic> _screenData = {};
  Offset _bubblePosition = const Offset(-1, -1); // -1 表示使用默认位置
  int? _pendingNavigation;    // 待执行导航 index [C-1]
  bool _privacyGranted = false; // 隐私授权状态 [H-1]

  /// 流式响应（用独立 ValueNotifier，避免主 notifyListeners 频繁重建）[C-3]
  final ValueNotifier<String> streamingResponse = ValueNotifier('');

  // ===== 导航回调（由 HomeScreen 注册）[C-1] =====
  NavigationCallback? _onNavigate;

  // ===== Getters =====
  AssistantState get state => _state;
  List<AssistantMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get currentScreen => _currentScreen;
  Offset get bubblePosition => _bubblePosition;
  int? get pendingNavigation => _pendingNavigation;
  bool get privacyGranted => _privacyGranted;

  AssistantService({
    required LlmManager llm,
    required QuestionService questionService,
    required ExamService examService,
    required MatchService matchService,
    required StudyPlanService studyPlanService,
    required ProfileService profileService,
    required BaselineService baselineService,
  })  : _llm = llm,
        _questionService = questionService,
        _examService = examService,
        _matchService = matchService,
        _studyPlanService = studyPlanService,
        _profileService = profileService,
        _baselineService = baselineService;

  // ===== 状态控制 =====

  void show() {
    if (_state == AssistantState.hidden) {
      _state = AssistantState.minimized;
      notifyListeners();
    }
  }

  void expand() {
    if (_state != AssistantState.expanded) {
      _state = AssistantState.expanded;
      notifyListeners();
    }
  }

  void minimize() {
    if (_state != AssistantState.minimized) {
      _state = AssistantState.minimized;
      notifyListeners();
    }
  }

  void hide() {
    _state = AssistantState.hidden;
    notifyListeners();
  }

  /// 更新悬浮球位置
  void updateBubblePosition(Offset position) {
    _bubblePosition = position;
    // 不 notifyListeners，避免重绘整个树
  }

  // ===== 导航回调注册 =====

  void registerNavigationCallback(NavigationCallback callback) {
    _onNavigate = callback;
  }

  /// 消费待执行导航（UI 层读取后调用，清除 pendingNavigation）
  void consumeNavigation() {
    _pendingNavigation = null;
    // 不需要 notifyListeners，UI 已经执行过导航
  }

  // ===== 上下文更新 =====

  /// 各 screen 切换时调用，更新当前页面上下文
  void updateContext(String screenName, {Map<String, dynamic>? data}) {
    _currentScreen = screenName;
    _screenData = data ?? {};
    // 不 notifyListeners，只影响下次 LLM 调用时的 system prompt
  }

  // ===== 隐私授权 [H-1] =====

  void grantPrivacy() {
    _privacyGranted = true;
    notifyListeners();
  }

  // ===== 消息管理 =====

  void clearMessages() {
    _messages = [];
    streamingResponse.value = '';
    notifyListeners();
  }

  // ===== LLM 消息发送 =====

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isLoading) return;

    // 添加用户消息
    final userMsg = AssistantMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: 'user',
      content: text.trim(),
      displayText: text.trim(),
      actions: const [],
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    _messages.add(userMsg);
    _isLoading = true;
    streamingResponse.value = '';
    notifyListeners();

    // 检查 LLM 是否配置
    if (!_llm.hasProvider) {
      _appendErrorMessage('未配置 AI 模型，请前往"我的 → AI 模型设置"添加模型。');
      return;
    }

    // 构建发送给 LLM 的消息（system + 最近 20 条）[H-2]
    final messagesToSend = _buildMessagesToSend();

    // 创建流式响应消息占位
    final streamingMsgId = '${DateTime.now().microsecondsSinceEpoch}_streaming';
    final streamingMsg = AssistantMessage(
      id: streamingMsgId,
      role: 'assistant',
      content: '',
      displayText: '',
      actions: const [],
      timestamp: DateTime.now(),
      status: MessageStatus.streaming,
    );
    _messages.add(streamingMsg);
    notifyListeners();

    final buffer = StringBuffer();
    try {
      await for (final chunk in _llm.streamChat(messagesToSend)) {
        buffer.write(chunk);
        streamingResponse.value = buffer.toString();
      }

      final rawResponse = buffer.toString();
      final display = stripActionTags(rawResponse);
      final actions = parseToolCommands(rawResponse, role: 'assistant');

      // 替换占位消息为完整消息
      final completedMsg = AssistantMessage(
        id: streamingMsgId,
        role: 'assistant',
        content: rawResponse,
        displayText: display,
        actions: actions,
        timestamp: DateTime.now(),
        status: MessageStatus.completed,
      );
      final idx = _messages.indexWhere((m) => m.id == streamingMsgId);
      if (idx >= 0) {
        _messages[idx] = completedMsg;
      }

      streamingResponse.value = '';
      _isLoading = false;
      notifyListeners();

      // 执行工具命令（fail-fast）[LOW-5]
      if (actions.isNotEmpty) {
        await _executeActions(actions);
      }
    } catch (e) {
      // 替换为错误消息
      final errMsg = AssistantMessage(
        id: streamingMsgId,
        role: 'assistant',
        content: 'AI 响应失败：$e',
        displayText: 'AI 响应失败：$e',
        actions: const [],
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        errorMessage: e.toString(),
      );
      final idx = _messages.indexWhere((m) => m.id == streamingMsgId);
      if (idx >= 0) {
        _messages[idx] = errMsg;
      }
      streamingResponse.value = '';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== 私有辅助方法 =====

  /// 构建发送给 LLM 的消息列表（system + 最近 20 条）[H-2]
  List<ChatMessage> _buildMessagesToSend() {
    final systemPrompt = _buildSystemPrompt();
    final recentMessages = _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .where((m) => m.status == MessageStatus.completed || m.status == MessageStatus.sending)
        .toList();
    // 最近 20 条
    final limited = recentMessages.length > 20
        ? recentMessages.sublist(recentMessages.length - 20)
        : recentMessages;

    return [
      ChatMessage(role: 'system', content: systemPrompt),
      ...limited.map((m) => m.toChatMessage()),
    ];
  }

  /// 追加错误提示消息
  void _appendErrorMessage(String errorText) {
    _messages.add(AssistantMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: 'assistant',
      content: errorText,
      displayText: errorText,
      actions: const [],
      timestamp: DateTime.now(),
      status: MessageStatus.error,
      errorMessage: errorText,
    ));
    _isLoading = false;
    notifyListeners();
  }

  /// 追加系统错误消息（工具执行失败时）[LOW-5]
  void _appendSystemMessage(String text) {
    _messages.add(AssistantMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: 'system',
      content: text,
      displayText: text,
      actions: const [],
      timestamp: DateTime.now(),
      status: MessageStatus.completed,
    ));
    notifyListeners();
  }

  // ===== System Prompt 三段式构建 =====

  String _buildSystemPrompt() {
    final buffer = StringBuffer();

    // 第一段：身份定义（固定）
    buffer.writeln('你是"考公智能助手"，专业的公务员考试备考助手。你可以帮助用户：');
    buffer.writeln('刷题练习、模拟考试、岗位匹配分析、学习计划制定、统计分析。请用简洁友好的中文回答。');
    buffer.writeln();

    // 第二段：工具列表（固定）
    buffer.writeln('当用户需要执行操作时，在回复末尾用 [ACTION:tool(param=value)] 标注：');
    buffer.writeln();
    buffer.writeln('**导航类：**');
    buffer.writeln('- [ACTION:navigate(screen=practice)] — 切换到刷题页');
    buffer.writeln('- [ACTION:navigate(screen=exam)] — 切换到模考页');
    buffer.writeln('- [ACTION:navigate(screen=match)] — 切换到岗位匹配页');
    buffer.writeln('- [ACTION:navigate(screen=stats)] — 切换到统计页');
    buffer.writeln('- [ACTION:navigate(screen=profile)] — 切换到个人信息页');
    buffer.writeln();
    buffer.writeln('**刷题类：**');
    buffer.writeln('- [ACTION:start_practice(subject=言语理解)] — 开始练习');
    buffer.writeln('- [ACTION:load_wrong_questions(subject=数量关系)] — 查看错题');
    buffer.writeln('- [ACTION:toggle_favorite(questionId=123)] — 收藏/取消收藏题目');
    buffer.writeln();
    buffer.writeln('**考试类：**');
    buffer.writeln('- [ACTION:start_exam(subject=行测,count=20,timeSeconds=3600)] — 开始模考');
    buffer.writeln('- [ACTION:show_exam_history()] — 查看考试历史');
    buffer.writeln();
    buffer.writeln('**学习规划类：**');
    buffer.writeln('- [ACTION:generate_plan(examDate=2026-05-01)] — 生成学习计划');
    buffer.writeln('- [ACTION:adjust_plan()] — 调整学习计划');
    buffer.writeln('- [ACTION:start_baseline(subjects=言语理解|数量关系)] — 摸底测试');
    buffer.writeln();
    buffer.writeln('**其他：**');
    buffer.writeln('- [ACTION:run_match()] — 执行岗位匹配');
    buffer.writeln('- [ACTION:show_stats()] — 查看统计');
    buffer.writeln();

    // 第三段：当前上下文（动态）
    buffer.writeln('**当前上下文：**');
    buffer.writeln('当前页面：${_screenContextDescription()}');

    // 用户画像（隐私授权后才添加）[H-1]
    final profile = _profileService.profile;
    if (_privacyGranted && profile != null) {
      final parts = <String>[];
      if (profile.education != null) parts.add(profile.education!);
      if (profile.major != null) parts.add('${profile.major!}专业');
      if (profile.workYears > 0) parts.add('${profile.workYears}年工作经验');
      if (parts.isNotEmpty) {
        buffer.writeln('用户画像：${parts.join('，')}');
      }
    }

    // 今日学习统计
    if (_questionService.answeredCount > 0) {
      final accuracy = (_questionService.accuracy * 100).toStringAsFixed(0);
      buffer.writeln('今日学习：已做${_questionService.answeredCount}题，正确率$accuracy%');
    }

    // 学习计划状态
    if (_studyPlanService.hasPlan && _studyPlanService.activePlan != null) {
      final plan = _studyPlanService.activePlan!;
      if (plan.examDate != null) {
        final examDt = DateTime.tryParse(plan.examDate!);
        if (examDt != null) {
          final daysLeft = examDt.difference(DateTime.now()).inDays;
          buffer.writeln('学习计划：距考试$daysLeft天');
        }
      }
    }

    return buffer.toString();
  }

  /// 根据 screenData 构建当前页面描述
  String _screenContextDescription() {
    switch (_currentScreen) {
      case 'practice':
        final subject = _screenData['subject'] as String? ?? '';
        final current = _screenData['current'] as int? ?? 0;
        final total = _screenData['total'] as int? ?? 0;
        if (subject.isNotEmpty) {
          return '刷题（$subject，第$current题/共$total题）';
        }
        return '刷题页';
      case 'exam':
        return '模考页';
      case 'match':
        return '岗位匹配页';
      case 'stats':
        return '统计页';
      case 'profile':
        return '个人信息页';
      default:
        return _currentScreen;
    }
  }

  // ===== 工具执行器（Phase 3：12 个 ACTION）=====

  /// 按顺序执行工具命令，fail-fast [LOW-5]
  Future<void> _executeActions(List<ToolCommand> commands) async {
    for (final cmd in commands) {
      try {
        await _executeSingleAction(cmd);
      } catch (e) {
        // fail-fast：前一个失败终止后续，错误作为 system 消息追加 [LOW-5]
        debugPrint('[AssistantService] 工具执行失败：${cmd.name} - $e');
        _appendSystemMessage('操作"${cmd.name}"执行失败：$e');
        return; // 终止后续
      }
    }
  }

  Future<void> _executeSingleAction(ToolCommand cmd) async {
    switch (cmd.name) {
      case 'navigate':
        await _executeNavigate(cmd.params);
        break;
      case 'start_practice':
        await _executeStartPractice(cmd.params);
        break;
      case 'load_wrong_questions':
        await _executeLoadWrongQuestions(cmd.params);
        break;
      case 'toggle_favorite':
        await _executeToggleFavorite(cmd.params);
        break;
      case 'start_exam':
        await _executeStartExam(cmd.params);
        break;
      case 'show_exam_history':
        await _executeShowExamHistory();
        break;
      case 'generate_plan':
        await _executeGeneratePlan(cmd.params);
        break;
      case 'adjust_plan':
        await _executeAdjustPlan();
        break;
      case 'start_baseline':
        await _executeStartBaseline(cmd.params);
        break;
      case 'run_match':
        await _executeRunMatch();
        break;
      case 'show_stats':
        await _executeShowStats();
        break;
      default:
        debugPrint('[AssistantService] 未知工具：${cmd.name}');
    }
  }

  // 导航 → 设置 pendingNavigation [C-1]
  Future<void> _executeNavigate(Map<String, String> params) async {
    final screen = params['screen'] ?? '';
    final index = screenTabIndex[screen];
    if (index != null) {
      _pendingNavigation = index;
      // 通知 UI 消费导航
      notifyListeners();
      // 同时尝试直接调用回调
      _onNavigate?.call(index);
    } else {
      throw Exception('未知页面：$screen');
    }
  }

  // 开始练习 → QuestionService + 导航到刷题页
  Future<void> _executeStartPractice(Map<String, String> params) async {
    final subject = params['subject'];
    final category = params['category'];
    final type = params['type'];

    await _questionService.loadQuestions(
      subject: subject,
      category: category,
      type: type,
      limit: 20,
    );
    // 导航到刷题页
    _pendingNavigation = 0;
    notifyListeners();
    _onNavigate?.call(0);
  }

  // 加载错题 → QuestionService
  Future<void> _executeLoadWrongQuestions(Map<String, String> params) async {
    final subject = params['subject'];
    await _questionService.loadWrongQuestions(subject: subject);
    // 导航到刷题页
    _pendingNavigation = 0;
    notifyListeners();
    _onNavigate?.call(0);
  }

  // 收藏/取消收藏
  Future<void> _executeToggleFavorite(Map<String, String> params) async {
    final questionIdStr = params['questionId'] ?? '';
    final questionId = int.tryParse(questionIdStr);
    if (questionId != null) {
      await _questionService.toggleFavorite(questionId);
    } else {
      throw Exception('无效的 questionId：$questionIdStr');
    }
  }

  // 开始模考 → ExamService + 导航
  Future<void> _executeStartExam(Map<String, String> params) async {
    final subject = params['subject'] ?? '行测';
    final count = int.tryParse(params['count'] ?? '20') ?? 20;
    final timeSeconds = int.tryParse(params['timeSeconds'] ?? '3600') ?? 3600;

    await _examService.startExam(
      subject: subject,
      totalQuestions: count,
      timeLimitSeconds: timeSeconds,
    );
    // 导航到模考页
    _pendingNavigation = 1;
    notifyListeners();
    _onNavigate?.call(1);
  }

  // 查看考试历史 → 导航到模考页
  Future<void> _executeShowExamHistory() async {
    await _examService.loadHistory();
    _pendingNavigation = 1;
    notifyListeners();
    _onNavigate?.call(1);
  }

  // 生成学习计划 → StudyPlanService
  Future<void> _executeGeneratePlan(Map<String, String> params) async {
    final examDate = params['examDate'];
    await _studyPlanService.generatePlan(examDate: examDate);
  }

  // 调整学习计划 → StudyPlanService
  Future<void> _executeAdjustPlan() async {
    await _studyPlanService.adjustPlan();
  }

  // 摸底测试 → BaselineService + 导航到刷题页
  Future<void> _executeStartBaseline(Map<String, String> params) async {
    final subjectsStr = params['subjects'] ?? '言语理解|数量关系';
    final subjects = subjectsStr.split('|').where((s) => s.isNotEmpty).toList();
    if (subjects.isEmpty) {
      throw Exception('未指定摸底科目');
    }
    await _baselineService.startBaseline(subjects);
    // 导航到刷题页
    _pendingNavigation = 0;
    notifyListeners();
    _onNavigate?.call(0);
  }

  // 执行岗位匹配 → MatchService + 导航
  Future<void> _executeRunMatch() async {
    await _matchService.runMatching();
    _pendingNavigation = 2;
    notifyListeners();
    _onNavigate?.call(2);
  }

  // 查看统计 → 导航到统计页
  Future<void> _executeShowStats() async {
    _pendingNavigation = 3;
    notifyListeners();
    _onNavigate?.call(3);
  }

  @override
  void dispose() {
    streamingResponse.dispose();
    super.dispose();
  }
}
