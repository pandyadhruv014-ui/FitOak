import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import '../state/daily_tracker_state.dart';
import '../services/notification_service.dart';
import '../widgets/custom_loading_switch.dart';
import 'workout_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isReminderEnabled = false;
  TimeOfDay selectedGymTime = const TimeOfDay(hour: 18, minute: 0);
  List<int> selectedRestDays = [7];

  bool isCreatineCycle = false;
  final int baseWaterGoalGlasses = 16; // 16 * 0.25L = 4.00 L minimum

  int get effectiveWaterGoalGlasses =>
      isCreatineCycle ? baseWaterGoalGlasses + 4 : baseWaterGoalGlasses;

  @override
  void initState() {
    super.initState();
    dailyTracker.addListener(_updateUi);
    _loadSavedGymReminder();
    dailyTracker.fetchBackendMeals();
    dailyTracker.fetchBackendWorkouts();
    dailyTracker.fetchWeeklyWater();
    dailyTracker.fetchMyGymGroup();
  }

  @override
  void dispose() {
    dailyTracker.removeListener(_updateUi);
    super.dispose();
  }

  void _updateUi() {
    _loadSavedGymReminder();
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedGymReminder() async {
    final saved = await NotificationService().getSavedGymReminder();
    if (!mounted) return;
    if (saved != null) {
      if (!isReminderEnabled || saved != selectedGymTime) {
        setState(() {
          isReminderEnabled = true;
          selectedGymTime = saved;
        });
      }
    }
  }

  void _openSubPage(
      String title, Widget Function(BuildContext, StateSetter) builder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (subContext, setSubState) {
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: builder(subContext, setSubState),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    final group = dailyTracker.activeGymGroup;
    final squadSubtitle = group != null
        ? "${group['group_name']} • Group Chat & Co-Logging"
        : "Connect with gym buddies, group chat, sync alarms & co-log";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Welcome, ${dailyTracker.fullName.isNotEmpty ? dailyTracker.fullName : 'User'} 👋",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. TODAY'S PROGRESS TILE
            _buildNavigationCard(
              context,
              title: "Today's progress",
              subtitle: "Activity, Steps, Macros & Completed Exercises",
              icon: Icons.directions_walk,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "Today's progress",
                (ctx, _) => _buildTodaysProgressContent(ctx),
              ),
            ),
            const SizedBox(height: 12),

            // 2. PROGRESS OVERVIEW TILE
            _buildNavigationCard(
              context,
              title: "Progress Overview",
              subtitle: "Weekly Exercises & Chart Stats",
              icon: Icons.bar_chart,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "Progress Overview",
                (_, __) => const ProgressOverviewSubPage(),
              ),
            ),
            const SizedBox(height: 12),

            // 3. INSTANT AI NUTRITION ANALYZER TILE
            _buildNavigationCard(
              context,
              title: "FitOak Nutrition Analyzer",
              subtitle: "Analyze custom dishes & portion macros",
              icon: Icons.auto_awesome,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "FitOak Nutrition Analyzer",
                (_, __) => const NutritionAnalyzerSubPage(),
              ),
            ),
            const SizedBox(height: 12),

            // 4. DAILY REMINDERS & HYDRATION TILE
            _buildNavigationCard(
              context,
              title: "Daily Reminders & Hydration",
              subtitle: "Persistent Gym Reminder & Weekly Water Tracker",
              icon: Icons.alarm,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "Daily Reminders & Hydration",
                (ctx, setSubState) =>
                    _buildRemindersAndHydrationContent(ctx, setSubState),
              ),
            ),
            const SizedBox(height: 12),

            // 5. GYM SQUAD TILE
            _buildNavigationCard(
              context,
              title: "Gym Squad",
              subtitle: squadSubtitle,
              icon: Icons.groups,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "Gym Squad",
                (ctx, setSubState) => _buildGymSquadContent(ctx, setSubState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryTextColor,
    required Color? secondaryTextColor,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: Colors.deepOrange, size: 28),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryTextColor)),
        subtitle: Text(subtitle,
            style: TextStyle(color: secondaryTextColor, fontSize: 12)),
        trailing:
            Icon(Icons.arrow_forward_ios, color: secondaryTextColor, size: 16),
        onTap: onTap,
      ),
    );
  }

  // --- SUB PAGE 1: TODAY'S PROGRESS ---
  Widget _buildTodaysProgressContent(BuildContext context) {
    final netCalories =
        (dailyTracker.totalCalories - dailyTracker.totalCaloriesBurned)
            .clamp(0, 10000);
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Daily Motion Sensors",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor)),
                    Text(
                      dailyTracker.isHealthPermissionGranted
                          ? "Synced"
                          : "Sensor Active",
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 11),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _activityMetric(
                        "Steps", "${dailyTracker.dailySteps}", "Pedometer"),
                    _activityMetric(
                        "Distance",
                        "${dailyTracker.distanceKm.toStringAsFixed(2)} km",
                        "Motion"),
                    _activityMetric(
                        "Burned",
                        "${dailyTracker.totalCaloriesBurned} kcal",
                        "Motion + Workouts"),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    context,
                    'Intake / Goal',
                    '${dailyTracker.totalCalories} / ${dailyTracker.dailyCalorieGoal} kcal',
                    Colors.deepOrange,
                    Icons.local_fire_department)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard(
                    context,
                    'Protein',
                    '${dailyTracker.totalProtein} / ${dailyTracker.dailyProteinGoal} g',
                    Colors.blue,
                    Icons.fitness_center)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    context,
                    'Carbs',
                    '${dailyTracker.totalCarbs} / ${dailyTracker.dailyCarbsGoal} g',
                    Colors.green,
                    Icons.grain)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard(
                    context,
                    'Fats',
                    '${dailyTracker.totalFat} / ${dailyTracker.dailyFatGoal} g',
                    Colors.amber,
                    Icons.opacity)),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Net Calories (Intake - Burned)",
                    style: TextStyle(fontSize: 13, color: secondaryTextColor)),
                Text("$netCalories kcal",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.fitness_center, color: Colors.deepOrange, size: 22),
            const SizedBox(width: 8),
            Text(
              "Today's Completed Exercises",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        dailyTracker.workoutLog.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      "No exercises logged yet today.",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ),
                ),
              )
            : Column(
                children: dailyTracker.workoutLog.map((item) {
                  final workoutId = item['id'];
                  final muscle = (item['muscle'] ?? '').toString();
                  final isCardio = muscle.toLowerCase() == 'cardio' ||
                      item['details'] != null;

                  final String? assetPath = _getMuscleAssetPath(muscle);

                  String subtitleText = "";
                  if (isCardio) {
                    subtitleText = item['details'] ?? "Cardio Session Logged";
                  } else {
                    List<SetLog> sets =
                        (item['sets'] ?? <SetLog>[]) as List<SetLog>;
                    subtitleText =
                        "${sets.length} sets logged | Max Weight: ${item['maxWeight'] ?? 0.0} kg";
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Slidable(
                      key: Key((workoutId ?? item['exercise']).toString()),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) async {
                              if (workoutId != null) {
                                await dailyTracker.deleteWorkout(workoutId);
                              } else {
                                dailyTracker.workoutLog.remove(item);
                                dailyTracker.refreshUI();
                              }
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Remove',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: assetPath != null
                                ? Image.asset(
                                    assetPath,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.fitness_center,
                                      color: Colors.deepOrange,
                                      size: 24,
                                    ),
                                  )
                                : Icon(
                                    isCardio
                                        ? Icons.directions_run
                                        : Icons.fitness_center,
                                    color: isCardio
                                        ? Colors.blueAccent
                                        : Colors.deepOrange,
                                    size: 24,
                                  ),
                          ),
                          title: Text("${item['muscle']} - ${item['exercise']}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor)),
                          subtitle: Text(subtitleText),
                          trailing: Text(
                            "-${item['caloriesBurned']} kcal",
                            style: const TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  String? _getMuscleAssetPath(String muscle) {
    switch (muscle.toLowerCase().trim()) {
      case 'abs':
      case 'core':
        return 'assets/icons/abs.png';
      case 'back':
        return 'assets/icons/back.png';
      case 'biceps':
      case 'arms':
        return 'assets/icons/biceps.png';
      case 'chest':
        return 'assets/icons/chest.png';
      case 'legs':
        return 'assets/icons/legs.png';
      case 'shoulders':
        return 'assets/icons/shoulders.png';
      case 'triceps':
        return 'assets/icons/triceps.png';
      default:
        return null;
    }
  }

  // --- SUB PAGE 4: PERSISTENT REMINDERS & WEEKLY HYDRATION ---
  Widget _buildRemindersAndHydrationContent(
      BuildContext context, StateSetter setSubState) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final currentLiters = dailyTracker.waterGlasses * 0.25;
    final goalLiters = effectiveWaterGoalGlasses * 0.25;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Gym Reminder Status",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryTextColor)),
                    CustomLoadingSwitch(
                      value: isReminderEnabled,
                      onChanged: (val) async {
                        setSubState(() => isReminderEnabled = val);
                        setState(() => isReminderEnabled = val);
                        if (val) {
                          await NotificationService().scheduleGymReminder(
                            hour: selectedGymTime.hour,
                            minute: selectedGymTime.minute,
                          );
                        } else {
                          await NotificationService().cancelGymReminders();
                        }
                      },
                    ),
                  ],
                ),
                if (isReminderEnabled) ...[
                  const Divider(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm, color: Colors.deepOrange),
                    title: Text("Time: ${selectedGymTime.format(context)}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor)),
                    subtitle: const Text(
                      "Locked Mon–Sat until you change it",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedGymTime,
                        );
                        if (picked != null) {
                          setSubState(() => selectedGymTime = picked);
                          setState(() => selectedGymTime = picked);
                          await NotificationService().scheduleGymReminder(
                            hour: picked.hour,
                            minute: picked.minute,
                          );
                          if (dailyTracker.activeGymGroup != null) {
                            await dailyTracker.updateGroupGymReminder(
                                picked.hour, picked.minute);
                          }
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(dailyTracker.activeGymGroup != null
                                  ? "Reminder updated for you & your Gym Squad!"
                                  : "Gym reminder locked at ${picked.format(this.context)}"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text("Change Time",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Water Consumption + Weekly Bar Chart (Minimum 4.00 L, +1.00 L on Creatine)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text("Water Consumption",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryTextColor)),
                    ),
                    Text(
                      "${currentLiters.toStringAsFixed(2)} / ${goalLiters.toStringAsFixed(2)} L",
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (dailyTracker.waterGlasses / effectiveWaterGoalGlasses)
                      .clamp(0.0, 1.0),
                  backgroundColor: Colors.blue.withValues(alpha: 0.2),
                  color: Colors.blueAccent,
                  minHeight: 10,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text("Creatine Cycle (+1.00 L)",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor)),
                    ),
                    CustomLoadingSwitch(
                      value: isCreatineCycle,
                      onChanged: (val) {
                        setSubState(() => isCreatineCycle = val);
                        setState(() => isCreatineCycle = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                        onPressed: () async {
                          await dailyTracker.addWaterGlass();
                          setSubState(() {});
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("+250 ml"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                        onPressed: () async {
                          await dailyTracker.addWaterGlass();
                          await dailyTracker.addWaterGlass();
                          setSubState(() {});
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("+500 ml"),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text("Weekly Hydration (Mon–Sun)",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryTextColor)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 125,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: dailyTracker.weeklyWaterData.map((dayData) {
                      final int glasses = (dayData['glasses'] ?? 0) as int;
                      final double liters = glasses * 0.25;
                      final bool isToday = dayData['is_today'] == true;
                      final double ratio =
                          (glasses / effectiveWaterGoalGlasses)
                              .clamp(0.06, 1.0);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text("${liters.toStringAsFixed(1)}L",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isToday
                                      ? Colors.blueAccent
                                      : Colors.grey)),
                          const SizedBox(height: 4),
                          Container(
                            width: 22,
                            height: 75 * ratio,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.blueAccent
                                  : Colors.blueGrey.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayData['day'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday
                                  ? Colors.deepOrange
                                  : primaryTextColor,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- SUB PAGE 5: GYM SQUAD (GROUP CHAT + ALARM SYNC + CO-LOG STRENGTH) ---
  Widget _buildGymSquadContent(BuildContext context, StateSetter setSubState) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final group = dailyTracker.activeGymGroup;

    if (group == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups, color: Colors.deepOrange, size: 28),
                  SizedBox(width: 10),
                  Text("Gym Squad",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Create a private squad with a secret entry pass or join your gym buddies' squad to:\n• Chat live with your Gym Squad buddies (auto-clears after 7 days)\n• Update the daily gym reminder for everyone in the squad\n• Log exercises once on the Strength Training page and automatically save them to selected buddies' logs",
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange),
                  onPressed: () =>
                      _showCreateOrJoinSquadDialog(context, setSubState),
                  icon: const Icon(Icons.vpn_key, color: Colors.white),
                  label: const Text("Create or Join with Entry Pass",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List members = group['members'] ?? [];
    final int? groupHour = group['gym_reminder_hour'];
    final int? groupMinute = group['gym_reminder_minute'];
    final String updatedBy = (group['reminder_updated_by'] ?? '').toString();
    final bool isGroupCreator = group['created_by'] == dailyTracker.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, color: Colors.deepOrange, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group['group_name'] ?? 'Gym Squad',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.deepOrange),
                      tooltip: "Refresh Squad",
                      onPressed: () async {
                        await dailyTracker.fetchMyGymGroup();
                        setSubState(() {});
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text("Connected Gym Buddies (${members.length})",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryTextColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: members.map((m) {
                    final isMe = m['user_id'] == dailyTracker.userId;
                    return Chip(
                      avatar: Icon(
                        isMe ? Icons.star : Icons.person,
                        size: 16,
                        color: Colors.deepOrange,
                      ),
                      label: Text(
                        isMe
                            ? "${m['user_name']} (You)"
                            : (m['user_name'] ?? 'Buddy'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Squad Group Chat Card
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(
              backgroundColor: Colors.deepOrange,
              child: Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
            title: Text("Squad Group Chat",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: primaryTextColor)),
            subtitle: Text(
              dailyTracker.squadMessages.isNotEmpty
                  ? "${dailyTracker.squadMessages.last['user_name']}: ${dailyTracker.squadMessages.last['message']}"
                  : "Message your gym buddies (chats auto-delete after 7 days)",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GymSquadChatScreen(),
                  ),
                ).then((_) => setSubState(() {}));
              },
              child: const Text("Open Chat",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Squad Shared Gym Reminder Card
        Card(
          child: ListTile(
            leading: const Icon(Icons.alarm_on, color: Colors.deepOrange),
            title: Text(
              (groupHour != null && groupMinute != null)
                  ? "Squad Reminder: ${TimeOfDay(hour: groupHour, minute: groupMinute).format(context)}"
                  : "Squad Reminder: Not Set Yet",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: primaryTextColor),
            ),
            subtitle: Text(
              updatedBy.isNotEmpty
                  ? "Last updated by $updatedBy (syncs to all members)"
                  : "Anyone in the squad can update the alarm for all",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final picked = await showTimePicker(
                  context: context,
                  initialTime: (groupHour != null && groupMinute != null)
                      ? TimeOfDay(hour: groupHour, minute: groupMinute)
                      : selectedGymTime,
                );
                if (picked != null) {
                  await dailyTracker.updateGroupGymReminder(
                      picked.hour, picked.minute);
                  setSubState(() {
                    selectedGymTime = picked;
                    isReminderEnabled = true;
                  });
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Gym reminder updated for all Gym Squad members!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text("Update",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Open Full Dedicated Strength Training Page for Co-Logging
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Log Exercise with Buddies",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryTextColor)),
                const SizedBox(height: 6),
                const Text(
                  "Open the full Strength Training page with muscle group icons, sets, super-sets & drop-sets—select buddies on the exercise page to log for everyone at once.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScaffoldPageWrapper(
                            title: 'Strength Training',
                            child: StrengthMuscleSelectorScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fitness_center, color: Colors.white),
                    label: const Text("Open Strength Training",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () async {
                await dailyTracker.leaveGymGroup();
                setSubState(() {});
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.orangeAccent),
              label: const Text("Leave Gym Squad",
                  style: TextStyle(color: Colors.orangeAccent)),
            ),
            if (isGroupCreator) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () =>
                    _showDeleteSquadDialog(context, group, setSubState),
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                label: const Text("Delete Group",
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showDeleteSquadDialog(BuildContext parentContext,
      Map<String, dynamic> group, StateSetter setSubState) {
    final passController = TextEditingController();
    bool isDeleting = false;
    final groupId = group['id'];
    final groupName = group['group_name'] ?? 'Gym Squad';

    showDialog(
      context: parentContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text("Delete Gym Squad"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This will permanently delete \"$groupName\", remove all members, and erase all squad chat history.",
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passController,
                  enabled: !isDeleting,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "Confirm Squad Entry Pass",
                    hintText: "Enter group passkey",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent),
                onPressed: isDeleting
                    ? null
                    : () async {
                        final enteredPass = passController.text.trim();
                        if (enteredPass.isEmpty) return;

                        final nav = Navigator.of(dialogCtx);
                        final messenger = ScaffoldMessenger.of(parentContext);
                        setDialogState(() => isDeleting = true);

                        try {
                          final res = await http
                              .delete(
                                Uri.parse(
                                    'https://backend-um5a.onrender.com/api/groups/$groupId'),
                                headers: {'Content-Type': 'application/json'},
                                body: json.encode({
                                  'user_id': dailyTracker.userId,
                                  'entry_pass': enteredPass,
                                }),
                              )
                              .timeout(const Duration(seconds: 30));

                          if (res.statusCode == 200) {
                            await dailyTracker.fetchMyGymGroup();
                            if (nav.canPop()) nav.pop();
                            setSubState(() {});
                            if (mounted) setState(() {});
                            messenger.showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Gym Squad deleted successfully."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            String detail = "Failed to delete group.";
                            try {
                              final body = json.decode(res.body);
                              if (body['detail'] != null) {
                                detail = body['detail'].toString();
                              }
                            } catch (_) {}
                            if (dialogCtx.mounted) {
                              setDialogState(() => isDeleting = false);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(detail),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isDeleting = false);
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Connection error. Please retry."),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Delete Forever",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateOrJoinSquadDialog(
      BuildContext parentContext, StateSetter setSubState) {
    final nameController = TextEditingController();
    final passController = TextEditingController();
    bool isJoinMode = false;
    bool isSubmitting = false;

    showDialog(
      context: parentContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isJoinMode ? "Join Gym Squad" : "Create Gym Squad"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Create"),
                        selected: !isJoinMode,
                        onSelected: (_) =>
                            setDialogState(() => isJoinMode = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Join with Pass"),
                        selected: isJoinMode,
                        onSelected: (_) =>
                            setDialogState(() => isJoinMode = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!isJoinMode) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Squad Name (e.g., Iron Brothers)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: passController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "Entry Pass (e.g., OAK2026)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pass = passController.text.trim();
                        final gName = nameController.text.trim();
                        if (pass.isEmpty || (!isJoinMode && gName.isEmpty)) {
                          return;
                        }
                        final nav = Navigator.of(dialogCtx);
                        final messenger = ScaffoldMessenger.of(dialogCtx);
                        setDialogState(() => isSubmitting = true);

                        try {
                          if (isJoinMode) {
                            await dailyTracker.joinGymGroup(pass);
                          } else {
                            await dailyTracker.createGymGroup(gName, pass);
                          }
                          if (nav.canPop()) nav.pop();
                          setSubState(() {});
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: Text(isJoinMode ? "Join Squad" : "Create Squad",
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _activityMetric(String label, String value, String subtext) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange)),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(subtext, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      Color color, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey
                            : Colors.grey[700],
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// GYM SQUAD GROUP CHAT SCREEN
// ==========================================
class GymSquadChatScreen extends StatefulWidget {
  const GymSquadChatScreen({super.key});

  @override
  State<GymSquadChatScreen> createState() => _GymSquadChatScreenState();
}

class _GymSquadChatScreenState extends State<GymSquadChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    dailyTracker.addListener(_onMessagesUpdated);
    dailyTracker.fetchSquadMessages().then((_) => _scrollToBottom());
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      dailyTracker.fetchSquadMessages();
    });
  }

  void _onMessagesUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    dailyTracker.removeListener(_onMessagesUpdated);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await dailyTracker.sendSquadMessage(text);
    _scrollToBottom();
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return "$hh:$mm";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupName = dailyTracker.activeGymGroup?['group_name'] ?? 'Gym Squad';
    final messages = dailyTracker.squadMessages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              "${(dailyTracker.activeGymGroup?['members'] as List?)?.length ?? 1} members • 7-day auto-clear",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.deepOrange),
            onPressed: () async {
              await dailyTracker.fetchSquadMessages();
              _scrollToBottom();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.deepOrange.withValues(alpha: 0.1),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_delete_outlined,
                      size: 14, color: Colors.deepOrange),
                  SizedBox(width: 6),
                  Text(
                    "Messages are stored for 7 days and deleted automatically.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          "No messages yet.\nSay hi or coordinate today's workout split!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['user_id'] == dailyTracker.userId;
                        final timeLabel =
                            _formatTime((msg['created_at'] ?? '').toString());

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.76,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.deepOrange
                                  : (isDark
                                      ? Colors.grey[850]
                                      : Colors.grey[200]),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: Radius.circular(isMe ? 14 : 2),
                                bottomRight: Radius.circular(isMe ? 2 : 14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3.0),
                                    child: Text(
                                      msg['user_name'] ?? 'Buddy',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                                Text(
                                  msg['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isMe
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (timeLabel.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    timeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Message $groupName...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.deepOrange,
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NUTRITION ANALYZER INNER SUB-PAGE ---
class NutritionAnalyzerSubPage extends StatefulWidget {
  const NutritionAnalyzerSubPage({super.key});

  @override
  State<NutritionAnalyzerSubPage> createState() =>
      _NutritionAnalyzerSubPageState();
}

class _NutritionAnalyzerSubPageState extends State<NutritionAnalyzerSubPage> {
  final TextEditingController _dishController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _errorMessage;

  Future<void> _analyze() async {
    final dish = _dishController.text.trim();
    final quantity = _quantityController.text.trim();

    if (dish.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await http
          .post(
            Uri.parse('https://backend-um5a.onrender.com/api/ai/nutrition'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'dish_name': dish,
              'quantity': quantity.isNotEmpty ? quantity : '1 portion',
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        setState(() {
          _result = data;
        });
      } else {
        setState(() {
          _errorMessage = "Analysis failed (Server status ${res.statusCode})";
        });
      }
    } catch (e) {
      debugPrint("Analysis error: $e");
      setState(() {
        _errorMessage = "Connection error. Please try again.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Enter Food Information",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryTextColor)),
                const SizedBox(height: 12),
                TextField(
                  controller: _dishController,
                  enabled: !_loading,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: "Food / Dish Name",
                    hintText: "e.g., Paneer Tikka or Oats Bowl",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  enabled: !_loading,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: "Quantity / Portion Size",
                    hintText: "e.g., 200g or 2 pieces or 1 bowl",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : _analyze,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.auto_awesome, color: Colors.black),
                    label: Text(
                        _loading ? "Analyzing Nutrients..." : "Analyze Nutrients",
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 20),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Macro Breakdown Table",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryTextColor)),
                      const Icon(Icons.table_chart, color: Colors.orange),
                    ],
                  ),
                  const Divider(height: 20),
                  Table(
                    border: TableBorder.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8)),
                    children: [
                      TableRow(children: [
                        const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Food Item",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text("${_result!['meal_name']}",
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold))),
                      ]),
                      TableRow(children: [
                        const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Calories",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text("${_result!['calories']} kcal")),
                      ]),
                      TableRow(children: [
                        const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Protein",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text("${_result!['protein_g']} g")),
                      ]),
                      TableRow(children: [
                        const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Carbs",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text("${_result!['carbs_g']} g")),
                      ]),
                      TableRow(children: [
                        const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Fat",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text("${_result!['fat_g']} g")),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// --- SUB PAGE 2: PROGRESS OVERVIEW WITH GENUINE READINGS ---
class ProgressOverviewSubPage extends StatefulWidget {
  const ProgressOverviewSubPage({super.key});

  @override
  State<ProgressOverviewSubPage> createState() =>
      _ProgressOverviewSubPageState();
}

class _ProgressOverviewSubPageState extends State<ProgressOverviewSubPage> {
  bool isPieChartMode = false;

  void _showWeekdayExercisesSubWindow(
      BuildContext context, Map<String, dynamic> dayData) {
    final dayName = dayData['day'] ?? 'Day';
    final burned = dayData['burned'] ?? 0;
    final exercises = (dayData['exercises'] as List<dynamic>?) ?? [];
    final hasDoneExercises = burned > 0 ||
        exercises.isNotEmpty ||
        (dayName == "Today" && dailyTracker.workoutLog.isNotEmpty);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final primaryTextColor = theme.colorScheme.onSurface;

        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: [
              Icon(
                hasDoneExercises ? Icons.check_circle : Icons.cancel,
                color: hasDoneExercises ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text("$dayName Exercises",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: primaryTextColor)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Burned: $burned kcal",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange)),
                const Divider(height: 16),
                if (!hasDoneExercises)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text("No exercises performed on this day.",
                        style: TextStyle(color: Colors.grey)),
                  )
                else if (dayName == "Today" &&
                    dailyTracker.workoutLog.isNotEmpty)
                  ...dailyTracker.workoutLog.map((item) {
                    final muscle = item['muscle'] ?? '';
                    final isCardio = muscle.toLowerCase() == 'cardio' ||
                        item['details'] != null;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCardio
                            ? Icons.directions_run
                            : Icons.fitness_center,
                        color: isCardio ? Colors.blueAccent : Colors.orange,
                        size: 18,
                      ),
                      title: Text("${item['muscle']} - ${item['exercise']}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor)),
                      subtitle: Text(isCardio
                          ? "${item['details']}"
                          : "Burned: ${item['caloriesBurned']} kcal"),
                    );
                  })
                else
                  ...exercises.map((item) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fitness_center,
                          color: Colors.orange, size: 18),
                      title: Text(
                          item['name'] ?? item['exercise'] ?? 'Exercise',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor)),
                      subtitle: Text(
                          "Sets: ${item['sets'] ?? 3} | Burned: ${item['calories'] ?? 100} kcal"),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close", style: TextStyle(color: Colors.orange)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPieChartMode ? "Pie Chart View" : "Bar Chart View",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryTextColor),
                    ),
                    Row(
                      children: [
                        Text("Pie Chart",
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.grey
                                    : Colors.grey[700])),
                        const SizedBox(width: 8),
                        CustomLoadingSwitch(
                          value: isPieChartMode,
                          onChanged: (val) =>
                              setState(() => isPieChartMode = val),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                isPieChartMode ? _buildPieChartView() : _buildBarChartView(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range,
                        color: Colors.deepOrange, size: 20),
                    const SizedBox(width: 8),
                    Text("Weekly Done Exercises",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryTextColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    "Tap any weekday to view performed exercises in a sub-window",
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey
                            : Colors.grey[700])),
                const Divider(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dailyTracker.weeklyProgressData.length,
                  itemBuilder: (context, index) {
                    final dayData = dailyTracker.weeklyProgressData[index];
                    final dayName = dayData['day'] ?? '';
                    final burned = (dayData['burned'] as num?)?.toInt() ?? 0;
                    final exercises =
                        (dayData['exercises'] as List<dynamic>?) ?? [];

                    final bool hasDoneExercises = burned > 0 ||
                        exercises.isNotEmpty ||
                        (dayName == "Today" &&
                            dailyTracker.workoutLog.isNotEmpty);

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4.0),
                      title: Text(dayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange)),
                      subtitle: Text(
                          "Burned: $burned kcal | Consumed: ${dayData['consumed']} kcal"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasDoneExercises
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: hasDoneExercises ? Colors.green : Colors.red,
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 18),
                        ],
                      ),
                      onTap: () =>
                          _showWeekdayExercisesSubWindow(context, dayData),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartView() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailyTracker.weeklyProgressData.map((data) {
              int consumed = (data['consumed'] as num).toInt();
              int burned = (data['burned'] as num).toInt();
              return Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: (consumed / 3000.0 * 100).clamp(10, 100),
                          decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 10,
                          height: (burned / 1000.0 * 100).clamp(10, 100),
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(data['day'],
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.square, color: Colors.deepOrange, size: 12),
                const SizedBox(width: 4),
                Text("Consumed: ${dailyTracker.totalCalories} kcal",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.square, color: Colors.green, size: 12),
                const SizedBox(width: 4),
                Text("Burned: ${dailyTracker.totalCaloriesBurned} kcal",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPieChartView() {
    final totalConsumed = dailyTracker.totalCalories;
    final totalBurned = dailyTracker.totalCaloriesBurned;
    final total =
        (totalConsumed + totalBurned) == 0 ? 1 : (totalConsumed + totalBurned);
    final consumedRatio = totalConsumed / total;
    final burnedRatio = totalBurned / total;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: CustomPaint(
                painter: _PieChartPainter(consumedRatio: consumedRatio),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${(consumedRatio * 100).toInt()}%",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepOrange)),
                Text("${(burnedRatio * 100).toInt()}%",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.square, color: Colors.deepOrange, size: 12),
            const SizedBox(width: 4),
            Text("Consumed: $totalConsumed kcal",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 16),
            const Icon(Icons.square, color: Colors.green, size: 12),
            const SizedBox(width: 4),
            Text("Burned: $totalBurned kcal",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        )
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final double consumedRatio;
  _PieChartPainter({required this.consumedRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);

    final consumedPaint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.fill;

    final burnedPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;
    double consumedSweep = 2 * math.pi * consumedRatio;
    double burnedSweep = 2 * math.pi * (1 - consumedRatio);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      consumedSweep,
      true,
      consumedPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + consumedSweep,
      burnedSweep,
      true,
      burnedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.consumedRatio != consumedRatio;
}