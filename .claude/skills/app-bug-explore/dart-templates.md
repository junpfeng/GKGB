# Dart 测试/调试模板

## Widget Test 模板

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// 测试 Screen 的基本渲染
void main() {
  testWidgets('{ScreenName} 基本渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => {ServiceName}(),
          child: const {ScreenName}(),
        ),
      ),
    );

    // 验证关键 widget 存在
    expect(find.byType({WidgetType}), findsOneWidget);
    expect(find.text('{预期文本}'), findsOneWidget);
  });
}
```

## Provider/ChangeNotifier Test 模板

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('{ServiceName}', () {
    late {ServiceName} service;

    setUp(() {
      service = {ServiceName}();
    });

    test('初始状态', () {
      expect(service.{属性}, equals({初始值}));
    });

    test('{方法名} 更新状态', () {
      service.{方法名}({参数});
      expect(service.{属性}, equals({预期值}));
    });
  });
}
```

## SQLite Database Test 模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // 使用 ffi 在测试环境初始化 SQLite
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('数据库表创建', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // 复制 database_helper.dart 的建表 SQL
        await db.execute('''
          CREATE TABLE {table_name} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            {field} {TYPE}
          )
        ''');
      },
    );

    // 验证表存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='{table_name}'"
    );
    expect(tables.length, 1);

    await db.close();
  });

  test('数据库迁移', () async {
    // 先创建 v1 数据库
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY)');
      },
    );
    await db.close();

    // 升级到 v2
    final db2 = await openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE test ADD COLUMN name TEXT');
        }
      },
    );

    // 验证新字段存在
    final info = await db2.rawQuery('PRAGMA table_info(test)');
    expect(info.any((col) => col['name'] == 'name'), isTrue);

    await db2.close();
  });
}
```

## LLM Service Mock 模板

```dart
import 'package:flutter_test/flutter_test.dart';

// 实现 LlmProvider 接口的 Mock
class MockLlmProvider implements LlmProvider {
  @override
  String get name => 'mock';

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    return '模拟回复：${messages.last.content}';
  }

  @override
  Stream<String> streamChat(List<ChatMessage> messages) async* {
    yield '模拟';
    yield '流式';
    yield '回复';
  }

  @override
  Future<bool> testConnection() async => true;
}

void main() {
  test('LlmManager fallback', () async {
    final manager = LlmManager();
    final primary = MockLlmProvider();
    final fallback = MockLlmProvider();

    manager.registerProvider(primary);
    manager.setDefault('mock');
    manager.setFallback('mock');

    final result = await manager.chat([
      ChatMessage(role: 'user', content: '测试'),
    ]);
    expect(result, contains('模拟回复'));
  });
}
```

## Integration Test 模板

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:exam_prep_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('底部导航切换', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 验证首页
    expect(find.text('刷题'), findsOneWidget);

    // 切换到模拟考试
    await tester.tap(find.byIcon(Icons.assignment));
    await tester.pumpAndSettle();
    expect(find.text('模拟考试'), findsOneWidget);

    // 切换到个人信息
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    expect(find.text('个人信息'), findsOneWidget);
  });
}
```
