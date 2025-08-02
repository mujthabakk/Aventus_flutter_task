import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:kanban_board/core/config/%20app_colors.dart';
import 'package:kanban_board/features/kanban/task_dialog.dart';
import 'package:kanban_board/utils/extensions.dart';

import '../../../core/models/task_model.dart';
import '../providers/kanban_provider.dart';
import 'task_dialog.dart' hide TaskDialog;

class KanbanBoardScreen extends ConsumerWidget {
  const KanbanBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final toDoTasks = tasks.where((t) => t.status == 'To Do').toList();
    final inProgressTasks =
        tasks.where((t) => t.status == 'In Progress').toList();
    final doneTasks = tasks.where((t) => t.status == 'Done').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const TaskDialog(),
            ),
          ),
        ],
      ),
      body: DragAndDropLists(
        children: [
          DragAndDropList(
            header: const _ColumnHeader('To Do', AppColors.cardToDo),
            children: toDoTasks
                .map((task) => DragAndDropItem(child: _TaskCard(task)))
                .toList(),
          ),
          DragAndDropList(
            header:
                const _ColumnHeader('In Progress', AppColors.cardInProgress),
            children: inProgressTasks
                .map((task) => DragAndDropItem(child: _TaskCard(task)))
                .toList(),
          ),
          DragAndDropList(
            header: const _ColumnHeader('Done', AppColors.cardDone),
            children: doneTasks
                .map((task) => DragAndDropItem(child: _TaskCard(task)))
                .toList(),
          ),
        ],
        onItemReorder:
            (oldItemIndex, oldListIndex, newItemIndex, newListIndex) {
          final statusMap = ['To Do', 'In Progress', 'Done'];
          final task = tasks.firstWhere((t) =>
              t.status == statusMap[oldListIndex] &&
              tasks
                      .where((t2) => t2.status == statusMap[oldListIndex])
                      .toList()[oldItemIndex] ==
                  t);
          ref.read(tasksProvider.notifier).updateTask(
                task.copyWith(status: statusMap[newListIndex]),
              );
        },
        onListReorder: (_, __) {},
        axis: Axis.horizontal,
        listWidth: MediaQuery.of(context).size.width / 3 - 16,
        listPadding: const EdgeInsets.all(8),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _ColumnHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;

  const _TaskCard(this.task);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text(task.description,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => showDialog(
          context: context,
          builder: (_) => TaskDialog(task: task),
        ),
      ),
    );
  }
}
