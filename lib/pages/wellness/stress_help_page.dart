import 'package:flutter/material.dart';
import '../../config/theme.dart';

class StressHelpPage extends StatefulWidget {
  const StressHelpPage({super.key});

  @override
  State<StressHelpPage> createState() => _StressHelpPageState();
}

class _StressHelpPageState extends State<StressHelpPage> {
  int _stressLevel = 5;

  List<String> _recommendedActions() {
    if (_stressLevel <= 3) {
      return const [
        'Take a 2-minute mindful pause.',
        'Drink one glass of water.',
        'Do a short neck and shoulder stretch.',
      ];
    }
    if (_stressLevel <= 7) {
      return const [
        'Use 4-7-8 breathing for 3 cycles.',
        'Take a 10-minute walk away from screens.',
        'Write down top 3 priorities and drop 1 non-essential task.',
      ];
    }
    return const [
      'Do 5-4-3-2-1 grounding immediately.',
      'Contact a trusted person and share how you feel.',
      'Use SOS if you feel unsafe or overwhelmed.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _recommendedActions();

    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(title: const Text('Stress Help')),
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
                    'How stressed do you feel right now?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: _stressLevel.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_stressLevel/10',
                    onChanged: (value) {
                      setState(() {
                        _stressLevel = value.round();
                      });
                    },
                  ),
                  Text('Stress level: $_stressLevel / 10'),
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
                  const Text(
                    'Action Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...actions.map(
                    (a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(a)),
                        ],
                      ),
                    ),
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
                children: const [
                  Text(
                    'Quick Grounding: 5-4-3-2-1',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('5 things you can see'),
                  Text('4 things you can touch'),
                  Text('3 things you can hear'),
                  Text('2 things you can smell'),
                  Text('1 thing you can taste'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/meditation'),
            icon: const Icon(Icons.self_improvement),
            label: const Text('Open Mindful Session'),
          ),
        ],
      ),
    );
  }
}
