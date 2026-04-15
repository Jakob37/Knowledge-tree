import 'package:flutter/material.dart';

import 'features/knowledge/presentation/knowledge_page.dart';

class KnowledgeApp extends StatelessWidget {
  const KnowledgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E5E56),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Knowledge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F1E7),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F1E7),
          foregroundColor: Color(0xFF18312D),
          elevation: 0,
        ),
      ),
      home: const KnowledgePage(),
    );
  }
}
