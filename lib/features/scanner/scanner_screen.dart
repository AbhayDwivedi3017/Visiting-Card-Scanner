import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/ocr_service.dart';
import '../../data/models/card_data.dart';
import 'edit_card_screen.dart';

enum ScannerMode { scanToExcel, createDigitalCard }

class ScannerScreen extends StatefulWidget {
  final ScannerMode mode;

  const ScannerScreen({Key? key, required this.mode}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  bool _isProcessing = false;
  String? _selectedImagePath;
  
  // Animation for the scanner laser line
  late AnimationController _animationController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndPickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showPermissionDeniedDialog('Camera');
          return;
        }
      } else {
        // Storage permissions for gallery
        if (Platform.isAndroid) {
          final status = await Permission.photos.request();
          if (!status.isGranted && status.isPermanentlyDenied) {
            _showPermissionDeniedDialog('Photos/Gallery');
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _isProcessing = true;
        });

        // Start scanning animation
        _animationController.repeat(reverse: true);

        // Perform OCR
        final parsedCard = await _ocrService.scanCardImage(image.path);

        _animationController.stop();

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          // Navigate to Edit Details form
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EditCardScreen(
                card: parsedCard,
                isNewScan: true,
                startDigitalCardFlow: widget.mode == ScannerMode.createDigitalCard,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _animationController.stop();
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Failed to capture card: $e');
    }
  }

  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text('This application needs $permissionName access to scan visiting cards. Please enable it in system settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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
    final title = widget.mode == ScannerMode.scanToExcel 
        ? 'Scan & Save to Excel' 
        : 'Generate Digital Card';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _isProcessing 
              ? _buildProcessingUI() 
              : _buildCaptureSelectionUI(context),
        ),
      ),
    );
  }

  Widget _buildCaptureSelectionUI(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Illustration / Icon
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_enhance,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Capture Visiting Card',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Place the card inside the frame, ensure clear lighting, and align text horizontally for best OCR parsing accuracy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Buttons
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: const Text('Capture Card (Camera)'),
                onPressed: () => _requestPermissionAndPickImage(ImageSource.camera),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Select from Gallery'),
                onPressed: () => _requestPermissionAndPickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simulated card crop box with laser line
          Container(
            width: 300,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2.5,
              ),
            ),
            child: Stack(
              children: [
                // Render image thumbnail inside the container
                if (_selectedImagePath != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(
                        File(_selectedImagePath!),
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.4),
                      ),
                    ),
                  ),
                // Laser animation line
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _laserAnimation.value * 170, // Height bounds
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
                // Scanner corner borders
                const Center(
                  child: Icon(Icons.qr_code_scanner, size: 48, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Analyzing details...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Performing offline OCR and parsing metadata',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
