import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/status_service.dart';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  Future<void> _createStatus() async {
    if (_textController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some text or an image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final statusService = StatusService();
      
      String userName = 'User';
      String? userProfileImageUrl;
      
      if (authService.userModel != null) {
        userName = authService.userModel!.fullName;
        userProfileImageUrl = authService.userModel!.profileImageUrl;
      } else if (authService.user != null) {
        userName = authService.user!.displayName ?? 'User';
        userProfileImageUrl = authService.user!.photoURL;
      }

      await statusService.createStatus(
        userId: authService.user?.uid ?? '',
        userName: userName,
        userProfileImageUrl: userProfileImageUrl,
        text: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
        imageFile: _selectedImage,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.grey900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Status',
          style: TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createStatus,
            child: Text(
              'Share',
              style: TextStyle(
                color: _isLoading ? AppColors.grey400 : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // User info section
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Consumer<AuthService>(
                        builder: (context, authService, child) {
                          final profileImageUrl = authService.userModel?.profileImageUrl ?? 
                                                 authService.user?.photoURL;
                          final userName = authService.userModel?.fullName ?? 
                                         authService.user?.displayName ?? 'User';
                          
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary,
                            backgroundImage: profileImageUrl != null 
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer<AuthService>(
                              builder: (context, authService, child) {
                                final userName = authService.userModel?.fullName ?? 
                                             authService.user?.displayName ?? 'User';
                                return Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.grey900,
                                  ),
                                );
                              },
                            ),
                            const Text(
                              'Status expires in 24 hours',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Content section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text input
                        TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'What\'s on your mind?',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: AppColors.grey500,
                              fontSize: 16,
                            ),
                          ),
                          maxLines: null,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.grey900,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Image preview
                        if (_selectedImage != null)
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom action bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.grey200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library, size: 20),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt, size: 20),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
