import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'chat_screen.dart'; // Required for navigation

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Toggle between "Login" and "Register" modes
  bool isLoginMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLoginMode ? "Login" : "Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email Input
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            // Password Input
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            SizedBox(height: 20),

            // Login/Register Button
            ElevatedButton(
              onPressed: () async {
                String email = _emailController.text.trim();
                String password = _passwordController.text.trim();

                dynamic user;
                if (isLoginMode) {
                  user = await _auth.loginWithEmail(email, password);
                } else {
                  user = await _auth.registerWithEmail(email, password);
                }

                if (user != null) {
                  // 1. Success Message
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Success! Welcome ${user.email}"))
                  );

                  // 2. NAVIGATE to Chat Screen (The Fix)
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(user: user),
                    ),
                  );
                } else {
                  // Error Message
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error. Check console for details."))
                  );
                }
              },
              child: Text(isLoginMode ? "Login" : "Register"),
            ),

            // Toggle Button
            TextButton(
              onPressed: () {
                setState(() {
                  isLoginMode = !isLoginMode; // Switch modes
                });
              },
              child: Text(isLoginMode
                  ? "Don't have an account? Register"
                  : "Already have an account? Login"),
            )
          ],
        ),
      ),
    );
  }
}