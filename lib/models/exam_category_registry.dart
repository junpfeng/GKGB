import 'exam_category.dart';

/// 静态考试类型注册表，定义所有考试类型的科目、题量、时间等配置
class ExamCategoryRegistry {
  ExamCategoryRegistry._();

  // ===== 通用科目分类定义（复用） =====

  static const _xingceCategories = [
    SubjectCategory(category: '言语理解', label: '言语理解', iconCodePoint: 0xe25c, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF667eea, 0xFF764ba2]),
    SubjectCategory(category: '数量关系', label: '数量关系', iconCodePoint: 0xe06b, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFf093fb, 0xFFf5576c]),
    SubjectCategory(category: '判断推理', label: '判断推理', iconCodePoint: 0xe4a2, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF4776E6, 0xFF8E54E9]),
    SubjectCategory(category: '资料分析', label: '资料分析', iconCodePoint: 0xe063, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF0ED2F7, 0xFF09A6C3]),
    SubjectCategory(category: '常识判断', label: '常识判断', iconCodePoint: 0xe3f0, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFF7971E, 0xFFFFD200]),
  ];

  static const _shenlunCategory = SubjectCategory(
    category: '申论', label: '申论写作',
    iconCodePoint: 0xe0b6, iconFontFamily: 'MaterialIcons',
    gradientColors: [0xFF43E97B, 0xFF38F9D7],
  );

  static const _gongjiCategory = SubjectCategory(
    category: '公共基础知识', label: '公共基础知识',
    iconCodePoint: 0xe5dc, iconFontFamily: 'MaterialIcons',
    gradientColors: [0xFF09A6C3, 0xFF0ED2F7],
  );

  // ===== 行测科目（不同题量） =====

  static const _xingce135 = ExamSubject(
    subject: '行测', label: '行政职业能力测验',
    defaultQuestionCount: 135, defaultTimeLimitSeconds: 7200, totalScore: 100,
    categories: _xingceCategories,
  );

  static const _xingce130 = ExamSubject(
    subject: '行测', label: '行政职业能力测验',
    defaultQuestionCount: 130, defaultTimeLimitSeconds: 7200, totalScore: 100,
    categories: _xingceCategories,
  );

  static const _xingce120 = ExamSubject(
    subject: '行测', label: '行政职业能力测验',
    defaultQuestionCount: 120, defaultTimeLimitSeconds: 7200, totalScore: 100,
    categories: _xingceCategories,
  );

  static const _shenlun = ExamSubject(
    subject: '申论', label: '申论',
    defaultQuestionCount: 5, defaultTimeLimitSeconds: 9000, totalScore: 100,
    categories: [_shenlunCategory],
  );

  static const _gongji = ExamSubject(
    subject: '公基', label: '公共基础知识',
    defaultQuestionCount: 100, defaultTimeLimitSeconds: 5400, totalScore: 100,
    categories: [_gongjiCategory],
  );

  // ===== 国考 =====

  static const guokao = ExamCategory(
    id: 'guokao',
    label: '国考',
    description: '中央机关及其直属机构招考',
    scope: 'national',
    requiresProvince: false,
    contentStatus: ContentStatus.full,
    supportedFeatures: {Feature.practice, Feature.mockExam, Feature.essay, Feature.interview, Feature.realExam, Feature.studyPlan, Feature.hotTopics},
    dbExamTypeValues: ['国考'],
    interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变', '自我认知', '演讲'],
    defaultSubjects: [_xingce135, _shenlun],
    subTypes: [
      ExamSubType(id: 'fushenji', label: '副省级', subjects: [_xingce135, _shenlun]),
      ExamSubType(id: 'dishiji', label: '地市级', subjects: [_xingce130, _shenlun]),
    ],
  );

  // ===== 省考 =====

  static const shengkao = ExamCategory(
    id: 'shengkao',
    label: '省考',
    description: '各省公务员招录考试',
    scope: 'provincial',
    requiresProvince: true,
    contentStatus: ContentStatus.full,
    supportedFeatures: {Feature.practice, Feature.mockExam, Feature.essay, Feature.interview, Feature.realExam, Feature.studyPlan, Feature.hotTopics},
    dbExamTypeValues: ['省考'],
    interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变', '自我认知'],
    defaultSubjects: [_xingce120, _shenlun],
    subTypes: [
      ExamSubType(id: 'liankaosheng', label: '联考省份', subjects: [_xingce120, _shenlun]),
      ExamSubType(id: 'duli', label: '独立命题省份', subjects: [_xingce120, _shenlun]),
    ],
  );

  /// v1 覆盖的 8 个省份（仅标记名称，题量/时间用通用默认值）
  static const coveredProvinces = ['浙江', '江苏', '广东', '山东', '四川', '湖北', '河南', '北京'];

  // ===== 事业单位 =====

  // A 类科目
  static const _zhiceA = ExamSubject(
    subject: '职测', label: '职业能力倾向测验',
    defaultQuestionCount: 150, defaultTimeLimitSeconds: 5400, totalScore: 150,
    categories: [
      SubjectCategory(category: '常识判断', label: '常识判断', iconCodePoint: 0xe3f0, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFF7971E, 0xFFFFD200]),
      SubjectCategory(category: '言语运用', label: '言语理解与表达', iconCodePoint: 0xe25c, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF667eea, 0xFF764ba2]),
      SubjectCategory(category: '数量分析', label: '数量关系', iconCodePoint: 0xe06b, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFf093fb, 0xFFf5576c]),
      SubjectCategory(category: '判断推理', label: '判断推理', iconCodePoint: 0xe4a2, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF4776E6, 0xFF8E54E9]),
      SubjectCategory(category: '资料分析', label: '资料分析', iconCodePoint: 0xe063, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF0ED2F7, 0xFF09A6C3]),
    ],
  );

  static const _zongyingA = ExamSubject(
    subject: '综合', label: '综合应用能力',
    defaultQuestionCount: 3, defaultTimeLimitSeconds: 9000, totalScore: 150,
    categories: [
      SubjectCategory(category: '综合应用', label: '综合应用能力', iconCodePoint: 0xe0b6, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF43E97B, 0xFF38F9D7]),
    ],
  );

  // B 类科目
  static const _zhiceB = ExamSubject(
    subject: '职测', label: '职业能力倾向测验',
    defaultQuestionCount: 150, defaultTimeLimitSeconds: 5400, totalScore: 150,
    categories: [
      SubjectCategory(category: '常识判断', label: '常识判断', iconCodePoint: 0xe3f0, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFF7971E, 0xFFFFD200]),
      SubjectCategory(category: '言语运用', label: '言语理解与表达', iconCodePoint: 0xe25c, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF667eea, 0xFF764ba2]),
      SubjectCategory(category: '数量分析', label: '数量分析与资料分析', iconCodePoint: 0xe06b, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFf093fb, 0xFFf5576c]),
      SubjectCategory(category: '判断推理', label: '判断推理', iconCodePoint: 0xe4a2, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF4776E6, 0xFF8E54E9]),
      SubjectCategory(category: '综合分析', label: '综合分析', iconCodePoint: 0xe063, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF0ED2F7, 0xFF09A6C3]),
    ],
  );

  static const _zongyingB = ExamSubject(
    subject: '综合', label: '综合应用能力',
    defaultQuestionCount: 3, defaultTimeLimitSeconds: 9000, totalScore: 150,
    categories: [
      SubjectCategory(category: '综合应用', label: '综合应用能力(B类)', iconCodePoint: 0xe0b6, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF43E97B, 0xFF38F9D7]),
    ],
  );

  // C 类科目
  static const _zhiceC = ExamSubject(
    subject: '职测', label: '职业能力倾向测验',
    defaultQuestionCount: 150, defaultTimeLimitSeconds: 5400, totalScore: 150,
    categories: [
      SubjectCategory(category: '常识判断', label: '常识判断', iconCodePoint: 0xe3f0, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFF7971E, 0xFFFFD200]),
      SubjectCategory(category: '言语理解', label: '言语理解与表达', iconCodePoint: 0xe25c, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF667eea, 0xFF764ba2]),
      SubjectCategory(category: '数量分析', label: '数量分析与资料分析', iconCodePoint: 0xe06b, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFf093fb, 0xFFf5576c]),
      SubjectCategory(category: '判断推理', label: '判断推理', iconCodePoint: 0xe4a2, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF4776E6, 0xFF8E54E9]),
      SubjectCategory(category: '综合分析', label: '综合分析', iconCodePoint: 0xe063, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF0ED2F7, 0xFF09A6C3]),
    ],
  );

  static const _zongyingC = ExamSubject(
    subject: '综合', label: '综合应用能力',
    defaultQuestionCount: 3, defaultTimeLimitSeconds: 9000, totalScore: 150,
    categories: [
      SubjectCategory(category: '综合应用', label: '综合应用能力(C类)', iconCodePoint: 0xe0b6, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF43E97B, 0xFF38F9D7]),
    ],
  );

  static const shiyebian = ExamCategory(
    id: 'shiyebian',
    label: '事业单位',
    description: '事业单位公开招聘',
    scope: 'provincial',
    requiresProvince: true,
    contentStatus: ContentStatus.partial,
    supportedFeatures: {Feature.practice, Feature.mockExam, Feature.interview, Feature.studyPlan},
    dbExamTypeValues: ['事业编', '事业单位'],
    interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变'],
    defaultSubjects: [_zhiceA, _zongyingA],
    subTypes: [
      ExamSubType(id: 'typeA', label: '综合管理类(A类)', subjects: [_zhiceA, _zongyingA]),
      ExamSubType(id: 'typeB', label: '社会科学专技类(B类)', subjects: [_zhiceB, _zongyingB]),
      ExamSubType(id: 'typeC', label: '自然科学专技类(C类)', subjects: [_zhiceC, _zongyingC]),
    ],
  );

  // ===== 选调生 =====

  static const xuandiao = ExamCategory(
    id: 'xuandiao',
    label: '选调生',
    description: '选调优秀大学毕业生到基层锻炼',
    scope: 'provincial',
    requiresProvince: true,
    contentStatus: ContentStatus.partial,
    supportedFeatures: {Feature.practice, Feature.mockExam, Feature.essay, Feature.interview, Feature.studyPlan},
    dbExamTypeValues: ['选调', '选调生'],
    interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变', '自我认知'],
    defaultSubjects: [_xingce120, _shenlun],
    subTypes: [],
  );

  // ===== 三支一扶 =====

  static const sanzhiyifu = ExamCategory(
    id: 'sanzhiyifu',
    label: '三支一扶',
    description: '支教、支农、支医和扶贫',
    scope: 'provincial',
    requiresProvince: true,
    contentStatus: ContentStatus.partial,
    supportedFeatures: {Feature.practice, Feature.studyPlan},
    dbExamTypeValues: ['三支一扶'],
    interviewCategories: ['综合分析', '计划组织', '人际关系'],
    defaultSubjects: [_gongji],
    subTypes: [],
  );

  // ===== 人才引进 =====

  static const rencaiyinjin = ExamCategory(
    id: 'rencaiyinjin',
    label: '人才引进',
    description: '各地人才引进计划',
    scope: 'variable',
    requiresProvince: false, // 人才引进不限定省份，通过岗位匹配选择具体地区
    contentStatus: ContentStatus.partial,
    supportedFeatures: {Feature.positionMatch, Feature.practice, Feature.interview, Feature.studyPlan},
    dbExamTypeValues: ['人才引进'],
    interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变', '自我认知'],
    defaultSubjects: [_xingce120, _shenlun], // 默认行测+申论，可被目标岗位动态覆盖
    subTypes: [],
  );

  // ===== 注册表查询 =====

  static const List<ExamCategory> allCategories = [
    guokao,
    shengkao,
    shiyebian,
    xuandiao,
    sanzhiyifu,
    rencaiyinjin,
  ];

  /// 按 id 查找考试类型
  static ExamCategory? findById(String id) {
    for (final c in allCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 按 id 查找子类型
  static ExamSubType? findSubType(String categoryId, String subTypeId) {
    final category = findById(categoryId);
    if (category == null || subTypeId.isEmpty) return null;
    for (final st in category.subTypes) {
      if (st.id == subTypeId) return st;
    }
    return null;
  }

  /// 获取所有可选类型（排除 comingSoon）
  static List<ExamCategory> get selectableCategories =>
      allCategories.where((c) => c.contentStatus != ContentStatus.comingSoon).toList();
}
