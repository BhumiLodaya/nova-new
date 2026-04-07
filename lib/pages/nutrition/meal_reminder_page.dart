import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';

class MealReminderPage extends StatefulWidget {
  const MealReminderPage({super.key});

  @override
  State<MealReminderPage> createState() => _MealReminderPageState();
}

class _MealReminderPageState extends State<MealReminderPage> {
  Timer? _timer;
  int _remainingSeconds = 0;
  String _mode = 'meal';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int minutes, String mode) {
    _timer?.cancel();
    setState(() {
      _mode = mode;
      _remainingSeconds = minutes * 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        _showReminderDialog(mode);
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _showReminderDialog(String mode) {
    final isMeal = mode == 'meal';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMeal ? 'Meal Reminder' : 'Hydration Reminder'),
        content: Text(
          isMeal
              ? 'Time to eat something healthy. Consider adding your meal log now.'
              : 'Time to drink water. A glass now helps maintain hydration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                isMeal ? AppRoutes.nutrition : AppRoutes.hydration,
              );
            },
            child: Text(isMeal ? 'Log Meal' : 'Log Water'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(title: const Text('Meal & Water Reminder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _remainingSeconds > 0 ? '$minutes:$seconds' : 'No active timer',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _remainingSeconds > 0
                        ? (_mode == 'meal' ? 'Meal timer running' : 'Water timer running')
                        : 'Start a reminder below',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Meal reminders', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [30, 60, 120]
                        .map(
                          (m) => ElevatedButton(
                            onPressed: () => _startTimer(m, 'meal'),
                            child: Text('In $m min'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Hydration reminders', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [20, 45, 90]
                        .map(
                          (m) => ElevatedButton(
                            onPressed: () => _startTimer(m, 'water'),
                            child: Text('In $m min'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _timer?.cancel();
                      setState(() {
                        _remainingSeconds = 0;
                      });
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop Timer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
