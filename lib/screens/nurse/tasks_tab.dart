import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/task_model.dart';
import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class TasksTab extends StatefulWidget {
  final int wardNumber;
  
  const TasksTab({
    super.key,
    required this.wardNumber,
  });

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<TaskModel>>(
        stream: _databaseService.getTasksForWard(widget.wardNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final tasks = snapshot.data!;
          final overdue = tasks.where((t) => !t.isCompleted && t.dueDate.isBefore(DateTime.now())).toList();
          final today = tasks.where((t) => !t.isCompleted && _isToday(t.dueDate) && t.dueDate.isAfter(DateTime.now())).toList();
          final upcoming = tasks.where((t) => !t.isCompleted && !_isToday(t.dueDate) && t.dueDate.isAfter(DateTime.now())).toList();
          final completed = tasks.where((t) => t.isCompleted).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overdue.isNotEmpty) ...[
                _buildSectionHeader('Overdue', AppTheme.criticalRed),
                ...overdue.map((t) => _TaskCard(task: t, databaseService: _databaseService, currentUser: currentUser)),
                const SizedBox(height: 16),
              ],
              
              if (today.isNotEmpty) ...[
                _buildSectionHeader('Today', AppTheme.primaryColor),
                ...today.map((t) => _TaskCard(task: t, databaseService: _databaseService, currentUser: currentUser)),
                const SizedBox(height: 16),
              ],

              if (upcoming.isNotEmpty) ...[
                _buildSectionHeader('Upcoming', AppTheme.textPrimary),
                ...upcoming.map((t) => _TaskCard(task: t, databaseService: _databaseService, currentUser: currentUser)),
                const SizedBox(height: 16),
              ],

              if (completed.isNotEmpty) ...[
                _buildSectionHeader('Completed', AppTheme.stableGreen),
                ...completed.map((t) => _TaskCard(task: t, databaseService: _databaseService, currentUser: currentUser)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context, currentUser),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_task),
        label: const Text('New Task'),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a new task',
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, dynamic currentUser) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String? selectedPatientId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Dropdown
                StreamBuilder<List<PatientModel>>(
                  stream: _databaseService.getPatientsByWard(widget.wardNumber),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return const SizedBox.shrink();
                     final patients = snapshot.data!;
                     
                     // Reset if selected patient no longer exists in list
                     if (selectedPatientId != null && !patients.any((p) => p.id == selectedPatientId)) {
                       selectedPatientId = null;
                     }

                     return DropdownButtonFormField<String>(
                       value: selectedPatientId,
                       decoration: const InputDecoration(
                         labelText: 'Select Patient',
                         prefixIcon: Icon(Icons.person),
                       ),
                       items: patients.map((patient) {
                         return DropdownMenuItem(
                           value: patient.id,
                           child: Text(
                             '${patient.name} (Bed ${patient.bedNumber})',
                             overflow: TextOverflow.ellipsis,
                           ),
                         );
                       }).toList(),
                       onChanged: (value) {
                         setState(() => selectedPatientId = value);
                       },
                     );
                  },
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g., Check BP',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Details...',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(DateFormat('MMM dd').format(selectedDate)),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                if (selectedPatientId == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Please select a patient')),
                   );
                   return;
                }

                // Fetch patient details needed for the task
                final patient = await _databaseService.getPatient(selectedPatientId!);
                if (patient == null) return;

                final dueDate = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final newTask = TaskModel(
                  id: '',
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  dueDate: dueDate,
                  patientId: patient.id,
                  patientName: patient.name,
                  assignedNurseId: currentUser.id,
                  assignedNurseName: currentUser.name,
                  wardNumber: widget.wardNumber,
                  createdAt: DateTime.now(),
                  isCompleted: false,
                );

                await _databaseService.addTask(newTask);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final DatabaseService databaseService;
  final dynamic currentUser;

  const _TaskCard({
    required this.task,
    required this.databaseService,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = !task.isCompleted && task.dueDate.isBefore(DateTime.now());

    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: AppTheme.criticalRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => databaseService.deleteTask(task.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isOverdue ? Border.all(color: AppTheme.criticalRed.withValues(alpha: 0.5)) : null,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: task.isCompleted,
                onChanged: task.isCompleted 
                    ? null 
                    : (value) => databaseService.updateTaskStatus(
                        taskId: task.id,
                        isCompleted: value ?? false,
                        completedByNurseId: currentUser.id,
                        completedByNurseName: currentUser.name,
                      ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                activeColor: AppTheme.stableGreen,
                // Make disabled look like checked but static
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return AppTheme.stableGreen.withOpacity(0.6);
                  }
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.stableGreen;
                  }
                  return null;
                }),
              ),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   'Patient: ${task.patientName}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                 ),
                 if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    _buildDetailRow(
                      Icons.assignment_ind_outlined,
                      'Given by:',
                      '${task.assignedNurseName} on ${DateFormat('MMM dd, HH:mm').format(task.createdAt)}',
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.event,
                      'Due date:',
                      DateFormat('MMM dd, HH:mm').format(task.dueDate),
                      isUrgent: isOverdue,
                    ),
                    if (task.isCompleted && task.completedByNurseName != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.check_circle_outline,
                        'Done by:',
                        '${task.completedByNurseName} on ${DateFormat('MMM dd, HH:mm').format(task.completedAt!)}',
                        color: AppTheme.stableGreen,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isUrgent = false, Color? color}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? (isUrgent ? AppTheme.criticalRed : AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color ?? (isUrgent ? AppTheme.criticalRed : AppTheme.textPrimary),
              fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
