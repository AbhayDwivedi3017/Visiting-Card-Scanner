import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/state/providers.dart';
import '../../data/models/card_data.dart';
import '../../data/models/excel_ref.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/edit_card_screen.dart';
import '../excel/excel_list_screen.dart';
import '../digital_card/digital_card_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCompany;
  int? _selectedExcelId;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCompany = null;
      _selectedExcelId = null;
    });
    ref.read(cardsProvider.notifier).loadCards();
  }

  void _applySearch() {
    ref.read(cardsProvider.notifier).loadCards(
      query: _searchController.text.trim(),
      companyFilter: _selectedCompany,
      excelSheetFilter: _selectedExcelId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsProvider);
    final cardsAsync = ref.watch(cardsProvider);
    final companiesAsync = ref.watch(companiesProvider);
    final excelRefsAsync = ref.watch(excelRefsProvider);
    final isDark = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.radar,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kloudera',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                Text(
                  'Card Scanner',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(darkModeProvider.notifier).toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(cardsProvider.notifier).loadCards();
          ref.read(excelRefsProvider.notifier).loadRefs();
          ref.read(statsProvider.notifier).loadStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Card Grid
                statsAsync.when(
                  data: (stats) => Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Cards',
                          stats['cardsScanned']?.toString() ?? '0',
                          Icons.contact_phone,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Excel Sheets',
                          stats['excelFiles']?.toString() ?? '0',
                          Icons.table_chart,
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (err, _) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 24),
                
                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _buildActionButton(
                      context,
                      'Scan & Save',
                      'Scan to Excel Sheet',
                      Icons.document_scanner,
                      Theme.of(context).colorScheme.primary,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScannerScreen(mode: ScannerMode.scanToExcel)),
                      ),
                    ),
                    _buildActionButton(
                      context,
                      'Digital Card',
                      'Create VCF & QR',
                      Icons.qr_code,
                      Theme.of(context).colorScheme.secondary,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScannerScreen(mode: ScannerMode.createDigitalCard)),
                      ),
                    ),
                    _buildActionButton(
                      context,
                      'Excel Sheets',
                      'View created files',
                      Icons.folder,
                      Colors.green,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ExcelListScreen()),
                      ),
                    ),
                    _buildActionButton(
                      context,
                      'Saved Cards',
                      'Preview digital cards',
                      Icons.badge,
                      Colors.amber.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DigitalCardListScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Search Bar & Filter Headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Scans',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showFilterBottomSheet(context, companiesAsync, excelRefsAsync),
                      icon: Icon(
                        Icons.filter_list,
                        size: 16,
                        color: (_selectedCompany != null || _selectedExcelId != null)
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                      ),
                      label: Text(
                        'Filter',
                        style: TextStyle(
                          color: (_selectedCompany != null || _selectedExcelId != null)
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _isSearching = val.isNotEmpty;
                    });
                    _applySearch();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Company, Email or Phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                              });
                              _applySearch();
                            },
                          )
                        : null,
                  ),
                ),

                // Active Filters Chips
                if (_selectedCompany != null || _selectedExcelId != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_selectedCompany != null)
                        InputChip(
                          label: Text(_selectedCompany!),
                          onDeleted: () {
                            setState(() => _selectedCompany = null);
                            _applySearch();
                          },
                        ),
                      if (_selectedExcelId != null)
                        FutureBuilder<ExcelRef?>(
                          future: ref.read(cardRepositoryProvider).getExcelRef(_selectedExcelId!),
                          builder: (context, snapshot) {
                            final name = snapshot.data?.name ?? 'Sheet';
                            return InputChip(
                              label: Text(name),
                              onDeleted: () {
                                setState(() => _selectedExcelId = null);
                                _applySearch();
                              },
                            );
                          },
                        ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Recent Scans List
                cardsAsync.when(
                  data: (cards) {
                    if (cards.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return _buildCardItem(context, card);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error loading scans: $err'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String val, IconData icon, Color color) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, CardData card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: card.imagePath.isNotEmpty && File(card.imagePath).existsSync()
              ? Image.file(
                  File(card.imagePath),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        ),
        title: Text(
          card.name.isNotEmpty ? card.name : 'Unknown Contact',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.designation.isNotEmpty || card.company.isNotEmpty)
              Text(
                [card.designation, card.company].where((s) => s.isNotEmpty).join(' @ '),
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (card.phone.isNotEmpty) ...[
                  const Icon(Icons.phone, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(card.phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 8),
                ],
                if (card.email.isNotEmpty) ...[
                  const Icon(Icons.email, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      card.email,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) async {
            if (val == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditCardScreen(card: card),
                ),
              );
            } else if (val == 'delete') {
              _showDeleteConfirmation(context, card);
            } else if (val == 'digital') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DigitalCardScreen(card: card),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'digital',
              child: Row(
                children: [
                  Icon(Icons.qr_code, size: 18),
                  SizedBox(width: 8),
                  Text('Digital Card'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_front,
              size: 72,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Visiting Cards Scanned Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan physical business cards to extract details, save them to Excel spreadsheets, and generate digital cards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerScreen(mode: ScannerMode.scanToExcel)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Scan Card Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, CardData card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${card.name}? This will also delete this row from the linked Excel sheet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (card.id != null) {
                ref.read(cardsProvider.notifier).deleteCard(card.id!);
              }
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, AsyncValue<List<String>> companiesAsync, AsyncValue<List<ExcelRef>> excelRefsAsync) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Scans',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCompany = null;
                            _selectedExcelId = null;
                          });
                          _clearFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Company Filter Dropdown
                  const Text('Filter by Company', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 8),
                  companiesAsync.when(
                    data: (companies) => DropdownButtonFormField<String>(
                      value: _selectedCompany,
                      hint: const Text('Select Company'),
                      items: companies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          _selectedCompany = val;
                        });
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading companies'),
                  ),
                  const SizedBox(height: 20),

                  // Excel Sheet Filter Dropdown
                  const Text('Filter by Excel Sheet', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 8),
                  excelRefsAsync.when(
                    data: (refs) => DropdownButtonFormField<int>(
                      value: _selectedExcelId,
                      hint: const Text('Select Excel File'),
                      items: refs
                          .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          _selectedExcelId = val;
                        });
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading Excel files'),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applySearch();
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
