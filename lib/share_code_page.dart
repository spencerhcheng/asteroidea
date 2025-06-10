import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ShareProfilePage extends StatelessWidget {
  final String profileUrl;
  final String fullName;
  const ShareProfilePage({
    super.key,
    required this.profileUrl,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          fullName,
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          ShadTabs<String>(
            value: 'mycode',
            tabBarConstraints: const BoxConstraints(maxWidth: 400),
            contentConstraints: const BoxConstraints(maxWidth: 400),
            tabs: [
              ShadTab(
                value: 'mycode',
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    QrImageView(
                      data: profileUrl,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          SelectableText(
                            profileUrl,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ShadButton(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: profileUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile URL copied!'),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.copy, size: 18),
                                const SizedBox(width: 6),
                                const Text('Copy Link'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                child: const Text(
                  'My Code',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ShadTab(
                value: 'scan',
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    ShadButton(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      onPressed: () async {
                        // TODO: Implement QR code scanning
                        final picker = ImagePicker();
                        await picker.pickImage(source: ImageSource.camera);
                      },
                      child: const Text('Scan QR Code (Camera)'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Point your camera at a friend's QR code to connect",
                      style: TextStyle(color: Colors.black),
                    ),
                  ],
                ),
                child: const Text(
                  'Scan Code',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
