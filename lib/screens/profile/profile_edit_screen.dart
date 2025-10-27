import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  bool _hasChangedUsername = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    // Delay loading to ensure AuthService is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user data when dependencies change (e.g., AuthService updates)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    debugPrint('Loading user data...');
    debugPrint('AuthService userModel: ${authService.userModel}');
    debugPrint('AuthService user: ${authService.user}');
    
    if (authService.userModel != null) {
      debugPrint('Loading from userModel:');
      debugPrint('Full Name: ${authService.userModel!.fullName}');
      debugPrint('Email: ${authService.userModel!.email}');
      debugPrint('Username: ${authService.userModel!.username}');
      debugPrint('Company: ${authService.userModel!.company}');
      debugPrint('Position: ${authService.userModel!.position}');
      debugPrint('Phone: ${authService.userModel!.phoneNumber}');
      
      _nameController.text = authService.userModel!.fullName;
      _emailController.text = authService.userModel!.email;
      _usernameController.text = authService.userModel!.username;
      _companyController.text = authService.userModel!.company ?? '';
      _positionController.text = authService.userModel!.position ?? '';
      _phoneController.text = authService.userModel!.phoneNumber ?? '';
      _bioController.text = authService.userModel!.bio ?? '';
      _linkedinController.text = authService.userModel!.socialLinks['linkedin'] ?? '';
      _currentImageUrl = authService.userModel!.profileImageUrl;
      
      debugPrint('Controllers updated with userModel data');
    } else if (authService.user != null) {
      debugPrint('Loading from Firebase user:');
      debugPrint('Display Name: ${authService.user!.displayName}');
      debugPrint('Email: ${authService.user!.email}');
      
      _nameController.text = authService.user!.displayName ?? '';
      _emailController.text = authService.user!.email ?? '';
      _usernameController.text = ''; // No username in Firebase user
      _companyController.text = '';
      _positionController.text = '';
      _phoneController.text = '';
      _bioController.text = '';
      _linkedinController.text = '';
      _currentImageUrl = authService.user!.photoURL;
      
      debugPrint('Controllers updated with Firebase user data');
      
      // If userModel is null but user exists, try to load user data
      if (authService.userModel == null) {
        debugPrint('UserModel is null, attempting to load user data...');
        await authService.loadUserData();
      }
    } else {
      debugPrint('No user data available');
    }
  }

  Future<void> _checkUsernameExists(String username) async {
    if (username.isEmpty || username.length < 3 || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    // Check if username is the same as current username
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userModel?.username == username) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final usernameExists = await authService.checkUsernameExists(username);
      
      if (usernameExists) {
        setState(() {
          _usernameError = 'Username already exists';
        });
      } else {
        setState(() {
          _usernameError = null;
        });
      }
    } catch (e) {
      setState(() {
        _usernameError = 'Error checking username. Please try again.';
      });
    } finally {
      setState(() {
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _currentImageUrl;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.user?.uid ?? authService.userModel?.uid;
      
      if (userId == null) return null;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      await ref.putFile(_selectedImage!);
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Upload image if selected
      String? imageUrl = await _uploadImage();
      
      // Update user profile
      final socialLinks = <String, String>{};
      if (_linkedinController.text.trim().isNotEmpty) {
        socialLinks['linkedin'] = _linkedinController.text.trim();
      }
      
      await authService.updateUserProfile(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        company: _companyController.text.trim(),
        position: _positionController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        profileImageUrl: imageUrl,
        socialLinks: socialLinks,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Profile'),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _isLoading ? AppColors.grey400 : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture Section
                  _buildProfilePictureSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Form Fields
                  CustomTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person,
                    enabled: false, // Name is not editable
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    prefixIcon: Icons.email,
                    enabled: false, // Email is not editable
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Username field with validation
                  CustomTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Choose a unique username',
                    prefixIcon: Icons.alternate_email,
                    onChanged: (value) {
                      // Track if username has been changed
                      final authService = Provider.of<AuthService>(context, listen: false);
                      if (authService.userModel?.username != value) {
                        _hasChangedUsername = true;
                      }
                      
                      // Debounce the username check to avoid too many API calls
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_usernameController.text == value) {
                          _checkUsernameExists(value);
                        }
                      });
                    },
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
                      if (_usernameError != null) {
                        return _usernameError;
                      }
                      return null;
                    },
                  ),
                  
                  // Username error message
                  if (_usernameError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _usernameError!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Username checking indicator
                  if (_isCheckingUsername)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Checking username availability...',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Username change limit warning
                  if (_hasChangedUsername)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_outlined,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You can only change your username once. Choose carefully!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: _companyController,
                    label: 'Company',
                    hint: 'Enter your company name',
                    prefixIcon: Icons.business,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: _positionController,
                    label: 'Position',
                    hint: 'Enter your job title',
                    prefixIcon: Icons.work,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter your phone number',
                    prefixIcon: Icons.phone,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: _bioController,
                    label: 'Bio',
                    hint: 'Tell us about yourself',
                    prefixIcon: Icons.info,
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: _linkedinController,
                    label: 'LinkedIn Profile',
                    hint: 'https://linkedin.com/in/yourprofile',
                    prefixIcon: Icons.work,
                    keyboardType: TextInputType.url,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  CustomButton(
                    text: 'Save Changes',
                    onPressed: _isLoading ? null : _saveProfile,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        // Profile Picture
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        )
                      : _currentImageUrl != null
                          ? Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar();
                              },
                            )
                          : _buildDefaultAvatar(),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        Text(
          'Tap to change photo',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.userModel?.fullName ?? 
                    authService.user?.displayName ?? 
                    'User';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}