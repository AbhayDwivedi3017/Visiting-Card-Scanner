import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../presentation/state/providers.dart';
import '../../data/models/excel_ref.dart';
import '../../data/models/card_data.dart';
import '../scanner/edit_card_screen.dart';

class ExcelListScreen extends ConsumerWidget {
  const ExcelListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excelRefsAsync = ref.watch(excelRefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Files'),
      ),
      body: excelRefsAsync.when(
        data: (refs) {
          if (refs.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: refs.length,
            itemBuilder: (context, index) {
              final refItem = refs[index];
              return _buildExcelListItem(context, ref, refItem);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading Excel files: $err')),
      ),
    );
  }

  Widget _buildExcelListItem(BuildContext context, WidgetRef ref, ExcelRef refItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.table_chart, color: Colors.green),
        ),
        title: Text(
          refItem.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Created: ${_formatDate(refItem.createdAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              refItem.filePath,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        onTap: () {
          // Open details page for cards scanned in this excel file
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExcelDetailScreen(excelRef: refItem),
            ),
          );
        },
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'open') {
              _openFile(refItem.filePath, context);
            } else if (val == 'share') {
              _shareFile(refItem.filePath, refItem.name);
            } else if (val == 'rename') {
              _showRenameDialog(context, ref, refItem);
            } else if (val == 'delete') {
              _showDeleteConfirmation(context, ref, refItem);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new, size: 18),
                  SizedBox(width: 8),
                  Text('Open File'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 18),
                  SizedBox(width: 8),
                  Text('Share File'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Rename File'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete File', style: TextStyle(color: Colors.red)),
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 72, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No Excel Files Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can create new Excel sheets directly when saving a scanned card.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(String filePath, BuildContext context) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
      } else {
        throw Exception('File does not exist on disk.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFile(String filePath, String name) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(filePath)], text: 'Excel Sheet: $name');
      }
    } catch (e) {
      // Handle error quietly or show logs
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, ExcelRef refItem) {
    final nameController = TextEditingController(text: refItem.name.replaceAll('.xlsx', ''));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Excel File'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'New file name',
            suffixText: '.xlsx',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await ref.read(excelRefsProvider.notifier).renameExcel(refItem, newName);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rename failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, ExcelRef refItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Excel File'),
        content: Text('Are you sure you want to delete ${refItem.name}?\n\nWarning: This will delete the actual .xlsx file from storage. The scanned cards metadata inside SQLite database will remain, but will no longer be linked to this Excel file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(excelRefsProvider.notifier).deleteExcel(refItem);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}

// Sub-screen showing cards parsed in a specific Excel Sheet
class ExcelDetailScreen extends ConsumerStatefulWidget {
  final ExcelRef excelRef;

  const ExcelDetailScreen({Key? key, required this.excelRef}) : super(key: key);

  @override
  ConsumerState<ExcelDetailScreen> createState() => _ExcelDetailScreenState();
}

class _ExcelDetailScreenState extends ConsumerState<ExcelDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load only cards matching this sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cardsProvider.notifier).loadCards(excelSheetFilter: widget.excelRef.id);
    });
  }

  @override
  void dispose() {
    // Reset filters and reload all cards on exit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cardsProvider.notifier).loadCards();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.excelRef.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final file = File(widget.excelRef.filePath);
              if (file.existsSync()) {
                Share.shareXFiles([XFile(widget.excelRef.filePath)], text: 'Export: ${widget.excelRef.name}');
              }
            },
            tooltip: 'Share file',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () async {
              if (File(widget.excelRef.filePath).existsSync()) {
                await OpenFilex.open(widget.excelRef.filePath);
              }
            },
            tooltip: 'Open Excel',
          ),
        ],
      ),
      body: cardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.contact_phone_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text(
                      'No Contacts in this Sheet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan new visiting cards and select this Excel sheet to add records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${card.designation} @ ${card.company}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditCardScreen(card: card),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading sheet contacts: $err')),
      ),
    );
  }
}
