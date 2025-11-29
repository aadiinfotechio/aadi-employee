import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final ApiService _apiService = ApiService();
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, in_progress, completed
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Auto-refresh tasks every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadTasks();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      final tasks = await _apiService.getTasks(employeeId: employeeId);

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(Task task, String newStatus) async {
    try {
      await _apiService.updateTaskStatus(task.id, newStatus);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully')),
      );

      _loadTasks(); // Reload tasks
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Task> get _filteredTasks {
    if (_selectedFilter == 'all') {
      return _tasks;
    }
    return _tasks.where((task) => task.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _selectedFilter == 'all',
                        onSelected: () => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending',
                        selected: _selectedFilter == 'pending',
                        onSelected: () => setState(() => _selectedFilter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'In Progress',
                        selected: _selectedFilter == 'in_progress',
                        onSelected: () => setState(() => _selectedFilter = 'in_progress'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Completed',
                        selected: _selectedFilter == 'completed',
                        onSelected: () => setState(() => _selectedFilter = 'completed'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tasks List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTasks,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = _filteredTasks[index];
                          return _TaskCard(
                            task: task,
                            onStatusChange: _updateTaskStatus,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final Function(Task, String) onStatusChange;

  const _TaskCard({
    required this.task,
    required this.onStatusChange,
  });

  Color _getStatusColor() {
    switch (task.status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor() {
    switch (task.priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Show task details
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => _TaskDetailsSheet(task: task, onStatusChange: onStatusChange),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (task.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (task.priority != null) ...[
                    Icon(Icons.flag, size: 16, color: _getPriorityColor()),
                    const SizedBox(width: 4),
                    Text(
                      task.priority!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getPriorityColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (task.dueDate != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: task.isOverdue ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(task.dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isOverdue ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
              if (task.projectName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.folder, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      task.projectName!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDetailsSheet extends StatelessWidget {
  final Task task;
  final Function(Task, String) onStatusChange;

  const _TaskDetailsSheet({
    required this.task,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                task.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              if (task.description != null) ...[
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(task.description!),
                const SizedBox(height: 16),
              ],
              const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('Pending')),
                  ButtonSegment(value: 'in_progress', label: Text('In Progress')),
                  ButtonSegment(value: 'completed', label: Text('Completed')),
                ],
                selected: {task.status},
                onSelectionChanged: (Set<String> newSelection) {
                  onStatusChange(task, newSelection.first);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              if (task.dueDate != null) ...[
                const Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(DateFormat('MMM dd, yyyy').format(task.dueDate!)),
                const SizedBox(height: 16),
              ],
              if (task.priority != null) ...[
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(task.priority!.toUpperCase()),
                const SizedBox(height: 16),
              ],
              if (task.projectName != null) ...[
                const Text('Project', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(task.projectName!),
              ],
            ],
          ),
        );
      },
    );
  }
}
