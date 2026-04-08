// 考试类型配置模型族（静态定义，非数据库存储）

/// 内容就绪状态
enum ContentStatus { full, partial, comingSoon }

/// 功能开关
enum Feature {
  practice,
  mockExam,
  essay,
  interview,
  positionMatch,
  realExam,
  studyPlan,
  hotTopics,
}

/// 考试类型配置
class ExamCategory {
  final String id; // 'guokao', 'shengkao', 'shiyebian', 'xuandiao', 'rencaiyinjin', 'sanzhiyifu'
  final String label; // '国考', '省考', '事业单位' 等
  final String description;
  final String scope; // 'national', 'provincial', 'municipal', 'variable'
  final bool requiresProvince;
  final ContentStatus contentStatus;
  final List<ExamSubType> subTypes;
  final List<ExamSubject> defaultSubjects;
  final List<String> interviewCategories;
  final List<String> dbExamTypeValues; // 映射到 DB 中 exam_type 字段值
  final Set<Feature> supportedFeatures;

  const ExamCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.scope,
    required this.requiresProvince,
    required this.contentStatus,
    required this.subTypes,
    required this.defaultSubjects,
    required this.interviewCategories,
    required this.dbExamTypeValues,
    required this.supportedFeatures,
  });
}

/// 考试子类型（如副省级/地市级、事业编A/B/C类）
class ExamSubType {
  final String id;
  final String label;
  final List<ExamSubject> subjects; // 始终已填充

  const ExamSubType({
    required this.id,
    required this.label,
    required this.subjects,
  });
}

/// 考试科目配置
class ExamSubject {
  final String subject; // '行测', '申论', '职测', '综合', '公基'
  final String label; // 显示名称
  final int defaultQuestionCount;
  final int defaultTimeLimitSeconds;
  final double totalScore;
  final List<SubjectCategory> categories;

  const ExamSubject({
    required this.subject,
    required this.label,
    required this.defaultQuestionCount,
    required this.defaultTimeLimitSeconds,
    required this.totalScore,
    required this.categories,
  });
}

/// 科目下的练习分类
class SubjectCategory {
  final String category; // DB 中的 category 值
  final String label; // 显示名称
  final int iconCodePoint;
  final String iconFontFamily;
  final List<int> gradientColors; // 如 [0xFF667eea, 0xFF764ba2]

  const SubjectCategory({
    required this.category,
    required this.label,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.gradientColors,
  });
}
