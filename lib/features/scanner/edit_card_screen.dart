import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/state/providers.dart';
import '../../data/models/card_data.dart';
import '../../data/models/excel_ref.dart';
import '../digital_card/digital_card_screen.dart';

class EditCardScreen extends ConsumerStatefulWidget {
  final CardData card;
  final bool isNewScan;
  final bool startDigitalCardFlow;

  const EditCardScreen({
    Key? key,
    required this.card,
    this.isNewScan = false,
    this.startDigitalCardFlow = false,
  }) : super(key: key);

  @override
  ConsumerState<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends ConsumerState<EditCardScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _companyController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _pincodeController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card.name);
    _designationController = TextEditingController(text: widget.card.designation);
    _companyController = TextEditingController(text: widget.card.company);
    _phoneController = TextEditingController(text: widget.card.phone);
    _altPhoneController = TextEditingController(text: widget.card.altPhone);
    _emailController = TextEditingController(text: widget.card.email);
    _websiteController = TextEditingController(text: widget.card.website);
    _addressController = TextEditingController(text: widget.card.address);
    _cityController = TextEditingController(text: widget.card.city);
    _stateController = TextEditingController(text: widget.card.state);
    _countryController = TextEditingController(text: widget.card.country);
    _pincodeController = TextEditingController(text: widget.card.pincode);
    _notesController = TextEditingController(text: widget.card.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  CardData _getUpdatedCardData([int? excelRefId]) {
    return widget.card.copyWith(
      excelRefId: excelRefId ?? widget.card.excelRefId,
      name: _nameController.text.trim(),
      designation: _designationController.text.trim(),
      company: _companyController.text.trim(),
      phone: _phoneController.text.trim(),
      altPhone: _altPhoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      pincode: _pincodeController.text.trim(),
      notes: _notesController.text.trim(),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isNewScan) {
      // 1. New Scan: Prompt user to choose Excel Destination
      _showExcelDestinationPrompt();
    } else {
      // 2. Existing Card update: Run duplicate checks directly
      final cardToSave = _getUpdatedCardData();
      _runDuplicateChecks(cardToSave, isUpdating: true);
    }
  }

  void _showExcelDestinationPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Destination', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: const Text('Choose how you would like to store this business card details:'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Create New Excel File'),
            onPressed: () {
              Navigator.pop(context);
              _promptCreateExcelName();
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Add to Existing Excel File'),
            onPressed: () {
              Navigator.pop(context);
              _showExistingExcelSelector();
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.cloud_off),
            label: const Text('Save Standalone (No Excel)'),
            onPressed: () {
              Navigator.pop(context);
              final cardToSave = _getUpdatedCardData(null);
              _runDuplicateChecks(cardToSave, isUpdating: false);
            },
          ),
        ],
      ),
    );
  }

  void _promptCreateExcelName() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel File Name', style: TextStyle(fontFamily: 'Outfit')),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name (e.g., Q2 Contacts)',
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
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                try {
                  // Create Excel Sheet
                  final excelRef = await ref.read(excelRefsProvider.notifier).createExcel(name);
                  final cardToSave = _getUpdatedCardData(excelRef.id);
                  _runDuplicateChecks(cardToSave, isUpdating: false);
                } catch (e) {
                  _showErrorSnackBar(e.toString());
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showExistingExcelSelector() {
    final excelRefsAsync = ref.watch(excelRefsProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Excel Sheet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 12),
              excelRefsAsync.when(
                data: (refs) {
                  if (refs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            const Text('No Excel files created yet.'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _promptCreateExcelName();
                              },
                              child: const Text('Create One Now'),
                            )
                          ],
                        ),
                      ),
                    );
                  }
                  return Expanded(
                    child: ListView.builder(
                      itemCount: refs.length,
                      itemBuilder: (context, index) {
                        final refItem = refs[index];
                        return ListTile(
                          leading: const Icon(Icons.table_chart, color: Colors.green),
                          title: Text(refItem.name),
                          onTap: () {
                            Navigator.pop(context);
                            final cardToSave = _getUpdatedCardData(refItem.id);
                            _runDuplicateChecks(cardToSave, isUpdating: false);
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading files: $err'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runDuplicateChecks(CardData cardToSave, {required bool isUpdating}) async {
    try {
      final repo = ref.read(cardRepositoryProvider);
      
      // Query database for duplicates by email or phone
      final duplicate = await repo.checkDuplicate(cardToSave.phone, cardToSave.email);
      
      // If a duplicate exists and it's not the exact same card we are updating
      if (duplicate != null && duplicate.id != cardToSave.id) {
        _showDuplicateResolutionDialog(cardToSave, duplicate, isUpdating);
      } else {
        // No duplicate, save directly
        _saveToStorage(cardToSave, isUpdating);
      }
    } catch (e) {
      _showErrorSnackBar('Duplicate check failed: $e');
    }
  }

  void _showDuplicateResolutionDialog(CardData currentCard, CardData duplicateCard, bool isUpdating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Contact Found', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        content: Text(
          'An entry with the same Email (${currentCard.email}) or Phone (${currentCard.phone}) already exists in the database:\n\n'
          'Existing Contact: ${duplicateCard.name} (${duplicateCard.company})\n\n'
          'What would you like to do?'
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              // Update the existing duplicate entry with new details, keeping duplicate's ID
              final mergedCard = currentCard.copyWith(
                id: duplicateCard.id,
                excelRefId: duplicateCard.excelRefId, // keep linked sheet
              );
              _saveToStorage(mergedCard, true); // true = update existing
            },
            child: const Text('Update Existing Entry'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              // Save as a completely new entry, ignoring duplicate check
              _saveToStorage(currentCard, isUpdating); 
            },
            child: const Text('Save As New Entry'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel & Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToStorage(CardData cardToSave, bool isUpdating) async {
    try {
      int savedCardId = cardToSave.id ?? -1;

      if (isUpdating) {
        await ref.read(cardsProvider.notifier).updateCard(cardToSave);
      } else {
        savedCardId = await ref.read(cardsProvider.notifier).saveCard(cardToSave);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact details saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.startDigitalCardFlow) {
          // Navigate to Digital Card generator
          final cardData = cardToSave.copyWith(id: isUpdating ? cardToSave.id : savedCardId);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DigitalCardScreen(card: cardData),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Save operation failed: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNewScan ? 'Verify Scanned Details' : 'Edit Contact Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _handleSave,
            tooltip: 'Save Card',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo Thumbnail Card
              if (widget.card.imagePath.isNotEmpty && File(widget.card.imagePath).existsSync()) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.black12,
                        child: Image.file(
                          File(widget.card.imagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo, size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Original Visited Card Image', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Group 1: Profile Info
              _buildSectionTitle(context, 'Profile Details'),
              _buildTextField('Full Name', _nameController, Icons.person, (val) => val == null || val.isEmpty ? 'Name is required' : null),
              _buildTextField('Designation / Job Title', _designationController, Icons.work_outline),
              _buildTextField('Company Name', _companyController, Icons.business),
              
              const SizedBox(height: 20),

              // Group 2: Contact
              _buildSectionTitle(context, 'Contact Details'),
              _buildTextField('Phone / Mobile Number', _phoneController, Icons.phone, null, TextInputType.phone),
              _buildTextField('Alternate Phone', _altPhoneController, Icons.phone_android, null, TextInputType.phone),
              _buildTextField('Email Address', _emailController, Icons.email, (val) {
                if (val != null && val.isNotEmpty) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                    return 'Invalid email address format';
                  }
                }
                return null;
              }, TextInputType.emailAddress),
              _buildTextField('Website URL', _websiteController, Icons.language, null, TextInputType.url),

              const SizedBox(height: 20),

              // Group 3: Location
              _buildSectionTitle(context, 'Location Details'),
              _buildTextField('Address', _addressController, Icons.location_on),
              Row(
                children: [
                  Expanded(child: _buildTextField('City', _cityController, Icons.location_city)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField('State', _stateController, Icons.map)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField('Country', _countryController, Icons.public)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField('Pincode / ZIP', _pincodeController, Icons.pin_drop, null, TextInputType.number)),
                ],
              ),

              const SizedBox(height: 20),

              // Group 4: Additional
              _buildSectionTitle(context, 'Additional Information'),
              _buildTextField('Notes / Labels', _notesController, Icons.notes, null, TextInputType.multiline, 3),

              const SizedBox(height: 32),

              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(widget.isNewScan ? 'Verify & Save Card' : 'Update Details'),
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
              fontFamily: 'Outfit',
            ),
          ),
          const Divider(thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, [
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
