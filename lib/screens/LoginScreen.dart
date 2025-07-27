import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fball/components/crud.dart';
import 'package:fball/constants/linkapi.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Crud _crud = Crud();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> login() async {
    setState(() => isLoading = true);

    try {
      var response = await _crud.postrequest(linkLogin, {
        'email': _emailController.text,
        'password': _passwordController.text,
      });

      if (response != null && response['status'] == 'success') {
        print('Login Success');

        // قراءة الحالة من السيرفر: 1 = admin, 0 = user
        String role = response['role'];

        if (role == 'admin') {
          Navigator.of(context).pushNamedAndRemoveUntil(
            'summarization_admin_screen',
            (route) => false,
          );
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            'summarization_user_screen',
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Login Error: $e');
    }

    setState(() => isLoading = false);
  }

  void validateAndLogin() {
    if (_formKey.currentState!.validate()) {
      login();
    }
  }

  void goToRegister() {
    Navigator.of(context).pushReplacementNamed("RegisterScreen");
  }

  @override
  Widget build(BuildContext context) {
    const backColor = Color(0xFFC9D6DF);
    const textColor = Color(0xFF000000);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back arrow
        title: const Text(
          "",
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous page
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 355,
                          height: 355,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 109, 188, 134),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(255, 74, 124, 89),
                              width: 8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                spreadRadius: 5,
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: ClipOval(
                              child: Container(
                                width: 340,
                                height: 340,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  "images/FBLogo.png",
                                  fit: BoxFit.cover,
                                  width: 340,
                                  height: 340,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        Text(
                          "Login to your Account",
                          style: GoogleFonts.robotoCondensed(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(
                                color: Colors.black, fontSize: 16),
                            prefixIcon: const Icon(Icons.email,
                                color: Colors.lightBlue),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.black),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter your password'
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(
                                color: Colors.black, fontSize: 16),
                            prefixIcon:
                                const Icon(Icons.lock, color: Colors.lightBlue),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Login Button
                        Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: MaterialButton(
                            minWidth: 160,
                            onPressed: validateAndLogin,
                            child: Text(
                              "Login",
                              style: GoogleFonts.robotoCondensed(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Register Prompt
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.robotoCondensed(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: goToRegister,
                              child: Text(
                                "SignUp",
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 18,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
