import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/tracking_providers.dart';
import '../../providers/wellness_providers.dart';
import '../../providers/health_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/period_cycle_model.dart';
import '../../models/symptom_model.dart';
import '../../models/workout_model.dart';
import '../../models/mood_log_model.dart';
import '../../models/hydration_model.dart';
import '../../models/food_log_model.dart';

class HealthCalendarPage extends ConsumerStatefulWidget {
  const HealthCalendarPage({super.key});

  @override
  ConsumerState<HealthCalendarPage> createState() => _HealthCalendarPageState();
}

class _HealthCalendarPageState extends ConsumerState<HealthCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final db = DatabaseService();
    final periodCycles = ref.watch(periodCyclesProvider);
    final symptoms = user != null ? db.getUserSymptoms(user.id) : <SymptomModel>[];
    final workouts = user != null ? db.getUserWorkouts(user.id) : <WorkoutModel>[];
    final moodLogs = user != null ? db.getUserMoodLogs(user.id) : <MoodLogModel>[];
    final hydrationLogs = user != null ? db.getUserHydrationLogs(user.id) : <HydrationModel>[];
    final foodLogs = user != null ? db.getUserFoodLogs(user.id) : <FoodLogModel>[];

    // Get data for selected day
    final selectedDaySymptoms = symptoms.where((s) =>
        isSameDay(s.timestamp, _selectedDay)).toList();
    final selectedDayWorkouts = workouts.where((w) =>
        isSameDay(w.date, _selectedDay)).toList();
    final selectedDayMoods = moodLogs.where((m) =>
        isSameDay(m.timestamp, _selectedDay)).toList();
    final selectedDayHydration = hydrationLogs.where((h) =>
        isSameDay(h.timestamp, _selectedDay)).toList();
    final selectedDayMeals = foodLogs.where((f) =>
      isSameDay(f.timestamp, _selectedDay)).toList();

    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(
        title: const Text(
          'Health Calendar',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLegend(context),
            tooltip: 'Show Legend',
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar widget with enhanced styling
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 6,
            shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableGestures: AvailableGestures.all,
              pageAnimationEnabled: true,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                markerDecoration: BoxDecoration(
                  color: AppTheme.peach,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonDecoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                titleTextStyle: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                  letterSpacing: 0.5,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.darkGreen,
                  size: 28,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.darkGreen,
                  size: 28,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  final markers = <Widget>[];

                  // Period marker
                  for (final cycle in periodCycles) {
                    if (day.isAfter(cycle.startDate.subtract(const Duration(days: 1))) &&
                        (cycle.endDate == null ||
                            day.isBefore(cycle.endDate!.add(const Duration(days: 1))))) {
                      markers.add(_buildMarker(Colors.pink, 0));
                      break;
                    }
                  }

                  // Workout marker
                  if (workouts.any((w) => isSameDay(w.date, day))) {
                    markers.add(_buildMarker(Colors.orange, 1));
                  }

                  // Mood marker
                  if (moodLogs.any((m) => isSameDay(m.timestamp, day))) {
                    markers.add(_buildMarker(Colors.yellow.shade700, 2));
                  }

                  // Symptom marker
                  if (symptoms.any((s) => isSameDay(s.timestamp, day))) {
                    markers.add(_buildMarker(Colors.red, 3));
                  }

                  // Meal marker
                  if (foodLogs.any((f) => isSameDay(f.timestamp, day))) {
                    markers.add(_buildMarker(const Color(0xFFFF7043), 4));
                  }

                  return markers.isNotEmpty
                      ? Positioned(
                          bottom: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: markers,
                          ),
                        )
                      : null;
                },
              ),
            ),
          ),

          // Selected day details with enhanced styling
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    AppTheme.primaryGreen.withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGreen,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Period info
                          if (_isPeriodDay(periodCycles, _selectedDay))
                            _buildDaySection(
                              icon: Icons.water_drop,
                              title: 'Period Day',
                              color: Colors.pink,
                              child: Text(
                                'Active menstrual cycle',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),

                          // Workouts
                          if (selectedDayWorkouts.isNotEmpty)
                            _buildDaySection(
                              icon: Icons.fitness_center,
                              title: 'Workouts (${selectedDayWorkouts.length})',
                              color: Colors.orange,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: selectedDayWorkouts.map((w) =>
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${w.activityType} - ${w.durationMinutes.toInt()} min',
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).toList(),
                              ),
                            ),

                          // Mood logs
                          if (selectedDayMoods.isNotEmpty)
                            _buildDaySection(
                              icon: Icons.mood,
                              title: 'Mood Logs (${selectedDayMoods.length})',
                              color: Colors.yellow.shade700,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: selectedDayMoods.map((m) =>
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.yellow.shade700,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${m.mood} (${m.intensity}/10)',
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).toList(),
                              ),
                            ),

                          // Symptoms
                          if (selectedDaySymptoms.isNotEmpty)
                            _buildDaySection(
                              icon: Icons.healing,
                              title: 'Symptoms (${selectedDaySymptoms.length})',
                              color: Colors.red,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: selectedDaySymptoms.map((s) =>
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${s.symptomType} - ${s.severity}',
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).toList(),
                              ),
                            ),

                          // Hydration
                          if (selectedDayHydration.isNotEmpty)
                            _buildDaySection(
                              icon: Icons.water,
                              title: 'Hydration',
                              color: Colors.blue,
                              child: Text(
                                'Total: ${selectedDayHydration.fold<int>(0, (sum, h) => sum + h.amountMl)} ml',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Meals
                          if (selectedDayMeals.isNotEmpty)
                            _buildDaySection(
                              icon: Icons.restaurant,
                              title: 'Meals (${selectedDayMeals.length})',
                              color: const Color(0xFFFF7043),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: selectedDayMeals.map((m) =>
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF7043),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${m.mealType}: ${m.foodName} (${m.calories.toInt()} cal)',
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).toList(),
                              ),
                            ),

                          // No data message with enhanced styling
                          if (selectedDaySymptoms.isEmpty &&
                              selectedDayWorkouts.isEmpty &&
                              selectedDayMoods.isEmpty &&
                              selectedDayHydration.isEmpty &&
                              selectedDayMeals.isEmpty &&
                              !_isPeriodDay(periodCycles, _selectedDay))
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.event_available_outlined,
                                        size: 56,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No health data for this day',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start tracking your health journey!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Color color, int position) {
    return Container(
      width: 6,
      height: 6,
      margin: EdgeInsets.only(left: position > 0 ? 2 : 0),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildDaySection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: child,
          ),
        ],
      ),
    );
  }

  bool _isPeriodDay(List<PeriodCycleModel> cycles, DateTime day) {
    for (final cycle in cycles) {
      if (day.isAfter(cycle.startDate.subtract(const Duration(days: 1))) &&
          (cycle.endDate == null ||
              day.isBefore(cycle.endDate!.add(const Duration(days: 1))))) {
        return true;
      }
    }
    return false;
  }

  void _showLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Calendar Legend',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem(Colors.pink, 'Period Day'),
            _buildLegendItem(Colors.orange, 'Workout'),
            _buildLegendItem(Colors.yellow.shade700, 'Mood Log'),
            _buildLegendItem(Colors.red, 'Symptom'),
            _buildLegendItem(const Color(0xFFFF7043), 'Meals'),
            const SizedBox(height: 16),
            Text(
              'Multiple markers may appear on a single day if you logged different types of data.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: AppTheme.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
