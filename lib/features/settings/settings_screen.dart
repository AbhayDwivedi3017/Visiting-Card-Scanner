import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/state/providers.dart';
import '../../core/database/database_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Section 1: Appearance
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable obsidian dark palette'),
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            value: isDark,
            onChanged: (_) {
              ref.read(darkModeProvider.notifier).toggleTheme();
            },
          ),
          
          const Divider(),

          // Section 2: Storage & Database Stats
          _buildSectionHeader('Storage & Stats'),
          statsAsync.when(
            data: (stats) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.contact_phone),
                  title: const Text('Cards Scanned'),
                  trailing: Text(
                    '${stats['cardsScanned']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Excel Files Linked'),
                  trailing: Text(
                    '${stats['excelFiles']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
            error: (err, _) => ListTile(title: Text('Error loading stats: $err')),
          ),

          const Divider(),

          // Section 3: Data Actions
          _buildSectionHeader('Data Management'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Wipe Local Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Deletes all scanned cards metadata and saved digital cards from database'),
            onTap: () => _showWipeConfirmation(context, ref),
          ),

          const Divider(),

          // Section 4: About
          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Kloudera Visiting Card Scanner'),
            subtitle: Text('Version 1.0.0 (Production-Ready)'),
          ),
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Company Ownership'),
            subtitle: Text('Licensed to Kloudera Technologies Private Limited'),
          ),
          
          const SizedBox(height: 48),
          Center(
            child: Text(
              '© ${DateTime.now().year} Kloudera Technologies',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showWipeConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe All Local Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to wipe the app database? This will permanently delete all contacts metadata and saved digital cards.\n\n'
          'Note: Scanned images and actual Excel sheets files stored in the device documents folder will NOT be deleted, but all references within this app will be cleared.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              
              // Get database and wipe
              final db = await DatabaseHelper.instance.database;
              await db.transaction((txn) async {
                await txn.delete('digital_cards');
                await txn.delete('scanned_cards');
                await txn.delete('excel_refs');
              });

              // Force reload providers to clear lists
              ref.read(cardsProvider.notifier).loadCards();
              ref.read(excelRefsProvider.notifier).loadRefs();
              ref.read(statsProvider.notifier).loadStats();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All local database records wiped successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Wipe Data'),
          ),
        ],
      ),
    );
  }
}
