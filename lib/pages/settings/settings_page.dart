import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/demo_data_seeder.dart';
import '../../utils/data_export.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _lastSyncStatus;
  String? _lastSyncTimestamp;
  int _lastSyncCount = 0;
  bool _syncingNow = false;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  void _loadSyncStatus() {
    final db = DatabaseService();
    setState(() {
      _lastSyncStatus = db.getSetting('sync_last_status')?.toString();
      _lastSyncTimestamp = db.getSetting('sync_last_timestamp')?.toString();
      _lastSyncCount = (db.getSetting('sync_last_count', defaultValue: 0) as num).toInt();
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncingNow = true;
    });
    final ok = await DatabaseService().syncToCloud();
    if (!mounted) return;
    _loadSyncStatus();
    setState(() {
      _syncingNow = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Cloud sync completed' : 'Cloud sync failed'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _seedDemoData(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Demo Data'),
        content: const Text(
          'This will add sample health data for the past 7 days including workouts, hydration, nutrition, mood logs, and more.\n\nThis is useful for testing and demonstration purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add Demo Data'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Seeding demo data...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final seeder = DemoDataSeeder(user.id);
      await seeder.seedAllData();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo data added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error seeding data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing export...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exporter = DataExporter(user.id);
      await exporter.exportAllData();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();
    bool isLoading = false;

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter your password to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your password')),
                        );
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      final user = ref.read(currentUserProvider);
                      if (user == null) return;

                      final authService = AuthService();
                      final result = await authService.deleteAccount(
                        user.id,
                        passwordController.text,
                      );

                      setState(() {
                        isLoading = false;
                      });

                      if (context.mounted) {
                        Navigator.pop(context, result.success);

                        if (result.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.landing,
                            (route) => false,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildListTile(
            context,
            icon: Icons.person,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.editProfile);
            },
          ),
          _buildListTile(
            context,
            icon: Icons.lock,
            title: 'Change Password',
            subtitle: 'Update your password',
            onTap: () {
              Navigator.pushNamed(context, '/change-password');
            },
          ),

          // Security Section (new)
          _buildSectionHeader(context, 'Security'),
          _buildListTile(
            context,
            icon: Icons.security,
            title: 'Multi-Factor Authentication',
            subtitle: 'Add extra security to your account',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.mfaSettings);
            },
          ),
          const Divider(),

          // Preferences Section
          _buildSectionHeader(context, 'Preferences'),
          _buildListTile(
            context,
            icon: Icons.language,
            title: 'Language',
            subtitle: 'Change app language',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.language);
            },
          ),
          _buildListTile(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification settings coming soon!')),
              );
            },
          ),
          const Divider(),

          // Data & Privacy Section
          _buildSectionHeader(context, 'Data & Privacy'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cloud Sync Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('Status: ${_lastSyncStatus ?? 'Not synced yet'}'),
                if (_lastSyncTimestamp != null)
                  Text('Last sync: $_lastSyncTimestamp'),
                Text('Last synced records: $_lastSyncCount'),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _syncingNow ? null : _syncNow,
                  icon: _syncingNow
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync),
                  label: Text(_syncingNow ? 'Syncing...' : 'Sync Now'),
                ),
              ],
            ),
          ),
          _buildListTile(
            context,
            icon: Icons.download,
            title: 'Export Data',
            subtitle: 'Download your health data as CSV',
            onTap: () => _exportData(context, ref),
          ),
          _buildListTile(
            context,
            icon: Icons.science,
            title: 'Seed Demo Data',
            subtitle: 'Add sample data for testing',
            onTap: () => _seedDemoData(context, ref),
          ),
          _buildListTile(
            context,
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon!')),
              );
            },
          ),
          const Divider(),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildListTile(
            context,
            icon: Icons.info,
            title: 'About NovaHealth',
            subtitle: 'Version 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'NovaHealth',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.favorite, color: AppTheme.primaryGreen, size: 48),
                children: [
                  const Text('Your AI-powered health companion'),
                  const SizedBox(height: 8),
                  const Text('Track your health, achieve your goals, and live better.'),
                ],
              );
            },
          ),
          _buildListTile(
            context,
            icon: Icons.help,
            title: 'Help & Support',
            subtitle: 'Get help or contact support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support feature coming soon!')),
              );
            },
          ),
          const Divider(),

          // Danger Zone
          _buildSectionHeader(context, 'Danger Zone'),
          _buildListTile(
            context,
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and data',
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
          const SizedBox(height: 24),

          // User Info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryGreen,
                  child: Text(
                    (user?.username ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? user?.username ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppTheme.primaryGreen),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.white,
      ),
    );
  }
}
