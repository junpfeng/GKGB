import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'db/database_helper.dart';
import 'services/question_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseHelper>.value(value: DatabaseHelper.instance),
        ChangeNotifierProvider(create: (_) => QuestionService()),
      ],
      child: const ExamPrepApp(),
    ),
  );
}
