import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';
import 'auth_screens.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool activityRecognitionGranted = true;
  bool locationPermissionGranted = false;
  bool notificationPermissionGranted = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('User Account & Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  dailyTracker.fullName.isEmpty ? 'FitOak User' : dailyTracker.fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  dailyTracker.email.isEmpty ? 'user@fitoak.com' : dailyTracker.email,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),

              // USER PROFILE METRICS CARD
              Card(
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Your Body Metrics & Goals", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metricItem("Age", "${dailyTracker.age} yrs"),
                          _metricItem("Height", "${dailyTracker.heightCm} cm"),
                          _metricItem("Weight", "${dailyTracker.weightKg} kg"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(child: Text("Primary Goal: ${dailyTracker.fitnessGoal}", style: const TextStyle(fontSize: 13, color: Colors.amber, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              const Text("App Appearance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: dailyTracker.isDarkMode,
                activeTrackColor: Colors.deepOrange,
                onChanged: (val) => dailyTracker.toggleTheme(val),
              ),
              const Divider(),

              const Text("Device Permissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              SwitchListTile(
                title: const Text('Activity Recognition (Pedometer)'),
                value: activityRecognitionGranted,
                activeTrackColor: Colors.deepOrange,
                onChanged: (val) => setState(() => activityRecognitionGranted = val),
              ),
              SwitchListTile(
                title: const Text('Location Services'),
                value: locationPermissionGranted,
                activeTrackColor: Colors.deepOrange,
                onChanged: (val) => setState(() => locationPermissionGranted = val),
              ),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Sign Out / Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await dailyTracker.logoutUser();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGateScreen()),
                  (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}