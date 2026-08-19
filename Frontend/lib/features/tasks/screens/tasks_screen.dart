import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _activeFilter = 'All'; // 'All', 'Pending', 'Completed'

  final List<Map<String, dynamic>> _tasks = [
    {
      'id': 't1',
      'title': 'Book Eiffel Tower Tickets',
      'assignee': 'Aastha Patel',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      'dueDate': 'May 18',
      'isCompleted': true,
    },
    {
      'id': 't2',
      'title': 'Arrange Airport Transfer cab',
      'assignee': 'Rahul Verma',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
      'dueDate': 'May 19',
      'isCompleted': false,
    },
    {
      'id': 't3',
      'title': 'Buy Group Travel Insurance',
      'assignee': 'Priya Sharma',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80',
      'dueDate': 'May 15',
      'isCompleted': true,
    },
    {
      'id': 't4',
      'title': 'Confirm Hotel Reservations',
      'assignee': 'Jay Shah',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
      'dueDate': 'May 10',
      'isCompleted': true,
    },
    {
      'id': 't5',
      'title': 'Book Seine River Cruise Tickets',
      'assignee': 'Neha Patel',
      'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&auto=format&fit=crop&q=80',
      'dueDate': 'May 21',
      'isCompleted': false,
    },
  ];

  final List<Map<String, String>> _members = [
    {
      'name': 'Aastha Patel',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80'
    },
    {
      'name': 'Rahul Verma',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80'
    },
    {
      'name': 'Priya Sharma',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80'
    },
    {
      'name': 'Jay Shah',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80'
    },
    {
      'name': 'Neha Patel',
      'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&auto=format&fit=crop&q=80'
    },
  ];

  List<Map<String, dynamic>> get _filteredTasks {
    if (_activeFilter == 'Pending') {
      return _tasks.where((t) => !t['isCompleted']).toList();
    } else if (_activeFilter == 'Completed') {
      return _tasks.where((t) => t['isCompleted']).toList();
    }
    return _tasks;
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    String selectedAssignee = 'Aastha Patel';
    final dateController = TextEditingController(text: 'May 20');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Create New Task', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'Enter task description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedAssignee,
                    decoration: const InputDecoration(
                      labelText: 'Assign To',
                      border: OutlineInputBorder(),
                    ),
                    items: _members.map((m) {
                      return DropdownMenuItem<String>(
                        value: m['name'],
                        child: Text(m['name']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedAssignee = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      hintText: 'e.g. May 20',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      final assigneeMap = _members.firstWhere((m) => m['name'] == selectedAssignee);
                      setState(() {
                        _tasks.add({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'title': titleController.text.trim(),
                          'assignee': selectedAssignee,
                          'avatar': assigneeMap['avatar'],
                          'dueDate': dateController.text.trim(),
                          'isCompleted': false,
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Group Tasks',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterTab('All'),
                const SizedBox(width: 8),
                _buildFilterTab('Pending'),
                const SizedBox(width: 8),
                _buildFilterTab('Completed'),
              ],
            ),
          ),
          // Tasks checklist view
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3E8FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.task_alt,
                            size: 40,
                            color: Color(0xFF9333EA),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Tasks Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Status Check Circle
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  item['isCompleted'] = !item['isCompleted'];
                                });
                              },
                              child: Icon(
                                item['isCompleted'] ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: item['isCompleted'] ? const Color(0xFF20C060) : const Color(0xFF94A3B8),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                      decoration: item['isCompleted'] ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 8,
                                            backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(item['avatar'])),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Assignee: ${item['assignee']}',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Due: ${item['dueDate']}',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FloatingActionButton(
          onPressed: _showAddTaskDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
