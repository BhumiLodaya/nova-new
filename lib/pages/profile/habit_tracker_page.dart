import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/database_service.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final DatabaseService _db = DatabaseService();
  final List<_HabitItem> _habits = [
    _HabitItem(id: 'water', title: 'Drink 8 glasses of water'),
    _HabitItem(id: 'walk', title: 'Walk at least 20 minutes'),
    _HabitItem(id: 'sleep', title: 'Sleep before 11 PM'),
    _HabitItem(id: 'meal', title: 'Do not skip meals'),
    _HabitItem(id: 'mindful', title: '5 minutes mindful breathing'),
  ];

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  String get _todayKey {
    final now = DateTime.now();
    return 'habit_tracker_${now.year}-${now.month}-${now.day}';
  }

  void _loadToday() {
    final done = (_db.getSetting(_todayKey, defaultValue: <String>[]) as List)
        .map((e) => e.toString())
        .toSet();
    setState(() {
      for (final h in _habits) {
        h.done = done.contains(h.id);
      }
    });
  }

  Future<void> _save() async {
    final doneIds = _habits.where((h) => h.done).map((h) => h.id).toList();
    await _db.saveSetting(_todayKey, doneIds);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _habits.where((h) => h.done).length;

    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(title: const Text('Habit Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Habit Progress',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: completed / _habits.length),
                  const SizedBox(height: 8),
                  Text('$completed / ${_habits.length} habits completed'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._habits.map(
            (h) => Card(
              child: CheckboxListTile(
                value: h.done,
                title: Text(h.title),
                onChanged: (value) async {
                  setState(() {
                    h.done = value ?? false;
                  });
                  await _save();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitItem {
  final String id;
  final String title;
  bool done;

  _HabitItem({required this.id, required this.title, this.done = false});
}
