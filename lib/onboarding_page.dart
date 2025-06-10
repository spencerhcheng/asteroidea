import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1 fields
  String _firstName = '';
  String _lastName = '';
  String _gender = '';
  File? _profilePhoto;
  bool _photoSkipped = false;

  // For image picker
  final ImagePicker _picker = ImagePicker();

  // Step 2 fields
  final Set<String> _selectedActivities = {};

  // Step 3 fields
  String _zipCode = '';
  bool _usingLocation = false;
  bool _locationLoading = false;
  String? _locationError;

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

  // Progress indicator
  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: ShadProgress(
        value: (_currentStep + 1) / 4 * 100,
        backgroundColor: Colors.grey[200],
        color: Colors.lightBlue,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Step 1: Name & Photo
  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Let\'s get to know you',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: _profilePhoto != null
                      ? FileImage(_profilePhoto!)
                      : null,
                  child: _profilePhoto == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: PopupMenuButton<String>(
                    icon: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.camera_alt, size: 20),
                    ),
                    onSelected: (value) async {
                      if (value == 'camera') {
                        final picked = await _picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (picked != null) {
                          setState(() {
                            _profilePhoto = File(picked.path);
                            _photoSkipped = false;
                          });
                        }
                      } else if (value == 'gallery') {
                        final picked = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (picked != null) {
                          setState(() {
                            _profilePhoto = File(picked.path);
                            _photoSkipped = false;
                          });
                        }
                      } else if (value == 'skip') {
                        setState(() {
                          _profilePhoto = null;
                          _photoSkipped = true;
                        });
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'camera',
                        child: Text('Take Photo'),
                      ),
                      const PopupMenuItem(
                        value: 'gallery',
                        child: Text('Choose from Gallery'),
                      ),
                      const PopupMenuItem(
                        value: 'skip',
                        child: Text('Skip (use default avatar)'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (v) => setState(() => _firstName = v.trim()),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Please enter your first name'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (v) => setState(() => _lastName = v.trim()),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Please enter your last name'
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _gender.isNotEmpty ? _gender : null,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
              DropdownMenuItem(
                value: 'Prefer not to say',
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (value) => setState(() => _gender = value ?? ''),
            validator: (v) =>
                v == null || v.isEmpty ? 'Please select your gender' : null,
          ),
          const SizedBox(height: 24),
          ShadButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                // TODO: Save step 1 progress to Firestore or locally
                setState(() => _currentStep = 1);
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final activities = [
      {'label': 'Running', 'icon': Icons.directions_run, 'value': 'running'},
      {'label': 'Cycling', 'icon': Icons.directions_bike, 'value': 'cycling'},
    ];
    final bool showValidation = _selectedActivities.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What are you interested in?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: activities.map((activity) {
            final isSelected = _selectedActivities.contains(activity['value']);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedActivities.remove(activity['value']);
                      } else {
                        _selectedActivities.add(activity['value'] as String);
                      }
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.15)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    activity['icon'] as IconData,
                                    size: 48,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.black54,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: -16,
                                      right: -16,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                activity['label'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        ShadButton(
          onPressed: _selectedActivities.isNotEmpty
              ? () {
                  setState(() => _currentStep = 2);
                }
              : null,
          child: const Text('Next'),
        ),
        Container(
          height: 32,
          alignment: Alignment.center,
          child: _selectedActivities.isEmpty
              ? const Text(
                  'Please select at least one activity.',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Where do you want to discover or host events?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'We\'ll use this to show nearby events.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                enabled: !_usingLocation,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: const InputDecoration(
                  labelText: 'ZIP Code',
                  border: OutlineInputBorder(),
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
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                ShadButton(
                  onPressed: _locationLoading
                      ? null
                      : () async {
                          await _getLocation();
                        },
                  child: _locationLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 4),
                const Text('Use my location', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _locationError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 32),
        ShadButton(
          onPressed: (_usingLocation || _zipCode.length == 5)
              ? () {
                  // TODO: Save step 3 progress to Firestore or locally
                  setState(() => _currentStep = 3);
                }
              : null,
          child: const Text('Next'),
        ),
      ],
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

  // Step 4: Confirmation/Finish
  Widget _buildStep4() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Playful vector illustration
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: SvgPicture.asset(
            'assets/outdoor_trail.svg',
            height: 140,
            fit: BoxFit.contain,
            width: double.infinity,
            alignment: Alignment.center,
            placeholderBuilder: (context) => const SizedBox(height: 140),
            // fallback if SVG fails to load
            // ignore: deprecated_member_use
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.landscape, size: 80, color: Colors.grey),
          ),
        ),
        const Text(
          'All set!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: _profilePhoto != null
                ? FileImage(_profilePhoto!)
                : null,
            child: _profilePhoto == null
                ? const Icon(Icons.person, size: 32)
                : null,
          ),
          title: Text('$_firstName $_lastName'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedActivities
                    .map((a) => a[0].toUpperCase() + a.substring(1))
                    .join(', '),
              ),
              if (_gender.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    'Gender: $_gender',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: Text(
            _usingLocation ? 'Using current location' : 'ZIP: $_zipCode',
          ),
        ),
        const SizedBox(height: 32),
        ShadButton(
          onPressed: () async {
            await _saveLocalProgress();
            await _saveFirestoreProgress();
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/main');
          },
          child: const Text('Finish'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(50.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
