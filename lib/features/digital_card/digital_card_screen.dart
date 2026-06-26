import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../presentation/state/providers.dart';
import '../../data/models/card_data.dart';
import '../../data/models/digital_card.dart';

class DigitalCardScreen extends ConsumerStatefulWidget {
  final CardData card;

  const DigitalCardScreen({Key? key, required this.card}) : super(key: key);

  @override
  ConsumerState<DigitalCardScreen> createState() => _DigitalCardScreenState();
}

class _DigitalCardScreenState extends ConsumerState<DigitalCardScreen> {
  late String _vCardData;
  bool _isSaved = false;
  int? _savedDigitalCardId;
  String? _vcfFilePath;

  @override
  void initState() {
    super.initState();
    _vCardData = _generateVCardString(widget.card);
    _checkIfSaved();
  }

  String _generateVCardString(CardData card) {
    final cleanName = card.name.replaceAll('\n', ' ').trim();
    final names = cleanName.split(' ');
    String firstName = cleanName;
    String lastName = '';
    if (names.length >= 2) {
      lastName = names.last;
      firstName = names.sublist(0, names.length - 1).join(' ');
    }

    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('N:$lastName;$firstName;;;');
    buffer.writeln('FN:$cleanName');
    if (card.company.isNotEmpty) buffer.writeln('ORG:${card.company}');
    if (card.designation.isNotEmpty) buffer.writeln('TITLE:${card.designation}');
    if (card.phone.isNotEmpty) buffer.writeln('TEL;TYPE=CELL:${card.phone}');
    if (card.altPhone.isNotEmpty) buffer.writeln('TEL;TYPE=WORK,VOICE:${card.altPhone}');
    if (card.email.isNotEmpty) buffer.writeln('EMAIL;TYPE=PREF,INTERNET:${card.email}');
    if (card.website.isNotEmpty) buffer.writeln('URL:${card.website}');
    if (card.address.isNotEmpty) {
      buffer.writeln('ADR;TYPE=WORK:;;${card.address};${card.city};${card.state};${card.pincode};${card.country}');
    }
    if (card.notes.isNotEmpty) buffer.writeln('NOTE:${card.notes}');
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  Future<void> _checkIfSaved() async {
    if (widget.card.id == null) return;
    try {
      final digitalCard = await ref.read(cardRepositoryProvider).getDigitalCard(widget.card.id!);
      if (digitalCard != null && mounted) {
        setState(() {
          _isSaved = true;
          _savedDigitalCardId = digitalCard.id;
          _vcfFilePath = digitalCard.vcfPath;
        });
      }
    } catch (_) {}
  }

  Future<String> _writeVcfFileToStorage() async {
    if (_vcfFilePath != null && File(_vcfFilePath!).existsSync()) {
      return _vcfFilePath!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'contact_${widget.card.name.replaceAll(' ', '_')}_${widget.card.id ?? DateTime.now().millisecondsSinceEpoch}.vcf';
    final fullPath = p.join(directory.path, fileName);
    final file = File(fullPath);
    await file.writeAsString(_vCardData);
    
    setState(() {
      _vcfFilePath = fullPath;
    });
    return fullPath;
  }

  Future<void> _saveDigitalCard() async {
    if (widget.card.id == null) {
      _showSnackBar('Save the scanned card contact details first.');
      return;
    }

    try {
      final vcfPath = await _writeVcfFileToStorage();

      final digitalCard = DigitalCard(
        scannedCardId: widget.card.id!,
        qrCodePath: '', // Will just generate dynamically from vcf data on display
        vcfPath: vcfPath,
        createdAt: DateTime.now(),
      );

      await ref.read(digitalCardsProvider.notifier).saveDigitalCard(digitalCard);
      await _checkIfSaved();

      _showSnackBar('Digital card saved successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Error saving digital card: $e', Colors.red);
    }
  }

  Future<void> _shareDigitalCard() async {
    try {
      final vcfPath = await _writeVcfFileToStorage();
      await Share.shareXFiles(
        [XFile(vcfPath)],
        text: 'Kloudera Digital Business Card: ${widget.card.name}',
      );
    } catch (e) {
      _showSnackBar('Error sharing card: $e', Colors.red);
    }
  }

  Future<void> _addToContacts() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
      final isGranted = status == PermissionStatus.granted || status == PermissionStatus.limited;

      if (isGranted) {
        final card = widget.card;
        final cleanName = card.name.replaceAll('\n', ' ').trim();
        final names = cleanName.split(' ');
        String firstName = cleanName;
        String lastName = '';
        if (names.length >= 2) {
          lastName = names.last;
          firstName = names.sublist(0, names.length - 1).join(' ');
        }

        final contact = Contact(
          name: Name(first: firstName, last: lastName),
          organizations: [
            Organization(
              name: card.company,
              jobTitle: card.designation,
            ),
          ],
          phones: [
            if (card.phone.isNotEmpty)
              Phone(number: card.phone, label: const Label(PhoneLabel.mobile)),
            if (card.altPhone.isNotEmpty)
              Phone(number: card.altPhone, label: const Label(PhoneLabel.work)),
          ],
          emails: [
            if (card.email.isNotEmpty)
              Email(address: card.email, label: const Label(EmailLabel.home)),
          ],
          websites: [
            if (card.website.isNotEmpty)
              Website(url: card.website, label: const Label(WebsiteLabel.homepage)),
          ],
          addresses: [
            if (card.address.isNotEmpty)
              Address(
                street: card.address,
                city: card.city,
                state: card.state,
                postalCode: card.pincode,
                country: card.country,
                label: const Label(AddressLabel.work),
              ),
          ],
          notes: [
            if (card.notes.isNotEmpty)
              Note(note: card.notes),
          ],
        );

        await FlutterContacts.create(contact);
        
        if (mounted) {
          _showSnackBar('Contact saved successfully to your phone book!', Colors.green);
        }
      } else {
        if (mounted) {
          _showSnackBar('Contacts permission denied.', Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar('Error saving contact: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Visiting Card'),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _isSaved ? null : _saveDigitalCard,
            tooltip: _isSaved ? 'Saved' : 'Save Card',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDigitalCard,
            tooltip: 'Share Card',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Preview Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.card.company.isNotEmpty ? widget.card.company.toUpperCase() : 'KLOUDERA TECHNOLOGIES',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'DIGITAL PASS',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 8,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.radar, color: Colors.white.withOpacity(0.8), size: 28),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      widget.card.name.isNotEmpty ? widget.card.name : 'Your Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Text(
                      widget.card.designation.isNotEmpty ? widget.card.designation : 'Your Designation',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 16),
                    _buildPreviewContactItem(Icons.phone, widget.card.phone),
                    _buildPreviewContactItem(Icons.email, widget.card.email),
                    _buildPreviewContactItem(Icons.language, widget.card.website),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // QR Code Section
            Column(
              children: [
                const Text(
                  'Scan QR to Add to Contacts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, // Ensure light background for QR contrast
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _vCardData,
                    version: QrVersions.auto,
                    size: 160.0,
                    gapless: false,
                    errorStateBuilder: (cxt, err) {
                      return const Center(
                        child: Text(
                          'Could not generate QR Code',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // Actions Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildActionCard(
                  context,
                  'Add to Contacts',
                  Icons.person_add,
                  Theme.of(context).colorScheme.primary,
                  _addToContacts,
                ),
                _buildActionCard(
                  context,
                  'Share vCard (VCF)',
                  Icons.share,
                  Theme.of(context).colorScheme.secondary,
                  _shareDigitalCard,
                ),
                _buildActionCard(
                  context,
                  'Save Digital Card',
                  Icons.save_alt,
                  Colors.green,
                  _isSaved ? null : _saveDigitalCard,
                ),
                _buildActionCard(
                  context,
                  'Export Local VCF',
                  Icons.download,
                  Colors.amber.shade800,
                  () async {
                    final path = await _writeVcfFileToStorage();
                    _showSnackBar('vCard exported to: $path', Colors.green);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContactItem(IconData icon, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String label, IconData icon, Color color, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        color: isEnabled ? null : Theme.of(context).cardTheme.color?.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: 'Outfit',
                    color: isEnabled ? null : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen displaying the list of Saved Digital Cards
class DigitalCardListScreen extends ConsumerWidget {
  const DigitalCardListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digitalCardsAsync = ref.watch(digitalCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Digital Cards'),
      ),
      body: digitalCardsAsync.when(
        data: (savedList) {
          if (savedList.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: savedList.length,
            itemBuilder: (context, index) {
              final dCard = savedList[index];
              return _buildDigitalCardListItem(context, ref, dCard);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading digital cards: $err')),
      ),
    );
  }

  Widget _buildDigitalCardListItem(BuildContext context, WidgetRef ref, DigitalCard dCard) {
    return FutureBuilder<CardData?>(
      future: ref.read(cardRepositoryProvider).getCard(dCard.scannedCardId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(bottom: 12),
            child: SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
          );
        }

        final card = snapshot.data;
        if (card == null) {
          return const SizedBox.shrink(); // Orphaned digital card
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Text(
                card.name.isNotEmpty ? card.name[0].toUpperCase() : 'U',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${card.designation} @ ${card.company}', style: const TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DigitalCardScreen(card: card),
                ),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(context, ref, dCard.id!),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, int digitalCardId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Digital Card'),
        content: const Text('Are you sure you want to remove this digital card from your saved shelf?\n\nNote: This will not delete the underlying contact details or Excel sheets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(digitalCardsProvider.notifier).deleteDigitalCard(digitalCardId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
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
            Icon(Icons.badge_outlined, size: 72, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No Saved Digital Cards',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a digital visiting card from any scanned card details and hit bookmark to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
