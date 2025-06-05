import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shadcn_ui/src/components/form/fields/input.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_page.dart';
import 'package:flutter/services.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
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
      });
      // Check if user is new
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
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
              if (_error != null)
                ShadAlert.destructive(
                  title: const Text('Error'),
                  description: Text(_error!),
                ),
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
                ShadButton(
                  onPressed: _isLoading || !_isPhoneValid ? null : _verifyPhone,
                  enabled: _isPhoneValid && !_isLoading,
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Send OTP'),
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
                ShadButton(
                  onPressed:
                      _isLoading ||
                          !RegExp(r'^\d{6}\u0000?$').hasMatch(_otpValue)
                      ? null
                      : _signInWithOTP,
                  enabled:
                      !_isLoading &&
                      RegExp(r'^\d{6}\u0000?$').hasMatch(_otpValue),
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Verify OTP'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
