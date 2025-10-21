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
