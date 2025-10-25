import 'package:flutter/material.dart';
import 'package:huawei_account/huawei_account.dart';
import 'auth_service.dart';
import '../util/snackbar_helper.dart';
import '../app_theme.dart';
import '../homepage/homepage.dart';
import 'terms_conditions_page.dart';
import 'privacy_policy_page.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({super.key, this.isLogin = true});

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
  bool _showValidationErrors = false;
  bool _acceptTerms = false;

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
      _formKey.currentState?.reset();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _acceptTerms = false;
      FocusScope.of(context).unfocus();
      _showValidationErrors = false;
    });
  }

  void _onFieldChanged() {
    if (_showValidationErrors) {
      setState(() {
        _showValidationErrors = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _showValidationErrors = true);
      return;
    }

    // Check if terms are accepted for signup
    if (!_isLoginMode && !_acceptTerms) {
      Snackbar.error("Please accept the Terms and Conditions to continue.");
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
        final user = await _authService.signInWithEmail(
          context,
          email,
          password,
        );
        if (user != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          Snackbar.error("Login failed. Please check credentials.");
        }
      } else {
        await _authService.requestEmailCodeForSignUp(email);
        Snackbar.success("Verification code sent to $email");
        _showVerifyCodeDialog();
      }
    } catch (e) {
      Snackbar.error(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerifyCodeDialog() {
    final codeController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Enter Verification Code"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Enter the code sent to ${_emailController.text.trim()}",
                  ),
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
                  onPressed: isDialogLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: AppTheme.primaryOrange),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            Snackbar.error("Please enter the code");
                            return;
                          }

                          setDialogState(() => isDialogLoading = true);

                          try {
                            await _authService.createEmailUser(
                              _emailController.text.trim(),
                              _passwordController.text,
                              code,
                            );

                            if (mounted) {
                              Navigator.of(context).pop();
                              Snackbar.success(
                                "Account created! Please log in.",
                              );
                              _toggleMode();
                            }
                          } catch (e) {
                            Snackbar.error(e.toString());
                          } finally {
                            if (mounted) {
                              setDialogState(() => isDialogLoading = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: isDialogLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Create Account"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleHuaweiSignIn() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('[HuaweiSignIn] Starting sign-in');
      final user = await _authService.signInWithHuaweiID(context);
      debugPrint('[HuaweiSignIn] Sign-in completed: ${user?.uid}');

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        Snackbar.error("Huawei ID Sign-In failed.");
      }
    } catch (e) {
      Snackbar.error(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController(
      text: _emailController.text,
    );
    bool isRequestingCode = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Reset Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Enter your email to receive a password reset code.",
                  ),
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
                  onPressed: isRequestingCode
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: AppTheme.primaryOrange),
                  ),
                ),
                ElevatedButton(
                  onPressed: isRequestingCode
                      ? null
                      : () async {
                          final email = forgotEmailController.text.trim();
                          if (email.isEmpty ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                            Snackbar.error("Please enter a valid email.");
                            return;
                          }

                          setDialogState(() => isRequestingCode = true);
                          try {
                            await _authService.requestPasswordResetCode(email);
                            if (mounted) {
                              Navigator.of(context).pop();
                              Snackbar.success(
                                "Password reset code sent to $email",
                              );
                              _showResetPasswordEnterCodeDialog(email);
                            }
                          } catch (e) {
                            if (mounted) {
                              Snackbar.error(e.toString());
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => isRequestingCode = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: isRequestingCode
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Get Code"),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Enter the code sent to $email and your new password.",
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Verification Code",
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Please enter code' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: "New Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureNewPassword = !obscureNewPassword,
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: "Confirm New Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureConfirmPassword =
                                  !obscureConfirmPassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm password';
                          }
                          if (v != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isResetting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: AppTheme.primaryOrange),
                  ),
                ),
                ElevatedButton(
                  onPressed: isResetting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final code = codeController.text.trim();
                          final newPassword = newPasswordController.text;

                          setDialogState(() => isResetting = true);
                          try {
                            await _authService.resetPasswordWithCode(
                              email,
                              newPassword,
                              code,
                            );
                            if (mounted) {
                              Navigator.of(context).pop();
                              Snackbar.success(
                                "Password has been reset successfully. Please log in.",
                              );
                              _emailController.text = email;
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            }
                          } catch (e) {
                            if (mounted) {
                              Snackbar.error(e.toString());
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => isResetting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: isResetting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Reset Password"),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
    required bool hasError,
    required FocusNode focusNode,
  }) {
    // When focused, always show orange and hide errors
    // When not focused and has error and validation is shown, show red
    // Otherwise show grey
    Color borderColor;
    Color labelColor;
    Color iconColor;

    if (isFocused) {
      borderColor = AppTheme.primaryOrange;
      labelColor = AppTheme.primaryOrange;
      iconColor = AppTheme.primaryOrange;
    } else if (hasError && _showValidationErrors) {
      borderColor = Colors.red;
      labelColor = Colors.red;
      iconColor = Colors.red;
    } else {
      borderColor = Colors.grey[300]!;
      labelColor = Colors.grey;
      iconColor = Colors.grey;
    }

    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: isFocused ? Colors.grey : labelColor),
      floatingLabelStyle: TextStyle(color: labelColor),
      prefixIcon: Icon(prefixIcon, color: iconColor),
      suffixIcon: suffixIcon,
      border: _buildBorder(Colors.grey[300]!),
      enabledBorder: _buildBorder(borderColor),
      focusedBorder: _buildBorder(AppTheme.primaryOrange, width: 2),
      errorBorder: _buildBorder(
        _showValidationErrors ? Colors.red : Colors.grey[300]!,
        width: _showValidationErrors ? 2 : 1,
      ),
      focusedErrorBorder: _buildBorder(AppTheme.primaryOrange, width: 2),
      errorStyle: TextStyle(
        fontSize: 12,
        height: _showValidationErrors ? 1 : 0.01,
        color: _showValidationErrors ? Colors.red : Colors.transparent,
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value, {bool isLoginCheck = false}) {
    if (value == null || value.isEmpty) {
      return _isLoginMode
          ? 'Please enter your password'
          : 'Please enter a password';
    }

    if (_isLoginMode || isLoginCheck) {
      return null;
    }

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

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Password does not match';
    }
    return null;
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
                  // Logo
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
                    _isLoginMode
                        ? 'Welcome Back'
                        : 'Join MYSafeZone community today',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    cursorColor: AppTheme.primaryOrange,
                    keyboardType: TextInputType.emailAddress,
                    onTap: () {
                      setState(() => _showValidationErrors = false);
                    },
                    decoration: _buildTextFieldDecoration(
                      labelText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      isFocused: _emailFocus.hasFocus,
                      hasError:
                          _showValidationErrors &&
                          _validateEmail(_emailController.text) != null,
                      focusNode: _emailFocus,
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    cursorColor: AppTheme.primaryOrange,
                    onTap: () {
                      setState(() => _showValidationErrors = false);
                    },
                    decoration: _buildTextFieldDecoration(
                      labelText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      isFocused: _passwordFocus.hasFocus,
                      hasError:
                          _showValidationErrors &&
                          _validatePassword(
                                _passwordController.text,
                                isLoginCheck: _isLoginMode,
                              ) !=
                              null,
                      focusNode: _passwordFocus,
                    ),
                    validator: (v) =>
                        _validatePassword(v, isLoginCheck: _isLoginMode),
                  ),

                  // Confirm Password Field (Sign Up only)
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      obscureText: _obscureConfirmPassword,
                      cursorColor: AppTheme.primaryOrange,
                      onTap: () {
                        setState(() => _showValidationErrors = false);
                      },
                      decoration: _buildTextFieldDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                        isFocused: _confirmPasswordFocus.hasFocus,
                        hasError:
                            _showValidationErrors &&
                            _validateConfirmPassword(
                                  _confirmPasswordController.text,
                                ) !=
                                null,
                        focusNode: _confirmPasswordFocus,
                      ),
                      validator: _validateConfirmPassword,
                    ),
                  ],
                  // Terms and Conditions Checkbox (Sign Up only)
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                            });
                          },
                          activeColor: AppTheme.primaryOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _acceptTerms = !_acceptTerms;
                              });
                            },
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const TermsConditionsPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Terms and Conditions',
                                        style: TextStyle(
                                          color: AppTheme.primaryOrange,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const TermsConditionsPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          color: AppTheme.primaryOrange,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showValidationErrors && !_acceptTerms)
                      const Padding(
                        padding: EdgeInsets.only(left: 48.0, top: 4.0),
                        child: Text(
                          'Please accept the Terms and Conditions',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),

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

                  // Toggle Login/Sign Up
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
                        onPressed: _isLoading ? null : _toggleMode,
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

                  // Forgot Password Button (Login only) - Centered below toggle
                  if (_isLoginMode)
                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Terms and Conditions Link (Login only)
                  if (_isLoginMode)
                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TermsConditionsPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Divider
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            "OR",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),

                  // Huawei ID Button
                  SizedBox(
                    height: 50,
                    child: HuaweiIdAuthButton(
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
