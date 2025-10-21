import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures async calls before runApp
  runApp(TaskApp());
}

class TaskApp extends StatefulWidget {
  @override
  State<TaskApp> createState() => _TaskAppState();
}

class _TaskAppState extends State<TaskApp> {
  bool _isDarkMode = false;
  bool _loaded = false; // Used to wait until theme loads before showing UI

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // Load saved theme preference
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(ThemeStorage.keyIsDark) ?? false;
    setState(() {
      _isDarkMode = saved;
      _loaded = true;
    });
  }

  // Toggle and save theme mode
  void _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ThemeStorage.keyIsDark, isDark);
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wait until theme preference loads
    if (!_loaded) return const SizedBox.shrink();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: TaskListScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

class ThemeStorage {
  static const String keyIsDark = 'is_dark_theme_v1';
}

class Task {
  String title;
  bool completed;

  Task({required this.title, this.completed = false});

  Map<String, dynamic> toJson() => {
        'title': title,
        'completed': completed,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'] ?? '',
        completed: json['completed'] ?? false,
      );
}

class TaskListScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const TaskListScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Task> _tasks = [];
  bool _loading = true;

  static const String tasksKey = 'task_list_v1';

  @override
  void initState() {
    super.initState();
    _loadTasks(); // Load tasks when app starts
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(tasksKey);
    if (raw != null) {
      try {
        final List decoded = json.decode(raw) as List;
        _tasks = decoded.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (e) {
        _tasks = [];
      }
    } else {
      _tasks = [];
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString(tasksKey, raw);
  }

  void _addTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.insert(0, Task(title: text));
      _controller.clear();
    });
    _saveTasks();
  }

  void _toggleTaskCompleted(int index, bool? value) {
    if (value == null) return;
    setState(() {
      _tasks[index].completed = value;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _clearCompleted() {
    setState(() {
      _tasks.removeWhere((t) => t.completed);
    });
    _saveTasks();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          // Theme switch (Light/Dark)
          Row(
            children: [
              Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              Switch(
                value: widget.isDarkMode,
                onChanged: (v) => widget.onThemeChanged(v),
              ),
            ],
          ),
          // Clear completed button
          IconButton(
            tooltip: 'Clear completed tasks',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _tasks.any((t) => t.completed) ? _clearCompleted : null,
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Input area
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Task text input
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onSubmitted: (_) => _addTask(),
                          decoration: InputDecoration(
                            hintText: 'Enter a task name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Add button
                      ElevatedButton(
                        onPressed: _addTask,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),

                // Summary text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Text('${_tasks.length} task${_tasks.length == 1 ? '' : 's'}'),
                      const SizedBox(width: 12),
                      Text('${_tasks.where((t) => t.completed).length} completed'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Task list
                Expanded(
                  child: _tasks.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks yet — add one above!',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return Dismissible(
                              key: ValueKey(task.title + index.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteTask(index),
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: task.completed,
                                    onChanged: (v) => _toggleTaskCompleted(index, v),
                                  ),
                                  title: Text(
                                    task.title,
                                    style: TextStyle(
                                      decoration: task.completed
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color: task.completed ? theme.disabledColor : null,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Delete task',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _confirmAndDelete(index),
                                  ),
                                  onTap: () =>
                                      _toggleTaskCompleted(index, !task.completed),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

