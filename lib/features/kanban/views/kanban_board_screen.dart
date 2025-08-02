import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/features/kanban/providers/kanban_provider.dart';
import 'package:kanban_board/features/kanban/task_dialog.dart';
import 'package:kanban_board/utils/extensions.dart';
import '../../../core/models/task_model.dart';

class KanbanBoardScreen extends ConsumerStatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  ConsumerState<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends ConsumerState<KanbanBoardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Trigger initial sync to ensure tasks are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kanbanControllerProvider).syncTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.dashboard_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Kanban Board',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const TaskDialog(),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add Task',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: tasksAsync.when(
              data: (tasks) {
                final toDoCount =
                    tasks.where((t) => t.status == 'To Do').length;
                final inProgressCount =
                    tasks.where((t) => t.status == 'In Progress').length;
                final doneCount = tasks.where((t) => t.status == 'Done').length;

                return TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF6366F1),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF6366F1),
                  indicatorWeight: 3,
                  dividerColor: Colors.grey.shade200,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  tabs: [
                    Tab(
                      child: _TabLabel(
                        'To Do',
                        toDoCount,
                        Icons.pending_actions_outlined,
                        const Color(0xFFEF4444),
                      ),
                    ),
                    Tab(
                      child: _TabLabel(
                        'In Progress',
                        inProgressCount,
                        Icons.hourglass_empty_outlined,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    Tab(
                      child: _TabLabel(
                        'Done',
                        doneCount,
                        Icons.check_circle_outline,
                        const Color(0xFF10B981),
                      ),
                    ),
                  ],
                );
              },
              loading: () => TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'To Do'),
                  Tab(text: 'In Progress'),
                  Tab(text: 'Done'),
                ],
              ),
              error: (_, __) => TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'To Do'),
                  Tab(text: 'In Progress'),
                  Tab(text: 'Done'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: tasksAsync.when(
        data: (tasks) {
          final toDoTasks = tasks.where((t) => t.status == 'To Do').toList();
          final inProgressTasks =
              tasks.where((t) => t.status == 'In Progress').toList();
          final doneTasks = tasks.where((t) => t.status == 'Done').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _TaskListView(
                tasks: toDoTasks,
                status: 'To Do',
                emptyMessage: 'No tasks to do',
                emptyIcon: Icons.pending_actions_outlined,
                color: const Color(0xFFEF4444),
                ref: ref,
                onReorder: (oldIndex, newIndex, status) async {
                  await _handleReorder(oldIndex, newIndex, toDoTasks, status);
                },
              ),
              _TaskListView(
                tasks: inProgressTasks,
                status: 'In Progress',
                emptyMessage: 'No tasks in progress',
                emptyIcon: Icons.hourglass_empty_outlined,
                color: const Color(0xFFF59E0B),
                ref: ref,
                onReorder: (oldIndex, newIndex, status) async {
                  await _handleReorder(
                      oldIndex, newIndex, inProgressTasks, status);
                },
              ),
              _TaskListView(
                tasks: doneTasks,
                status: 'Done',
                emptyMessage: 'No completed tasks',
                emptyIcon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
                ref: ref,
                onReorder: (oldIndex, newIndex, status) async {
                  await _handleReorder(oldIndex, newIndex, doneTasks, status);
                },
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading your tasks...',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReorder(
      int oldIndex, int newIndex, List<TaskModel> tasks, String status) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final task = tasks[oldIndex];
    await ref.read(tasksControllerProvider.notifier).updateTask(
          task.copyWith(status: status),
        );
  }
}

class _TabLabel extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _TabLabel(this.title, this.count, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskListView extends StatelessWidget {
  final List<TaskModel> tasks;
  final String status;
  final String emptyMessage;
  final IconData emptyIcon;
  final Color color;
  final WidgetRef ref;
  final Future<void> Function(int, int, String) onReorder;

  const _TaskListView({
    required this.tasks,
    required this.status,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.color,
    required this.ref,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyIcon,
                size: 48,
                color: color.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasks will appear here when added',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) => onReorder(oldIndex, newIndex, status),
      itemBuilder: (context, index) {
        return _TaskCard(
          key: ValueKey(tasks[index].id ?? index),
          task: tasks[index],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;

  const _TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDialog(
            context: context,
            builder: (_) => TaskDialog(task: task),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getStatusIcon(task.status),
                        size: 16,
                        color: _getStatusColor(task.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(task.status),
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Updated today',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return const Color(0xFFEF4444);
      case 'In Progress':
        return const Color(0xFFF59E0B);
      case 'Done':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'To Do':
        return Icons.pending_actions_outlined;
      case 'In Progress':
        return Icons.hourglass_empty_outlined;
      case 'Done':
        return Icons.check_circle_outline;
      default:
        return Icons.task_outlined;
    }
  }
}
