import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/theme.dart';
import '../../models/period_cycle_model.dart';
import '../../models/health_metric_model.dart';
import '../../providers/tracking_providers.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

const uuid = Uuid();

class PeriodTrackerPage extends ConsumerStatefulWidget {
  const PeriodTrackerPage({super.key});

  @override
  ConsumerState<PeriodTrackerPage> createState() => _PeriodTrackerPageState();
}

class _PeriodTrackerPageState extends ConsumerState<PeriodTrackerPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String _flowIntensity = 'medium';
  final List<String> _selectedSymptoms = [];
  String? _mood;
  final _notesController = TextEditingController();

  final List<String> _symptomOptions = [
    'Cramps',
    'Headache',
    'Mood Swings',
    'Fatigue',
    'Bloating',
    'Back Pain',
    'Tender Breasts',
    'Acne',
  ];

  final List<String> _moodOptions = [
    'Happy',
    'Irritable',
    'Sad',
    'Anxious',
    'Normal',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cycles = ref.watch(periodCyclesProvider);
    final activeCycle = ref.watch(activePeriodCycleProvider);
    final avgCycleLength = ref.read(periodCyclesProvider.notifier).getAverageCycleLength();
    final nextPeriod = ref.read(periodCyclesProvider.notifier).predictNextPeriod();

    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(
        title: const Text('Period Tracker'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Calendar
            Card(
              margin: const EdgeInsets.all(16),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    // Mark period days
                    for (final cycle in cycles) {
                      if (day.isAfter(cycle.startDate.subtract(const Duration(days: 1))) &&
                          (cycle.endDate == null ||
                              day.isBefore(cycle.endDate!.add(const Duration(days: 1))))) {
                        return Center(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.pink,
                              shape: BoxShape.circle,
                            ),
                            width: 35,
                            height: 35,
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    // Mark predicted next period
                    if (nextPeriod != null &&
                        day.isAfter(nextPeriod.subtract(const Duration(days: 3))) &&
                        day.isBefore(nextPeriod.add(const Duration(days: 8)))) {
                      return Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          width: 35,
                          height: 35,
                          child: Center(
                            child: Text('${day.day}'),
                          ),
                        ),
                      );
                    }

                    return null;
                  },
                ),
              ),
            ),

            // Cycle insights
            if (cycles.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cycle Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (avgCycleLength != null)
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 8),
                            Text('Average Cycle: $avgCycleLength days'),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (nextPeriod != null)
                        Row(
                          children: [
                            const Icon(Icons.event, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Next Period (est): ${nextPeriod.day}/${nextPeriod.month}/${nextPeriod.year}',
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.history, size: 20),
                          const SizedBox(width: 8),
                          Text('Total Cycles Tracked: ${cycles.length}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Active cycle or start new
            if (activeCycle != null)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.pink.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, color: Colors.pink, size: 12),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Period',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Started: ${activeCycle.startDate.day}/${activeCycle.startDate.month}/${activeCycle.startDate.year}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      Text(
                        'Flow: ${activeCycle.flowIntensity}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _endPeriod(activeCycle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('End Period'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Log Period',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),

                        // Flow intensity
                        const Text('Flow Intensity'),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'light', label: Text('Light')),
                            ButtonSegment(value: 'medium', label: Text('Medium')),
                            ButtonSegment(value: 'heavy', label: Text('Heavy')),
                          ],
                          selected: {_flowIntensity},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _flowIntensity = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Symptoms
                        const Text('Symptoms'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _symptomOptions.map((symptom) {
                            final isSelected = _selectedSymptoms.contains(symptom);
                            return FilterChip(
                              label: Text(symptom),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSymptoms.add(symptom);
                                  } else {
                                    _selectedSymptoms.remove(symptom);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Mood
                        DropdownButtonFormField<String>(
                          value: _mood,
                          decoration: const InputDecoration(
                            labelText: 'Mood (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: _moodOptions.map((mood) {
                            return DropdownMenuItem(
                              value: mood,
                              child: Text(mood),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _mood = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Save button
                        ElevatedButton(
                          onPressed: _startPeriod,
                          child: const Text('Start Period'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Cycle history
            if (cycles.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Cycle History',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cycles.length > 10 ? 10 : cycles.length,
                itemBuilder: (context, index) {
                  final cycle = cycles[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.pink,
                        child: Text(
                          '${cycle.periodLength ?? "?"}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        '${cycle.startDate.day}/${cycle.startDate.month}/${cycle.startDate.year}',
                      ),
                      subtitle: Text(
                        cycle.endDate != null
                            ? 'Ended: ${cycle.endDate!.day}/${cycle.endDate!.month}/${cycle.endDate!.year}'
                            : 'Active',
                      ),
                      trailing: Text(cycle.flowIntensity),
                      textColor: Colors.black87,
                      onLongPress: () => _deleteCycle(cycle.id),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  void _startPeriod() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    // Save to old PeriodCycleModel for backward compatibility
    final cycle = PeriodCycleModel(
      id: uuid.v4(),
      userId: user.id,
      startDate: _selectedDay,
      flowIntensity: _flowIntensity,
      symptoms: List.from(_selectedSymptoms),
      mood: _mood,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: now,
    );

    ref.read(periodCyclesProvider.notifier).addCycle(cycle);

    // ALSO save to HealthMetricModel for Supabase sync
    final db = DatabaseService();
    
    // Get or create health metric for the selected day
    var healthMetric = db.getHealthMetricByDate(user.id, selectedDate);
    
    if (healthMetric == null || healthMetric.id.isEmpty) {
      healthMetric = HealthMetricModel(
        id: uuid.v4(),
        userId: user.id,
        date: selectedDate,
        createdAt: now,
        isPeriodDay: true,
        flowIntensity: _flowIntensity,
        periodSymptoms: _selectedSymptoms.isNotEmpty ? List.from(_selectedSymptoms) : null,
        mood: _mood,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
    } else {
      // Update existing metric with period data
      healthMetric = HealthMetricModel(
        id: healthMetric.id,
        userId: healthMetric.userId,
        date: healthMetric.date,
        weight: healthMetric.weight,
        steps: healthMetric.steps,
        sleepMinutes: healthMetric.sleepMinutes,
        mood: _mood ?? healthMetric.mood,
        stressLevel: healthMetric.stressLevel,
        energyLevel: healthMetric.energyLevel,
        notes: _notesController.text.isNotEmpty ? _notesController.text : healthMetric.notes,
        createdAt: healthMetric.createdAt,
        isPeriodDay: true,
        flowIntensity: _flowIntensity,
        periodSymptoms: _selectedSymptoms.isNotEmpty ? List.from(_selectedSymptoms) : null,
        cycleDay: healthMetric.cycleDay,
        symptoms: healthMetric.symptoms,
        symptomSeverity: healthMetric.symptomSeverity,
        symptomBodyParts: healthMetric.symptomBodyParts,
        symptomTriggers: healthMetric.symptomTriggers,
      );
    }

    await db.saveHealthMetric(healthMetric);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Period started!')),
      );
    }

    setState(() {
      _selectedSymptoms.clear();
      _mood = null;
      _notesController.clear();
    });
  }

  void _endPeriod(PeriodCycleModel activeCycle) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Calculate cycle length if there's a previous cycle
    final cycles = ref.read(periodCyclesProvider);
    int? cycleLength;

    if (cycles.length > 1) {
      final previousCycle = cycles[1];
      cycleLength = activeCycle.startDate.difference(previousCycle.startDate).inDays;
    }

    final updatedCycle = PeriodCycleModel(
      id: activeCycle.id,
      userId: activeCycle.userId,
      startDate: activeCycle.startDate,
      endDate: DateTime.now(),
      flowIntensity: activeCycle.flowIntensity,
      symptoms: activeCycle.symptoms,
      mood: activeCycle.mood,
      notes: activeCycle.notes,
      cycleLength: cycleLength,
      createdAt: activeCycle.createdAt,
    );

    ref.read(periodCyclesProvider.notifier).updateCycle(updatedCycle);

    // Update health metrics for all period days to mark them as ended
    final db = DatabaseService();
    final startDate = DateTime(
      activeCycle.startDate.year,
      activeCycle.startDate.month,
      activeCycle.startDate.day,
    );
    final endDate = DateTime.now();
    
    // Calculate cycle day for the last day
    final periodLength = endDate.difference(startDate).inDays + 1;
    
    // Update the last day's health metric with cycle info
    final lastDayDate = DateTime(endDate.year, endDate.month, endDate.day);
    var lastDayMetric = db.getHealthMetricByDate(user.id, lastDayDate);
    
    if (lastDayMetric != null && lastDayMetric.id.isNotEmpty && lastDayMetric.isPeriodDay) {
      lastDayMetric = HealthMetricModel(
        id: lastDayMetric.id,
        userId: lastDayMetric.userId,
        date: lastDayMetric.date,
        weight: lastDayMetric.weight,
        steps: lastDayMetric.steps,
        sleepMinutes: lastDayMetric.sleepMinutes,
        mood: lastDayMetric.mood,
        stressLevel: lastDayMetric.stressLevel,
        energyLevel: lastDayMetric.energyLevel,
        notes: lastDayMetric.notes,
        createdAt: lastDayMetric.createdAt,
        isPeriodDay: true,
        flowIntensity: lastDayMetric.flowIntensity,
        periodSymptoms: lastDayMetric.periodSymptoms,
        cycleDay: cycleLength, // Store cycle length info
        symptoms: lastDayMetric.symptoms,
        symptomSeverity: lastDayMetric.symptomSeverity,
        symptomBodyParts: lastDayMetric.symptomBodyParts,
        symptomTriggers: lastDayMetric.symptomTriggers,
      );
      await db.saveHealthMetric(lastDayMetric);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Period ended!')),
      );
    }
  }

  void _deleteCycle(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cycle'),
        content: const Text('Are you sure you want to delete this cycle record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(periodCyclesProvider.notifier).deleteCycle(id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
