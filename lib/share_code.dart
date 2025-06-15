import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareCodePage extends StatefulWidget {
  const ShareCodePage({super.key});

  @override
  State<ShareCodePage> createState() => _ShareCodePageState();
}

class _ShareCodePageState extends State<ShareCodePage> {
  String _selectedTab = 'qr';
  String? _profileLink;
  bool _isLoading = true;
  // MobileScannerController? _scannerController;

  void _showSnackBar(String message, {Color? backgroundColor, Widget? content}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content ?? Text(message),
        backgroundColor: backgroundColor ?? Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _generateProfileLink();
  }

  @override
  void dispose() {
    // _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _generateProfileLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Generate a unique profile link using user ID
      final link = 'https://asteroidea.app/profile/${user.uid}';
      setState(() {
        _profileLink = link;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareProfileLink() async {
    if (_profileLink != null) {
      // Try to use native sharing if available, fall back to clipboard copy
      try {
        // Note: For actual sharing, you'd use a package like share_plus
        // For now, we'll copy to clipboard with better feedback
        await Clipboard.setData(ClipboardData(text: _profileLink!));
        if (!mounted) return;
        _showSnackBar(
          'Profile link copied to clipboard!',
          backgroundColor: Colors.green[600],
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Profile link copied to clipboard!'),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Failed to copy link', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _handleQRScan(String data) async {
    // Handle scanned QR code data
    if (data.contains('asteroidea.app/profile/')) {
      // Extract user ID from the link
      final userId = data.split('/').last;
      
      // Navigate to user profile or show user info
      if (!mounted) return;
      _showSnackBar('Scanned profile: $userId');
      
      // You can add navigation to view the scanned user's profile here
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (context) => ViewUserProfilePage(userId: userId),
      // ));
    } else {
      if (!mounted) return;
      _showSnackBar('Invalid QR code', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Share Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Tab Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'qr',
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 18,
                          color: _selectedTab == 'qr'
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'QR Code',
                          style: TextStyle(
                            color: _selectedTab == 'qr'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ButtonSegment<String>(
                    value: 'scan',
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: _selectedTab == 'scan'
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scan Code',
                          style: TextStyle(
                            color: _selectedTab == 'scan'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedTab = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return Colors.grey[200]!;
                  }),
                ),
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: _selectedTab == 'qr' ? _buildQRCodeTab() : _buildScanCodeTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_profileLink == null) {
      return const Center(
        child: Text(
          'Unable to generate profile link',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Share your profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Others can scan this QR code to view your profile',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: _profileLink!,
                version: QrVersions.auto,
                size: 220.0,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Text(
                  _profileLink!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.outline(
                    onPressed: _shareProfileLink,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Share Link',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScanCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Point your camera at a QR code to view someone\'s profile',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Text(
                      'QR Scanner temporarily disabled',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Make sure the QR code is clearly visible in the camera frame',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
