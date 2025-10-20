import 'package:flutter/material.dart';
import 'package:agconnect_auth/agconnect_auth.dart'; // Import ACG Auth
import 'package:huawei_account/huawei_account.dart'; // Import Account Kit for button & Scope
import 'auth_service.dart'; // Import our updated service
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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;
  late FocusNode _confirmPasswordFocus;

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  late bool _isLoginMode;
  bool _showPasswordError = false; // Used only for confirm password matching visual
  bool _showValidationErrors = false; // Used for general form validation visuals

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.isLogin;
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);

    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    _confirmPasswordFocus = FocusNode();

    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _formKey.currentState?.reset(); // Reset validation state
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus(); // Hide keyboard
      _showPasswordError = false;
      _showValidationErrors = false;
    });
  }

  // Reset error visuals when user types
  void _onFieldChanged() {
    if (_showValidationErrors) {
      setState(() {
        _showValidationErrors = false;
        // Optionally re-validate silently to update borders if needed
        // _formKey.currentState?.validate();
      });
    }
    // Also clear confirm password specific error visual if user edits either password field
    if (!_isLoginMode && _showPasswordError && ( _passwordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty)) {
      setState(() {
        _showPasswordError = false;
      });
    }
  }

  // --- Snackbar Helpers (Unchanged) ---
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Handle Email/Password Submit ---
  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _showValidationErrors = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _showValidationErrors = false;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isLoginMode) {
        // --- LOGIN ---
        final user = await _authService.signInWithEmail(email, password);
        if (user != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          _showErrorSnackBar("Login failed. Please check credentials."); // Fallback error
        }
      } else {
        // --- SIGN UP (Step 1: Request Code) ---
        await _authService.requestEmailCodeForSignUp(email);
        _showSuccessSnackBar("Verification code sent to $email");
        _showVerifyCodeDialog(); // Proceed to ask for the code
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Show Sign-Up Verification Code Dialog ---
  void _showVerifyCodeDialog() {
    final codeController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Enter Verification Code"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Enter the code sent to ${_emailController.text.trim()}"),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Verification Code",
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: isDialogLoading ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading ? null : () async {
                    final code = codeController.text.trim();
                    if (code.isEmpty) {
                      _showErrorSnackBar("Please enter the code"); // Show error inside dialog context
                      return;
                    }

                    setDialogState(() => isDialogLoading = true);

                    try {
                      // --- SIGN UP (Step 2: Create User) ---
                      await _authService.createEmailUser(
                        _emailController.text.trim(),
                        _passwordController.text, // Get password from main page state
                        code,
                      );

                      if (mounted) {
                        Navigator.of(context).pop(); // Close dialog
                        _showSuccessSnackBar("Account created! Please log in.");
                        _toggleMode(); // Switch to login mode
                      }
                    } catch (e) {
                      // Show error without closing dialog
                      _showErrorSnackBar(e.toString());
                    } finally {
                      // Only update state if dialog is still mounted
                      // Check mounted state of the main widget, implicitly checks dialog too
                      if(mounted) {
                        setDialogState(() => isDialogLoading = false);
                      }
                    }
                  },
                  child: isDialogLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Create Account"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // --- Handle Huawei ID Sign-In ---
  Future<void> _handleHuaweiSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithHuaweiID();
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        _showErrorSnackBar("Huawei ID Sign-In failed."); // Fallback if user is null without exception
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- MODIFIED: Show Forgot Password Flow ---
  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController(text: _emailController.text); // Pre-fill if available
    bool isRequestingCode = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder for loading state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Reset Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter your email to receive a password reset code."),
                  const SizedBox(height: 16),
                  TextField(
                    controller: forgotEmailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: isRequestingCode ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  onPressed: isRequestingCode ? null : () async {
                    final email = forgotEmailController.text.trim();
                    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      _showErrorSnackBar("Please enter a valid email.");
                      return;
                    }

                    setDialogState(() => isRequestingCode = true);
                    try {
                      await _authService.requestPasswordResetCode(email);
                      if (mounted) {
                        Navigator.of(context).pop(); // Close this dialog
                        _showSuccessSnackBar("Password reset code sent to $email");
                        _showResetPasswordEnterCodeDialog(email); // Open the next dialog
                      }
                    } catch (e) {
                      if (mounted) {
                        // Keep dialog open, show error
                        _showErrorSnackBar(e.toString());
                      }
                    } finally {
                      if (mounted) {
                        setDialogState(() => isRequestingCode = false);
                      }
                    }
                  },
                  child: isRequestingCode
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Get Code"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- NEW: Dialog to Enter Reset Code and New Password ---
  void _showResetPasswordEnterCodeDialog(String email) {
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isResetting = false;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Enter Code & New Password"),
              content: Form( // Use a Form for validation
                key: formKey,
                child: SingleChildScrollView( // Allow scrolling if needed
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Enter the code sent to $email and your new password."),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Verification Code",
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter code' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: "New Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setDialogState(() => obscureNewPassword = !obscureNewPassword),
                          ),
                        ),
                        validator: _validatePassword, // Reuse password validation
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: "Confirm New Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm password';
                          if (v != newPasswordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: isResetting ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  onPressed: isResetting ? null : () async {
                    if (!formKey.currentState!.validate()) {
                      return; // Validation failed
                    }

                    final code = codeController.text.trim();
                    final newPassword = newPasswordController.text;

                    setDialogState(() => isResetting = true);
                    try {
                      await _authService.resetPasswordWithCode(email, newPassword, code);
                      if (mounted) {
                        Navigator.of(context).pop(); // Close this dialog
                        _showSuccessSnackBar("Password has been reset successfully. Please log in.");
                        // Optionally clear fields if staying on login page
                        _emailController.text = email; // Keep email filled
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      }
                    } catch (e) {
                      if (mounted) {
                        // Keep dialog open, show error
                        _showErrorSnackBar(e.toString());
                      }
                    } finally {
                      if (mounted) {
                        setDialogState(() => isResetting = false);
                      }
                    }
                  },
                  child: isResetting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Reset Password"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI Build Helpers (Unchanged) ---
  InputBorder _buildBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _buildTextFieldDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    required bool isFocused,
    required bool hasError, // This flag controls error border/label color
    required FocusNode focusNode,
  }) {
    Color borderColor = isFocused
        ? AppTheme.primaryOrange
        : (hasError ? Colors.red : Colors.grey[300]!);

    Color labelColor = isFocused
        ? AppTheme.primaryOrange
        : (hasError ? Colors.red : Colors.grey); // Label matches border unless focused

    return InputDecoration(
      labelText: labelText,
      // Label style: Red ONLY if there's an error AND the field is NOT focused
      labelStyle: TextStyle(
        color: hasError && !isFocused ? Colors.red : Colors.grey,
      ),
      // Floating label style: Follows focus/error state logic
      floatingLabelStyle: TextStyle(
        color: labelColor,
      ),
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      border: _buildBorder(Colors.grey[300]!), // Default border
      enabledBorder: _buildBorder(borderColor), // Border when enabled (takes error state)
      focusedBorder: _buildBorder(AppTheme.primaryOrange, width: 2), // Orange when focused
      errorBorder: _buildBorder(Colors.red, width: 2), // Red error border when not focused
      focusedErrorBorder: _buildBorder(AppTheme.primaryOrange, width: 2), // Orange error border WHEN focused
      errorStyle: const TextStyle(fontSize: 0, height: 0), // Hide default error text below field
    );
  }

  // --- Password Validator (Slightly adjusted for reset dialog) ---
  String? _validatePassword(String? value, {bool isLoginCheck = false}) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    // Skip complex rules if just logging in OR if called from reset dialog without signup context
    if (_isLoginMode || isLoginCheck) {
      return null;
    }

    // Sign Up / New Password Rules
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one symbol';
    }
    return null;
  }

  // --- Build Method (Mostly Unchanged UI, logic adjusted) ---
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
                  // --- Logo and Title ---
                  Container( /* ... Logo ... */
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
                  const Text( /* ... Title ... */
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
                  Text( /* ... Subtitle ... */
                    _isLoginMode ? 'Welcome Back' : 'Join MYSafeZone community today',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Email Field ---
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    cursorColor: AppTheme.primaryOrange,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildTextFieldDecoration(
                      labelText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      isFocused: _emailFocus.hasFocus,
                      // Error visual if general validation failed AND field is empty/invalid
                      hasError: _showValidationErrors && (_emailController.text.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text)),
                      focusNode: _emailFocus,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    cursorColor: AppTheme.primaryOrange,
                    decoration: _buildTextFieldDecoration(
                      labelText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      isFocused: _passwordFocus.hasFocus,
                      // Error visual if general validation failed AND field is empty/invalid
                      hasError: _showValidationErrors && _validatePassword(_passwordController.text, isLoginCheck: _isLoginMode) != null,
                      focusNode: _passwordFocus,
                    ),
                    validator: (v) => _validatePassword(v, isLoginCheck: _isLoginMode), // Use wrapper validator
                  ),

                  // --- Confirm Password Field (Sign Up only) ---
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      obscureText: _obscureConfirmPassword,
                      cursorColor: AppTheme.primaryOrange,
                      decoration: _buildTextFieldDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        isFocused: _confirmPasswordFocus.hasFocus,
                        // Error visual if general validation failed AND passwords don't match or empty
                        hasError: _showValidationErrors && (_confirmPasswordController.text.isEmpty || _confirmPasswordController.text != _passwordController.text),
                        focusNode: _confirmPasswordFocus,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          // Set specific flag for immediate visual feedback on mismatch if needed
                          // Future enhancement: could update _showPasswordError here based on mismatch
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onChanged: (value) { // Trigger re-validation of password field if confirm changes
                        _formKey.currentState?.validate();
                        // Optionally reset specific mismatch flag if user edits confirm field
                        if(_showPasswordError) setState(() => _showPasswordError = false);
                      },
                    ),
                  ],

                  // --- Forgot Password Button (Login only) ---
                  if (_isLoginMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // --- Submit Button ---
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isLoginMode ? 'Login' : 'Sign Up', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Toggle Login/Sign Up ---
                  Row( /* ... Toggle Row ... */
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoginMode ? "Don't have an account? " : 'Already have an account? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _toggleMode, // Disable toggle while loading
                        child: Text(
                          _isLoginMode ? 'Sign Up' : 'Login',
                          style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // Added spacing before OR

                  // --- Divider ---
                  const Padding( /* ... OR Divider ... */
                    padding: EdgeInsets.symmetric(vertical: 8.0), // Reduced vertical padding
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text("OR", style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),

                  // --- Huawei ID Button ---
                  SizedBox(
                    height: 50,
                    child: HuaweiIdAuthButton( // Make sure this widget is correctly imported/available
                      onPressed: _isLoading ? () {} : _handleHuaweiSignIn,
                      buttonColor: AuthButtonBackground.RED,
                      borderRadius: AuthButtonRadius.MEDIUM,
                    ),
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