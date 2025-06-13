import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_page.dart';
import 'main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _otpFormKey = GlobalKey<FormState>();
  String? _verificationId;
  bool _isLoading = false;
  String? _error;
  bool _otpSent = false;
  bool _isPhoneValid = false;
  String _otpValue = '';
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final value = _phoneController.text.trim();
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    final phonePattern = RegExp(r'^[2-9][0-9]{9}$');
    final isValid = phonePattern.hasMatch(digitsOnly);
    if (isValid != _isPhoneValid) {
      setState(() {
        _isPhoneValid = isValid;
      });
    }
    // Also update the button state if the field becomes invalid
    setState(() {});
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    final phonePattern = RegExp(r'^[2-9][0-9]{9}$');
    if (!phonePattern.hasMatch(digitsOnly)) {
      return 'Enter a valid 10-digit US phone number';
    }
    return null;
  }

  String? _validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the OTP';
    }
    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }
    return null;
  }

  Future<void> _verifyPhone() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final digitsOnly = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+1$digitsOnly',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _error = e.message;
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithOTP() async {
    if (!_otpFormKey.currentState!.validate()) return;
    if (_verificationId == null) {
      setState(() {
        _error = null;
        _otpError =
            'We hit a snag. Try again in a bit, or ping us if you need help.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _otpError = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      setState(() {
        _isLoading = false;
        _otpError = null;
      });
      final user = userCredential.user;
      final isNewUser = userCredential.additionalUserInfo?.isNewUser == true;
      if (user != null && isNewUser) {
        // Save user credentials to Firestore with standardized schema
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phoneNumber': user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'onboardingComplete': false,
          'eventsAttended': 0,
          'friends': [],
          'friendRequests': [],
        });
      }
      // Check onboarding status
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final onboardingComplete =
            userDoc.data()?['onboardingComplete'] == true;
        if (isNewUser || !onboardingComplete) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingPage()),
          );
        } else {
          // Navigate to main app
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }
      }
    } catch (e) {
      String? errorMsg;
      if (e is FirebaseAuthException && e.code == 'invalid-verification-code') {
        errorMsg = 'Invalid OTP Code. Please try again.';
      } else {
        errorMsg =
            'We hit a snag. Try again in a bit, or ping us if you need help.';
      }
      setState(() {
        _otpError = errorMsg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 80),
                
                // App logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.purple[600]!],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Title
                Text(
                  _otpSent ? 'Enter Verification Code' : 'Join the Movement',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  _otpSent 
                      ? 'We sent a 6-digit code to +1 ${_phoneController.text}'
                      : 'Connect with runners and cyclists in your area',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                if (!_otpSent) ...[
                  // Phone Number Input
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isPhoneValid 
                                  ? Colors.blue[600]!
                                  : Colors.grey[300]!,
                              width: _isPhoneValid ? 2 : 1,
                            ),
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
                                  keyboardType: TextInputType.phone,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  decoration: InputDecoration(
                                    hintText: '(555) 123-4567',
                                    hintStyle: TextStyle(color: Colors.grey[500]),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    counterText: '',
                                  ),
                                  inputFormatters: [
                                    _PhoneNumberFormatter(),
                                  ],
                                  validator: _validatePhone,
                                ),
                              ),
                              
                              // Status indicator
                              if (_isPhoneValid)
                                Container(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.green[500],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Disclaimer
                        Text(
                          'By continuing, you agree to receive SMS messages. Standard rates may apply.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_isPhoneValid ? null : _verifyPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPhoneValid 
                            ? Colors.black
                            : Colors.grey[400],
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
                              'Send Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  if (_error != null && !_otpSent)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'We hit a snag. Try again in a bit, or ping us if you need help.',
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
                    
                ] else ...[
                  // OTP Input
                  Form(
                    key: _otpFormKey,
                    child: Column(
                      children: [
                        ShadInputOTPFormField(
                          id: 'otp',
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          validator: _validateOTP,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            _otpController.text = value;
                            setState(() {
                              _otpValue = value;
                            });
                          },
                          children: const [
                            ShadInputOTPGroup(
                              children: [
                                ShadInputOTPSlot(),
                                ShadInputOTPSlot(),
                                ShadInputOTPSlot(),
                                ShadInputOTPSlot(),
                                ShadInputOTPSlot(),
                                ShadInputOTPSlot(),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Resend Code
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _otpSent = false;
                              _otpError = null;
                              _otpValue = '';
                              _otpController.clear();
                            });
                          },
                          child: Text(
                            'Didn\'t receive a code? Resend',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || _otpValue.length != 6
                          ? null
                          : _signInWithOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _otpValue.length == 6 
                            ? Colors.black
                            : Colors.grey[400],
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
                              'Verify & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  if (_otpError != null && _otpSent)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _otpError!,
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
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
