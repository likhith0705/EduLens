import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'screens/teacher_dashboard_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';

const String webClientId =
    '245046756856-um8bqsmbfq40c73d5j756jb2dkst89ha.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GoogleSignIn.instance.initialize(
    serverClientId: webClientId,
  );

  final backendHealthy = await ApiService.healthCheck();

  debugPrint(
    'EduLens Backend Health: $backendHealthy',
  );

  runApp(const EduLensApp());
}

class EduLensApp extends StatelessWidget {
  const EduLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduLens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

Future<void> logout(BuildContext context) async {
  try {
    await GoogleSignIn.instance.disconnect();
  } catch (e) {
    debugPrint('Logout error: $e');
  }

  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (context) => const LoginPage(),
    ),
    (route) => false,
  );
}

class _LoginPageState extends State<LoginPage> {
  String? signedInEmail;
  String? errorMessage;
  bool isLoading = false;

  
Future<void> _signInWithGoogle() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final account = await GoogleSignIn.instance.authenticate();

    final authentication = account.authentication;
    final idToken = authentication.idToken;

    if (idToken == null) {
      throw Exception('Google ID token was not received');
    }

    final backendResponse = await ApiService.googleLogin(idToken);
    final backendUser =
        backendResponse['user'] as Map<String, dynamic>;

    final email = backendUser['email'] as String;
    final role = backendUser['role'] as String?;

    if (!mounted) return;

    setState(() {
      isLoading = false;
      signedInEmail = email;
    });

    if (role == 'teacher') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherDashboardScreen(
            userName: backendUser['name'] ?? 'Teacher',
            email: email,
            photoUrl: backendUser['profile_photo_url'] ??
                account.photoUrl,
            idToken: idToken,
            onLogout: logout,
          ),
        ),
      );
    } else if (role == 'student') {
      final studentData =
          await ApiService.getStudentProfile(email);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            userName: backendUser['name'] ?? 'Student',
            email: email,
            photoUrl: backendUser['profile_photo_url'] ??
                account.photoUrl,
            studentData: studentData,
            onLogout: logout,
          ),
        ),
      );
    } else {
      throw Exception(
        'Your EduLens account has an unsupported role.',
      );
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      errorMessage = e.toString();
      isLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/college_logo.jpg',
                height: 100,
                width: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'EduLens',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sai Vidya Institute of Technology',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: Text(
                    isLoading
                        ? 'Signing in...'
                        : 'Continue with Google',
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
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