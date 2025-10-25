import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  bool _obscurePassword = true;
  final bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String _accountType = 'Public'; // Default to Public
  
  // Progressive form state
  int _currentStep = 0;
  final int _totalSteps = 3;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Email and Password
        return _emailController.text.isNotEmpty && 
               _passwordController.text.isNotEmpty &&
               _passwordController.text.length >= 6;
      case 1: // Personal Information
        return _fullNameController.text.isNotEmpty &&
               _usernameController.text.isNotEmpty &&
               _phoneController.text.isNotEmpty &&
               _companyController.text.isNotEmpty;
      case 2: // Account Type and Terms
        return _agreeToTerms;
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      _nextStep();
      return;
    }

    // Final step - complete registration
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        company: _companyController.text.trim(),
        accountType: _accountType,
      );
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign up failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.grey600, size: 20),
          onPressed: () => context.go('/login'),
        ),
        title: Text(
          _getStepTitle(),
          style: const TextStyle(
            color: AppColors.grey700,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
              child: Column(
                children: [
                  Row(
                    children: List.generate(_totalSteps, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(
                            right: index < _totalSteps - 1 ? 6 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: index <= _currentStep 
                                ? AppColors.primary 
                                : AppColors.grey100,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Step ${_currentStep + 1} of $_totalSteps',
                    style: const TextStyle(
                      color: AppColors.grey500,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step content
                      _buildStepContent(),
                      
                      const SizedBox(height: 48),
                      
                      // Navigation buttons
                      _buildNavigationButtons(),
                      
                      const SizedBox(height: 24),
                      
                      // Google sign up (only on first step)
                      if (_currentStep == 0) ...[
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.grey100, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: AppColors.grey400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppColors.grey100, height: 1)),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        OutlinedButton.icon(
                          onPressed: _signUpWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 20, color: AppColors.grey600),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: AppColors.grey600,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.2,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.grey100, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: AppColors.white,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      // Sign in link
                      if (_currentStep == 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: AppColors.grey400,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              ),
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
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
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Create Your Account';
      case 1:
        return 'Personal Information';
      case 2:
        return 'Account Settings';
      default:
        return 'Create Your Account';
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEmailPasswordStep();
      case 1:
        return _buildPersonalInfoStep();
      case 2:
        return _buildAccountTypeStep();
      default:
        return _buildEmailPasswordStep();
    }
  }

  Widget _buildEmailPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.grey700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Join Linkly and unlock your business potential.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.grey500,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Email field
        CustomTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Password field
        CustomTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create your password',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outlined,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: AppColors.grey500,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.grey700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tell us a bit about yourself.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.grey500,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Full name field
        CustomTextField(
          controller: _fullNameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your full name';
            }
            if (value.length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Username field
        CustomTextField(
          controller: _usernameController,
          label: 'Username',
          hint: 'Choose a unique username',
          prefixIcon: Icons.alternate_email,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            if (value.length < 3) {
              return 'Username must be at least 3 characters';
            }
            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
              return 'Username can only contain letters, numbers, and underscores';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Phone number field
        CustomTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Company/College field
        CustomTextField(
          controller: _companyController,
          label: 'Company/College Name',
          hint: 'Enter your company or college name',
          prefixIcon: Icons.business_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your company or college name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAccountTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.grey700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose your account type and accept our terms.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.grey500,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Account Type selection
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.grey700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.grey100, width: 1),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text(
                      'Public',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
                    ),
                    subtitle: const Text(
                      'Personal information (email and phone number) will be shown to your connections',
                      style: TextStyle(fontSize: 13, color: AppColors.grey500, letterSpacing: -0.1),
                    ),
                    value: 'Public',
                    groupValue: _accountType,
                    onChanged: (value) {
                      setState(() {
                        _accountType = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  const Divider(height: 1, color: AppColors.grey100),
                  RadioListTile<String>(
                    title: const Text(
                      'Private',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
                    ),
                    subtitle: const Text(
                      'Personal information (email and phone number) won\'t be shown to your connections',
                      style: TextStyle(fontSize: 13, color: AppColors.grey500, letterSpacing: -0.1),
                    ),
                    value: 'Private',
                    groupValue: _accountType,
                    onChanged: (value) {
                      setState(() {
                        _accountType = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Terms and conditions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grey100, width: 1),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: AppColors.grey500,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.1,
                    ),
                    children: [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.grey100, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: AppColors.white,
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  color: AppColors.grey600,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Consumer<AuthService>(
            builder: (context, authService, child) {
              return ElevatedButton(
                onPressed: authService.isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: authService.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      )
                    : Text(
                        _currentStep == _totalSteps - 1 ? 'Create Account' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
