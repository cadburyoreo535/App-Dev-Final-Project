import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _lastController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _signup() {
    if (!_formKey.currentState!.validate()) return;
    // TODO: implement sign up logic (auth / firestore)
    Navigator.pushReplacementNamed(context, '/'); // go to dashboard after signup
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // logo / icon
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: Image.asset(
                      'lib/assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // First & Last name
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstController,
                          decoration: InputDecoration(
                            hintText: 'First name',
                            filled: true,
                            fillColor: const Color(0xFFF7F7F8),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Enter first name' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastController,
                          decoration: InputDecoration(
                            hintText: 'Last name',
                            filled: true,
                            fillColor: const Color(0xFFF7F7F8),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Enter last name' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      filled: true,
                      fillColor: const Color(0xFFF7F7F8),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter email';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Create a password',
                      filled: true,
                      fillColor: const Color(0xFFF7F7F8),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter password';
                      if (v.trim().length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  // Sign up button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F8C86),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Already have account -> Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: TextStyle(color: Colors.grey[700])),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}