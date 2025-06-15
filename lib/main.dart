import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'main_navigation.dart';
import 'onboarding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      themeMode: ThemeMode.light,
      darkTheme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(),
      ),
      appBuilder: (context) {
        return MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.blueGrey[900],
            colorScheme: ColorScheme.light(
              primary: Colors.blueGrey[900]!,
              secondary: Colors.blueAccent,
              surface: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Colors.black,
            ),
            fontFamily: 'Helvetica Neue',
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              titleLarge: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            buttonTheme: const ButtonThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          builder: (context, child) {
            return ShadAppBuilder(child: child!);
          },
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginPage(),
            '/main': (context) => const MainNavigation(),
          },
        );
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.purple[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_run,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // App Name
                    const Text(
                      'Asteroidea',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Tagline
                    Text(
                      'Find your running & cycling community',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Join local events, meet new people, stay active',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Bottom section with button
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
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
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'No spam, just great workout partners',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<void> _createMissingUserDocument(User user) async {
    try {
      
      // Create user document if it doesn't exist
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboardingComplete': false,
        'eventsAttended': 0,
        'friends': [],
        'friendRequests': [],
      });
      
    } catch (e) {
      // If document creation fails, we'll still proceed to onboarding
      // The onboarding flow should handle document creation as well
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LandingPage();
        }

        
        // User is authenticated, check onboarding status
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User document doesn't exist, create it and go to onboarding
              return FutureBuilder<void>(
                future: _createMissingUserDocument(user),
                builder: (context, createSnapshot) {
                  if (createSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: Colors.white,
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return const OnboardingPage();
                },
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final onboardingComplete = userData?['onboardingComplete'] == true;

            if (!onboardingComplete) {
              return const OnboardingPage();
            }
            return const MainNavigation();
          },
        );
      },
    );
  }
}

class LoginOrSignUpPage extends StatefulWidget {
  const LoginOrSignUpPage({super.key});

  @override
  State<LoginOrSignUpPage> createState() => _LoginOrSignUpPageState();
}

class _LoginOrSignUpPageState extends State<LoginOrSignUpPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  String? _error;
  bool _otpSent = false;

  Future<void> _verifyPhone() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        _isLoading = false;
      });
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
        child: ShadCard(
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
                  ShadInput(
                    controller: _phoneController,
                    placeholder: const Text('+1 234 567 8900'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  ShadButton(
                    onPressed: _isLoading ? null : _verifyPhone,
                    child: _isLoading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Text('Send OTP'),
                  ),
                ] else ...[
                  ShadInput(
                    controller: _otpController,
                    placeholder: const Text('123456'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ShadButton(
                    onPressed: _isLoading ? null : _signInWithOTP,
                    child: _isLoading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Text('Verify OTP'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
