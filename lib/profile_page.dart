import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _updateProfilePhoto(File? newPhoto) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? photoUrl;
      if (newPhoto != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user.uid}.jpg');

        await ref.putFile(newPhoto);
        photoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': photoUrl, 'photoSkipped': photoUrl == null},
      );
    } catch (e) {
      print('Error updating profile photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('Not signed in.', style: TextStyle(color: Colors.black)),
        ),
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data?.data();
        final firstName = data?['firstName'] ?? 'User';
        final lastName = data?['lastName'] ?? '';
        final bio = data?['bio'] ?? '';
        final fullName = (firstName + ' ' + lastName).trim();
        final location = (data?['usingLocation'] ?? false)
            ? 'Current Location'
            : (data?['zipCode'] ?? '');
        final photoSkipped = data?['photoSkipped'] ?? true;
        final String? photoUrl = data?['photoUrl'];
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32.0, 48.0, 32.0, 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.grey[400],
                              backgroundImage:
                                  (photoUrl != null && photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl) as ImageProvider
                                  : null,
                              child: (photoUrl == null || photoUrl.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      size: 54,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: -10,
                              right: -10,
                              child: PopupMenuButton<String>(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                onSelected: (value) async {
                                  if (value == 'camera') {
                                    final picked = await ImagePicker()
                                        .pickImage(
                                          source: ImageSource.camera,
                                          maxWidth: 1000,
                                          maxHeight: 1000,
                                          imageQuality: 85,
                                        );
                                    if (picked != null) {
                                      await _updateProfilePhoto(
                                        File(picked.path),
                                      );
                                    }
                                  } else if (value == 'gallery') {
                                    final picked = await ImagePicker()
                                        .pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 1000,
                                          maxHeight: 1000,
                                          imageQuality: 85,
                                        );
                                    if (picked != null) {
                                      await _updateProfilePhoto(
                                        File(picked.path),
                                      );
                                    }
                                  } else if (value == 'remove') {
                                    await _updateProfilePhoto(null);
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
                                  if (photoUrl != null)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove Photo'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 4.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              bio,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${data?['eventsAttended'] ?? 0} Events',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Ready for your next adventure!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.black,
                      size: 28,
                    ),
                    tooltip: 'Edit Profile',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const EditProfileSheet(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // ... (move edit modal code here, using light mode colors)
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Center(
        child: Text(
          'Edit Profile Form Here',
          style: TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  String _firstName = '';
  String _lastName = '';
  String _bio = '';
  String _zipCode = '';
  String _gender = '';
  final Set<String> _activities = {'run', 'ride'}; // Default to both
  String _units = 'Imperial';
  bool _isLoading = true;
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _bioController.text = _bio;
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _firstName = data['firstName'] ?? '';
          _lastName = data['lastName'] ?? '';
          _bio = data['bio'] ?? '';
          _zipCode = data['zipCode'] ?? '';
          _gender = data['gender'] ?? '';
          _activities.clear();
          _activities.addAll(
            List<String>.from(data['activities'] ?? ['run', 'ride']),
          );
          _units = data['units'] ?? 'Imperial';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one activity')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'firstName': _firstName,
          'lastName': _lastName,
          'bio': _bio,
          'zipCode': _zipCode,
          'gender': _gender,
          'activities': _activities.toList(),
          'units': _units,
          'eventsAttended': FieldValue.increment(0), // Ensures field exists
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator()
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter your first name'
                            : null,
                        onChanged: (v) => setState(() => _firstName = v.trim()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter your last name'
                            : null,
                        onChanged: (v) => setState(() => _lastName = v.trim()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bioController,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          border: OutlineInputBorder(),
                          hintText: 'Tell us about yourself...',
                          counterText: '',
                        ),
                        maxLines: 3,
                        onChanged: (v) => setState(() => _bio = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _zipCode,
                        decoration: const InputDecoration(
                          labelText: 'ZIP Code *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        validator: (v) => v == null || v.length != 5
                            ? 'Enter a valid ZIP code'
                            : null,
                        onChanged: (v) => setState(() => _zipCode = v),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Activity Preferences *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Run'),
                            selected: _activities.contains('run'),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _activities.add('run');
                                } else if (_activities.length > 1) {
                                  _activities.remove('run');
                                }
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Ride'),
                            selected: _activities.contains('ride'),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _activities.add('ride');
                                } else if (_activities.length > 1) {
                                  _activities.remove('ride');
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (_activities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Select at least one activity',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _gender.isNotEmpty ? _gender : null,
                        decoration: const InputDecoration(
                          labelText: 'Gender *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'Non-binary',
                            child: Text('Non-binary'),
                          ),
                          DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? ''),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please select your gender'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _units,
                        decoration: const InputDecoration(
                          labelText: 'Units *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Imperial',
                            child: Text('Imperial (mi)'),
                          ),
                          DropdownMenuItem(
                            value: 'Metric',
                            child: Text('Metric (km)'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _units = v ?? 'Imperial'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
