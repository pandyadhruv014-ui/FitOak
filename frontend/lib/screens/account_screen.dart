import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';
import '../widgets/custom_loading_switch.dart';
import 'auth_screens.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool activityRecognitionGranted = true;
  bool locationPermissionGranted = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme-aware color palette
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = isDark ? Colors.grey : Colors.grey[700];
    final borderColor = Colors.deepOrange.withValues(alpha: isDark ? 0.4 : 0.6);

    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('User Account & Profile', style: TextStyle(fontWeight: FontWeight.bold))),
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor),
                ),
              ),
              Center(
                child: Text(
                  dailyTracker.email.isEmpty ? 'user@fitoak.com' : dailyTracker.email,
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
              ),
              const SizedBox(height: 20),

              // USER PROFILE METRICS CARD
              Card(
                color: cardBgColor,
                elevation: isDark ? 1 : 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Body Metrics & Profile",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metricItem("DOB", dailyTracker.dob.isEmpty ? "N/A" : dailyTracker.dob, primaryTextColor, secondaryTextColor),
                          _metricItem("Height", "${dailyTracker.heightCm} cm", primaryTextColor, secondaryTextColor),
                          _metricItem("Weight", "${dailyTracker.weightKg} kg", primaryTextColor, secondaryTextColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          "Primary Goal: ${dailyTracker.fitnessGoal}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.amber : Colors.deepOrange[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // APP APPEARANCE SECTION
              const Text("App Appearance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 8),
              Card(
                color: cardBgColor,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: ListTile(
                  leading: const Icon(Icons.dark_mode, color: Colors.deepOrange),
                  title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                  subtitle: Text('Switch between light and dark themes', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                  trailing: CustomLoadingSwitch(
                    value: dailyTracker.isDarkMode,
                    onChanged: (val) => dailyTracker.toggleTheme(val),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // DEVICE PERMISSIONS SECTION
              const Text("Device Permissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 8),
              Card(
                color: cardBgColor,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.directions_walk, color: Colors.deepOrange),
                      title: Text('Activity Recognition (Pedometer)', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                      subtitle: Text('Tracks steps & real-time motion data', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                      trailing: CustomLoadingSwitch(
                        value: activityRecognitionGranted,
                        onChanged: (val) => setState(() => activityRecognitionGranted = val),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.deepOrange),
                      title: Text('Location Services', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                      subtitle: Text('Accurate GPS distance logging', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                      trailing: CustomLoadingSwitch(
                        value: locationPermissionGranted,
                        onChanged: (val) => setState(() => locationPermissionGranted = val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // LOGOUT ACTION BUTTON
              Card(
                color: cardBgColor,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: ListTile(
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricItem(String label, String value, Color primaryTextColor, Color? secondaryTextColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
      ],
    );
  }
}