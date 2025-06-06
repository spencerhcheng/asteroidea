import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shadcn_ui/src/components/form/fields/input.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_page.dart';
import 'landing_page.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final phonePattern = RegExp(r'^[2-9][0-9]{9}');
    final isValid = phonePattern.hasMatch(value);
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
    final phonePattern = RegExp(r'^[2-9][0-9]{9}');
    if (!phonePattern.hasMatch(value.trim())) {
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
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+1${_phoneController.text.trim()}',
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
        // Save user credentials to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phone': user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'onboardingComplete': false,
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
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LandingPage()),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Login or Sign Up',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // if (_error != null)
              //   ShadAlert.destructive(
              //     title: const Text('Error'),
              //     description: Text(_error!),
              //   ),
              if (!_otpSent) ...[
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 48,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '+1',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ShadInputFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: _validatePhone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                if (value.length > 10) {
                                  _phoneController.text = value.substring(
                                    0,
                                    10,
                                  );
                                  _phoneController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(offset: 10),
                                      );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          'Currently available in the US. By signing up, you agree to receive text messsages from us or event hosts.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: ShadButton(
                    onPressed: _isLoading || !_isPhoneValid
                        ? null
                        : _verifyPhone,
                    enabled: _isPhoneValid && !_isLoading,
                    child: _isLoading
                        ? Container(
                            width: 90,
                            height: 24,
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Text('Send OTP'),
                  ),
                ),
                if (_error != null && !_otpSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'We hit a snag. Try again in a bit, or ping us if you need help.',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ] else ...[
                Form(
                  key: _otpFormKey,
                  child: ShadInputOTPFormField(
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
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: ShadButton(
                    onPressed:
                        _isLoading ||
                            !RegExp(r'^\d{6}\u0000?$').hasMatch(_otpValue)
                        ? null
                        : _signInWithOTP,
                    enabled:
                        !_isLoading &&
                        RegExp(r'^\d{6}\u0000?$').hasMatch(_otpValue),
                    child: _isLoading
                        ? Container(
                            width: 90,
                            height: 24,
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Text('Verify OTP'),
                  ),
                ),
                if (_otpError != null && _otpSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _otpError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
