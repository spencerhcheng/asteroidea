import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'widgets/friends_list.dart';
import 'widgets/add_friend_modal.dart';
import 'services/friend_service.dart';
import 'services/photo_service.dart';
import 'share_code.dart';
import 'login.dart';

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 10 digits
    if (digitsOnly.length > 10) {
      return oldValue;
    }
    
    String formatted;
    if (digitsOnly.length <= 3) {
      formatted = digitsOnly;
    } else if (digitsOnly.length <= 6) {
      formatted = '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3)}';
    } else {
      formatted = '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }
    
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _refreshKey = 0;
  
  @override
  void dispose() {
    super.dispose();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.green,
      ),
    );
  }

  Future<void> _updateProfilePhoto(File? newPhoto) async {
    await PhotoService.updateProfilePhoto(
      newPhoto,
      _showSnackBar,
      () {
        if (mounted) {
          setState(() => _refreshKey++);
        }
      },
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              spreadRadius: 0,
              offset: Offset(0, -8),
            ),
          ],
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
            const SizedBox(height: 24),
            const Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.purple[400]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1000,
                    maxHeight: 1000,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    await _updateProfilePhoto(File(picked.path));
                  }
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[400]!, Colors.pink[400]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1000,
                    maxHeight: 1000,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    await _updateProfilePhoto(File(picked.path));
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequest(Map<String, dynamic> request) async {
    await FriendService.acceptFriendRequest(request, _showSnackBar);
    if (mounted) {
      setState(() => _refreshKey++);
    }
  }
  
  Future<void> _declineFriendRequest(Map<String, dynamic> request) async {
    await FriendService.declineFriendRequest(request, _showSnackBar);
    if (mounted) {
      setState(() => _refreshKey++);
    }
  }

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    await FriendService.removeFriend(friend, _showSnackBar);
    if (mounted) {
      setState(() => _refreshKey++);
    }
  }
  
  void _showAddFriendModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddFriendModal(),
    );
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
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
        final fullName = '$firstName $lastName'.trim();
        final location = (data?['usingLocation'] ?? false)
            ? 'Current Location'
            : (data?['zipCode'] ?? '');
        final String? photoUrl = data?['photoUrl'];
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShadButton.outline(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ShareCodePage(),
                      ),
                    );
                  },
                  child: const Icon(Icons.share, size: 18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ShadButton(
                  onPressed: () async {
                    final result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const EditProfileSheet(),
                    );
                    
                    if (result == true) {
                      setState(() {
                        _refreshKey++;
                      });
                    }
                  },
                  child: const Icon(Icons.edit, size: 18),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _refreshKey++;
              });
              // Small delay to show the refresh indicator
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
              children: [
                // Profile Header Card
                ShadCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Profile Photo
                      Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      width: 92,
                                      height: 92,
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.blue[400]!, Colors.purple[400]!],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: () => _showPhotoOptions(),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[600]!, Colors.purple[600]!],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Name
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Location
                      ShadBadge(
                        backgroundColor: Colors.grey[100],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              location.isNotEmpty ? location : 'Location not set',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Events Attended section within same card
                      Divider(color: Colors.grey[200]),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Events Attended',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.purple[600]!],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${data?['eventsAttended'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                
                // Friends Card
                ShadCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Friends',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          ShadButton(
                            onPressed: () => _showAddFriendModal(),
                            backgroundColor: Colors.blue[600],
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Add Friend',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FriendsList(
                        userData: data,
                        onAcceptRequest: _acceptFriendRequest,
                        onDeclineRequest: _declineFriendRequest,
                        onRemoveFriend: _removeFriend,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

// Keep the existing EditProfileSheet and other classes here for now
// They will be extracted in the next step
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

// TODO: Extract this to a separate file
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  String _selectedActivity = 'run'; // Single activity selection
  bool _isLoading = false;
  String _selectedGender = 'prefer not to say';
  String _selectedUnits = 'imperial';
  bool _phoneVerified = false;
  String _originalPhoneNumber = '';
  
  final List<Map<String, dynamic>> _availableActivities = [
    {'value': 'run', 'label': 'Running', 'icon': Icons.directions_run},
    {'value': 'ride', 'label': 'Cycling', 'icon': Icons.directions_bike},
  ];
  final List<String> _genderOptions = ['male', 'female', 'prefer not to say'];
  final List<String> _unitOptions = ['imperial', 'metric'];

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _originalPhoneNumber = data['phoneNumber'] ?? '';
          _zipCodeController.text = data['zipCode'] ?? '';
          final activities = List<String>.from(data['activities'] ?? ['run']);
          _selectedActivity = activities.isNotEmpty ? activities.first : 'run';
          _selectedGender = (data['gender'] ?? 'prefer not to say').toString().toLowerCase();
          _selectedUnits = (data['units'] ?? 'imperial').toString().toLowerCase();
          _phoneVerified = data['phoneVerified'] ?? false;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty) {
      _showSnackBar('First name is required', backgroundColor: Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
        'activities': [_selectedActivity],
        'gender': _selectedGender,
        'units': _selectedUnits,
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to trigger refresh
      }
    } catch (e) {
      _showSnackBar('Failed to update profile', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.green,
      ),
    );
  }

  bool _isPhoneNumberValid() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return phone.length == 10;
  }

  bool _isPhoneNumberChanged() {
    return _phoneController.text.trim() != _originalPhoneNumber;
  }

  bool _shouldEnableVerifyButton() {
    return _isPhoneNumberValid() && _isPhoneNumberChanged() && !_phoneVerified;
  }

  Future<void> _verifyPhoneNumber() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      _showSnackBar('Please enter a phone number', backgroundColor: Colors.red);
      return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+1$phoneNumber',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          setState(() {
            _phoneVerified = true;
          });
          _showSnackBar('Phone number verified successfully!');
        },
        verificationFailed: (FirebaseAuthException e) {
          _showSnackBar('Phone verification failed: ${e.message}', backgroundColor: Colors.red);
        },
        codeSent: (String verificationId, int? resendToken) {
          // Show OTP verification dialog
          _showOTPDialog(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
      );
    } catch (e) {
      _showSnackBar('Failed to verify phone number', backgroundColor: Colors.red);
    }
  }

  void _showOTPDialog(String verificationId) {
    final otpController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We sent a verification code to ${_phoneController.text}'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: otpController.text.trim(),
                );
                
                await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
                
                setState(() {
                  _phoneVerified = true;
                });
                
                Navigator.pop(context);
                _showSnackBar('Phone number verified successfully!');
              } catch (e) {
                _showSnackBar('Invalid verification code', backgroundColor: Colors.red);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Delete user data from Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
          
          // Delete user account
          await user.delete();
          
          // Navigate to login screen
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        _showSnackBar('Failed to delete account', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to sign out', backgroundColor: Colors.red);
    }
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) => setState(() {}), // Trigger rebuild for validation
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              // Country Code
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  '+1',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              
              // Divider
              Container(
                height: 24,
                width: 1,
                color: Colors.grey[300],
              ),
              
              // Phone Input
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  inputFormatters: [_PhoneNumberFormatter()],
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}), // Trigger rebuild for validation
                  decoration: InputDecoration(
                    hintText: '(555) 123-4567',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: _shouldEnableVerifyButton() ? _verifyPhoneNumber : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _shouldEnableVerifyButton() 
                                ? Colors.blue[600] 
                                : Colors.grey[300],
                            foregroundColor: _shouldEnableVerifyButton() 
                                ? Colors.white 
                                : Colors.grey[500],
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _shouldEnableVerifyButton() ? 2 : 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_phoneVerified) ...[
                                const Icon(Icons.verified, size: 16),
                                const SizedBox(width: 4),
                                const Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ] else ...[
                                const Icon(Icons.security, size: 16),
                                const SizedBox(width: 4),
                                const Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_phoneVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Phone number verified',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActivitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Primary Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This will be used as the default when creating and viewing events',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _availableActivities.map((activity) {
            final isSelected = _selectedActivity == activity['value'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: activity == _availableActivities.last ? 0 : 12,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedActivity = activity['value'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[600] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          activity['icon'],
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activity['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            dropdownColor: Colors.white,
            items: options.map((option) {
              return DropdownMenuItem(
                value: option.toLowerCase(),
                child: Text(
                  option.split(' ').map((word) => 
                      word[0].toUpperCase() + word.substring(1)).join(' '),
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
              
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
                    _buildSectionTitle('Personal Information'),
                    
                    _buildInputField(
                      label: 'First Name',
                      controller: _firstNameController,
                      hint: 'Enter your first name',
                    ),
                    
                    _buildInputField(
                      label: 'Last Name',
                      controller: _lastNameController,
                      hint: 'Enter your last name',
                    ),
                    
                    _buildInputField(
                      label: 'Bio',
                      controller: _bioController,
                      hint: 'Tell us about yourself...',
                      maxLines: 3,
                    ),

                    _buildPhoneField(),

                    _buildInputField(
                      label: 'ZIP Code',
                      controller: _zipCodeController,
                      hint: 'Enter your ZIP code',
                      keyboardType: TextInputType.number,
                    ),
                    
                    // Preferences Section
                    _buildSectionTitle('Preferences'),
                    
                    _buildActivitySelector(),
                    
                    _buildDropdownField(
                      label: 'Gender',
                      value: _selectedGender,
                      options: _genderOptions,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedGender = value;
                          });
                        }
                      },
                    ),

                    _buildDropdownField(
                      label: 'Units',
                      value: _selectedUnits,
                      options: _unitOptions,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnits = value;
                          });
                        }
                      },
                    ),

                    // Account Section
                    _buildSectionTitle('Account Actions'),

                    // Sign Out Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),

                    // Delete Account Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 32),
                      child: OutlinedButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(Icons.delete_forever, size: 20),
                        label: const Text('Delete Account'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              
            // Save Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: Colors.blue.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TODO: Extract to widgets/phone_otp_verification.dart
class PhoneOTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final Function(bool) onVerificationComplete;
  final VoidCallback onCancel;

  const PhoneOTPVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.onVerificationComplete,
    required this.onCancel,
  });

  @override
  State<PhoneOTPVerificationPage> createState() => _PhoneOTPVerificationPageState();
}

class _PhoneOTPVerificationPageState extends State<PhoneOTPVerificationPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('OTP Verification - TODO: Extract to separate widget'),
    );
  }
}