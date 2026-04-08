import 'package:flutter/material.dart';
import '../models/exam_category.dart';

/// SubjectCategory 的 UI 扩展（IconData/Color 放在 widget 层，不放在 model 中）
extension SubjectCategoryUI on SubjectCategory {
  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily);
  List<Color> get gradient => gradientColors.map(Color.new).toList();
  LinearGradient get linearGradient => LinearGradient(colors: gradient);
}
