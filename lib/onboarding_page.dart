import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'main_navigation.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late PageController _pageController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  // Step 1 fields
  String _firstName = '';
  String _lastName = '';
  String _bio = '';
  String _gender = '';
  File? _profilePhoto;
  bool _photoSkipped = false;
  bool _isUploading = false;

  // Step 2 fields
  final Set<String> _selectedActivities = {};
  String _units = 'Imperial';

  // Step 3 fields
  String _zipCode = '';
  bool _usingLocation = false;
  bool _locationLoading = false;
  String? _locationError;

  // General state
  bool _isLoading = false;

  // Form controllers to preserve data
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _updateProgress();

    // Initialize controllers with current values
    _firstNameController.text = _firstName;
    _lastNameController.text = _lastName;
    _zipCodeController.text = _zipCode;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    final progress = (_currentStep + 1) / 4;
    _progressController.animateTo(progress);
  }

  Future<void> _nextStep() async {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _updateProgress();
      // Only call nextPage if PageController is attached
      if (_pageController.hasClients) {
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _previousStep() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _updateProgress();
      // Only call previousPage if PageController is attached
      if (_pageController.hasClients) {
        await _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      final dir = Directory.systemTemp;
      final fileName = path.basename(imageFile.path);
      final targetPath = '${dir.path}/compressed_$fileName';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 400,
        minHeight: 400,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadProfilePhoto() async {
    if (_profilePhoto == null) return null;

    try {
      setState(() => _isUploading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Compress the image before uploading
      final compressedPhoto = await _compressImage(_profilePhoto!);
      if (compressedPhoto == null) {
        setState(() => _isUploading = false);
        return null;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      final uploadTask = await ref.putFile(compressedPhoto);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Clean up temporary compressed file
      try {
        await compressedPhoto.delete();
      } catch (e) {
        // Failed to delete temporary file - not critical
      }

      setState(() => _isUploading = false);
      return downloadUrl;
    } catch (e) {
      setState(() => _isUploading = false);
      return null;
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied.';
          _locationLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      // Reverse geocode to ZIP (for demo, just set using lat/lon)
      // In production, use a proper reverse geocoding API
      // For now, just set usingLocation true and clear zip
      setState(() {
        _usingLocation = true;
        _zipCode = '';
        _locationLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location.';
        _locationLoading = false;
      });
    }
  }

  // Modern segmented progress indicator with flowing gradient
  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button or step text
              GestureDetector(
                onTap: _currentStep > 0 ? _previousStep : () {
                  // Navigate back to login page on first step
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentStep > 0 ? 'Back' : 'Back to Login',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${((_currentStep + 1) / 4 * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented progress bar with flowing gradient
          Row(
            children: List.generate(4, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.grey[200],
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isCompleted || isCurrent ? Colors.blue[600] : Colors.grey[200],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Step 1: Name & Photo
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Form(
        key: _formKeys[0],
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Header with emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[100]!, Colors.purple[100]!],
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👋', style: TextStyle(fontSize: 30)),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Let\'s get to know you!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            Text(
              'Tell us a bit about yourself',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Profile Photo Section
            GestureDetector(
              onTap: () => _showPhotoOptions(),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _profilePhoto != null
                        ? Colors.green[400]!
                        : Colors.grey[300]!,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                        image: _profilePhoto != null
                            ? DecorationImage(
                                image: FileImage(_profilePhoto!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profilePhoto == null
                          ? Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tap to add a photo',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            const SizedBox(height: 20),

            // Name Fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => setState(() => _firstName = v.trim()),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => setState(() => _lastName = v.trim()),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Gender Dropdown
            DropdownButtonFormField<String>(
              value: _gender.isNotEmpty ? _gender : null,
              decoration: InputDecoration(
                labelText: 'Gender',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Select your gender',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(
                  value: 'Non-binary',
                  child: Text('Non-binary'),
                ),
                DropdownMenuItem(
                  value: 'Prefer not to say',
                  child: Text('Prefer not to say'),
                ),
              ],
              onChanged: (value) => setState(() => _gender = value ?? ''),
              validator: (v) => v == null || v.isEmpty ? 'Please select' : null,
            ),

            // Add space to push button away from content
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKeys[0].currentState?.validate() ?? false) {
                    _nextStep();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Photo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1000,
                  maxHeight: 1000,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    _profilePhoto = File(picked.path);
                    _photoSkipped = false;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1000,
                  maxHeight: 1000,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    _profilePhoto = File(picked.path);
                    _photoSkipped = false;
                  });
                }
              },
            ),
            if (_profilePhoto != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profilePhoto = null;
                    _photoSkipped = true;
                  });
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Step 2: Activities & Preferences
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Header
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[100]!, Colors.red[100]!],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🏃‍♀️', style: TextStyle(fontSize: 35)),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'What gets you moving?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Text(
            'Select the activities you enjoy.',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Activity Cards - made more compact
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildActivityCard('Running', '🏃‍♂️', 'run', Colors.blue),
              _buildActivityCard('Cycling', '🚴‍♀️', 'ride', Colors.green),
            ],
          ),

          const SizedBox(height: 24),

          // Units Toggle - Centered and Modern
          Column(
            children: [
              const Text(
                'Preferred Units',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Metric',
                      style: TextStyle(
                        fontSize: 15,
                        color: _units == 'Metric'
                            ? Colors.blue[600]
                            : Colors.grey[600],
                        fontWeight: _units == 'Metric'
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Switch(
                      value: _units == 'Imperial',
                      onChanged: (value) {
                        setState(() {
                          _units = value ? 'Imperial' : 'Metric';
                        });
                      },
                      activeColor: Colors.blue[600],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Imperial',
                      style: TextStyle(
                        fontSize: 15,
                        color: _units == 'Imperial'
                            ? Colors.blue[600]
                            : Colors.grey[600],
                        fontWeight: _units == 'Imperial'
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedActivities.isNotEmpty
                  ? () => _nextStep()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedActivities.isNotEmpty
                    ? Colors.black
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_selectedActivities.isEmpty)
            Text(
              'Please select at least one activity',
              style: TextStyle(color: Colors.red[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    String title,
    String emoji,
    String value,
    Color color,
  ) {
    final isSelected = _selectedActivities.contains(value);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedActivities.remove(value);
          } else {
            _selectedActivities.add(value);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 15 : 10,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Header with emoji
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[100]!, Colors.blue[100]!],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📍', style: TextStyle(fontSize: 30)),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Where are you?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Text(
            'Help us find events near you',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          Form(
            key: _formKeys[2],
            child: Column(
              children: [
                // ZIP Code Input
                TextFormField(
                  controller: _zipCodeController,
                  enabled: !_usingLocation,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    labelText: 'ZIP Code',
                    hintText: '12345',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: Colors.blue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: _usingLocation
                        ? Colors.grey[100]
                        : Colors.grey[50],
                    enabled: !_usingLocation,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _zipCode = v;
                    _usingLocation = false;
                  }),
                  validator: (v) {
                    if (!_usingLocation && (v == null || v.length != 5)) {
                      return 'Enter a valid 5-digit ZIP code';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // OR Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),

                const SizedBox(height: 16),

                // Use Location Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _locationLoading ? null : _getLocation,
                    icon: _locationLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _usingLocation ? Colors.white : Colors.blue,
                              ),
                            ),
                          )
                        : Icon(
                            _usingLocation ? Icons.check : Icons.my_location,
                            color: _usingLocation ? Colors.white : Colors.blue,
                          ),
                    label: Text(
                      _usingLocation
                          ? 'Location Enabled'
                          : 'Use My Current Location',
                      style: TextStyle(
                        color: _usingLocation ? Colors.white : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _usingLocation
                          ? Colors.green[400]
                          : Colors.white,
                      side: BorderSide(
                        color: _usingLocation
                            ? Colors.green[400]!
                            : Colors.blue,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationError!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Add space to push button away from content
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_usingLocation || _zipCode.length == 5)
                  ? () => _nextStep()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: (_usingLocation || _zipCode.length == 5)
                    ? Colors.black
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (!_usingLocation && _zipCode.length != 5)
            Text(
              'Please enter a ZIP code or enable location',
              style: TextStyle(color: Colors.red[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Save onboarding progress locally
  Future<void> _saveLocalProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', _firstName);
    await prefs.setString('lastName', _lastName);
    await prefs.setString('gender', _gender);
    await prefs.setBool('photoSkipped', _photoSkipped);
    await prefs.setStringList('activities', _selectedActivities.toList());
    await prefs.setString('units', _units);
    await prefs.setString('zipCode', _zipCode);
    await prefs.setBool('usingLocation', _usingLocation);
    await prefs.setBool('onboarding_complete', true);
  }

  // Save onboarding progress to Firestore
  Future<void> _saveFirestoreProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = {
      'firstName': _firstName,
      'lastName': _lastName,
      'gender': _gender,
      'photoSkipped': _photoSkipped,
      'activities': _selectedActivities.toList(),
      'zipCode': _zipCode,
      'usingLocation': _usingLocation,
      'onboardingComplete': true,
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  // Save onboarding progress to Firestore with photo URL
  Future<void> _saveFirestoreProgressWithPhoto(String? photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = {
      'firstName': _firstName,
      'lastName': _lastName,
      'bio': '',
      'gender': _gender,
      'photoSkipped': _photoSkipped,
      'activities': _selectedActivities.toList(),
      'units': _units,
      'zipCode': _zipCode,
      'usingLocation': _usingLocation,
      'onboardingComplete': true,
      'phoneNumber': user.phoneNumber, // Preserve phone number from Firebase Auth
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  // Step 4: Confirmation/Finish
  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Header with emoji
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[100]!, Colors.yellow[100]!],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 35)),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'You\'re all set!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Text(
            'Ready to find your next adventure',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Profile Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Profile Photo & Name
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                        image: _profilePhoto != null
                            ? DecorationImage(
                                image: FileImage(_profilePhoto!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profilePhoto == null
                          ? Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_firstName $_lastName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_gender.isNotEmpty)
                            Text(
                              _gender,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Divider
                Divider(color: Colors.grey[200]),

                const SizedBox(height: 16),

                // Activities
                Row(
                  children: [
                    Icon(
                      Icons.directions_run,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activities',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedActivities
                                .map((a) => a[0].toUpperCase() + a.substring(1))
                                .join(', '),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _usingLocation
                                ? 'Current location'
                                : 'ZIP: $_zipCode',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Units
                Row(
                  children: [
                    Icon(Icons.straighten, color: Colors.purple[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Units',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _units,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Finish Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);

                      // Upload photo if selected
                      String? photoUrl;
                      if (_profilePhoto != null && !_photoSkipped) {
                        photoUrl = await _uploadProfilePhoto();
                      }

                      // Save progress with photo URL
                      await _saveLocalProgress();
                      await _saveFirestoreProgressWithPhoto(photoUrl);

                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/main');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Start Exploring',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentStep == 0
                    ? _buildStep1()
                    : _currentStep == 1
                    ? _buildStep2()
                    : _currentStep == 2
                    ? _buildStep3()
                    : _buildStep4(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
