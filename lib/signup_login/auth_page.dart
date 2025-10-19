import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../homepage/homepage.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  
  const AuthScreen({Key? key, this.isLogin = true}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  late FocusNode _usernameFocus;
  late FocusNode _passwordFocus;
  late FocusNode _confirmPasswordFocus;
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  late bool _isLoginMode;
  bool _showPasswordError = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.isLogin;
    _usernameController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
    
    _usernameFocus = FocusNode();
    _passwordFocus = FocusNode();
    _confirmPasswordFocus = FocusNode();
    
    // Rebuild when focus changes to show orange border immediately
    _usernameFocus.addListener(() {
      setState(() {});
    });
    _passwordFocus.addListener(() {
      setState(() {});
    });
    _confirmPasswordFocus.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _formKey.currentState?.reset();
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus();
      _showPasswordError = false;
    });
  }

  void _onFieldChanged() {
    if (_showPasswordError || _showValidationErrors) {
      setState(() {
        _showPasswordError = false;
        _showValidationErrors = false;
        _formKey.currentState?.reset();
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _showPasswordError = false;
        _showValidationErrors = false;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (_isLoginMode) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          setState(() {
            _isLoginMode = true;
            _formKey.currentState?.reset();
            _usernameController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
            FocusScope.of(context).unfocus();
            _showPasswordError = false;
            _showValidationErrors = false;
          });
        }
      }
    } else {
      setState(() {
        _showValidationErrors = true;
      });
    }
  }

  // Helper method to build consistent text field borders
  InputBorder _buildBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // Helper method to build text field decoration
  InputDecoration _buildTextFieldDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    required bool isFocused,
    required bool hasError,
    required FocusNode focusNode,
  }) {
    // If focused, always show orange - even if there's an error
    Color borderColor = isFocused 
        ? AppTheme.primaryOrange
        : (hasError ? Colors.red : Colors.grey[300]!);
    
    Color labelColor = isFocused
        ? AppTheme.primaryOrange
        : (hasError ? Colors.red : Colors.grey);
    
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: hasError && !isFocused ? Colors.red : Colors.grey,
      ),
      floatingLabelStyle: TextStyle(
        color: labelColor,
      ),
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      border: _buildBorder(Colors.grey[300]!),
      enabledBorder: _buildBorder(borderColor),
      focusedBorder: _buildBorder(AppTheme.primaryOrange, width: 2),
      errorBorder: _buildBorder(Colors.red, width: 2),
      focusedErrorBorder: _buildBorder(AppTheme.primaryOrange, width: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/mysafezone_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'MYSafeZone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Goldman',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 77, 57, 22),
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _isLoginMode ? 'Welcome Back' : 'Join MYSafeZone community today',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    cursorColor: AppTheme.primaryOrange,
                    decoration: _buildTextFieldDecoration(
                      labelText: 'Username',
                      prefixIcon: Icons.person_outline,
                      isFocused: _usernameFocus.hasFocus,
                      hasError: _showValidationErrors && _usernameController.text.isEmpty,
                      focusNode: _usernameFocus,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _isLoginMode 
                            ? 'Please enter your username'
                            : 'Please enter a username';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    cursorColor: AppTheme.primaryOrange,
                    decoration: _buildTextFieldDecoration(
                      labelText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      isFocused: _passwordFocus.hasFocus,
                      hasError: _showValidationErrors && _passwordController.text.isEmpty,
                      focusNode: _passwordFocus,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _isLoginMode
                            ? 'Please enter your password'
                            : 'Please enter a password';
                      }
                      return null;
                    },
                  ),

                  // Confirm Password Field (only for sign up)
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      obscureText: _obscureConfirmPassword,
                      cursorColor: AppTheme.primaryOrange,
                      onChanged: (value) {
                        setState(() {
                          _showPasswordError = false;
                        });
                      },
                      decoration: _buildTextFieldDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        isFocused: _confirmPasswordFocus.hasFocus,
                        hasError: _showPasswordError && _confirmPasswordController.text != _passwordController.text,
                        focusNode: _confirmPasswordFocus,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          setState(() => _showPasswordError = true);
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          setState(() => _showPasswordError = true);
                          return 'Passwords do not match';
                        }
                        setState(() => _showPasswordError = false);
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isLoginMode ? 'Login' : 'Sign Up',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Toggle between Login/Sign Up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoginMode
                            ? "Don't have an account? "
                            : 'Already have an account? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: _toggleMode,
                        child: Text(
                          _isLoginMode ? 'Sign Up' : 'Login',
                          style: const TextStyle(
                            color: AppTheme.primaryOrange,
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