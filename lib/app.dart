import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'features/kanban/views/kanban_board_screen.dart';

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanban Board',
      theme: AppTheme.lightTheme,
      home: const KanbanBoardScreen(),
    );
  }
}
