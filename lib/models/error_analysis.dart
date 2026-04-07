/// 错因分析结果（纯数据类，非 DB 表）
class ErrorAnalysis {
  final String errorType; // blind_spot / confusion / careless / timeout / trap
  final String analysis;  // AI 分析文本

  const ErrorAnalysis({
    required this.errorType,
    this.analysis = '',
  });

  /// 错因类型中文标签
  static const Map<String, String> errorTypeLabels = {
    'blind_spot': '知识盲区',
    'confusion': '概念混淆',
    'careless': '粗心大意',
    'timeout': '时间不足',
    'trap': '陷阱题',
  };

  /// 错因类型对应颜色值（十六进制）
  static const Map<String, int> errorTypeColors = {
    'blind_spot': 0xFFE74C3C,
    'confusion': 0xFFF39C12,
    'careless': 0xFF3498DB,
    'timeout': 0xFF9B59B6,
    'trap': 0xFF1ABC9C,
  };

  String get label => errorTypeLabels[errorType] ?? errorType;
}
