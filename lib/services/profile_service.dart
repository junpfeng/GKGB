import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/user_profile.dart';

/// 用户画像服务：CRUD 用户个人信息
class ProfileService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  UserProfile? _profile;
  bool _isLoading = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null && _profile!.education != null;

  /// 加载用户画像
  Future<UserProfile?> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final row = await _db.queryProfile();
      _profile = row != null ? UserProfile.fromDb(row) : null;
      return _profile;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存/更新用户画像
  Future<void> saveProfile(UserProfile profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.upsertProfile(profile.toDb());
      _profile = profile;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新单个字段
  Future<void> updateField(UserProfile updatedProfile) async {
    await saveProfile(updatedProfile);
  }
}
