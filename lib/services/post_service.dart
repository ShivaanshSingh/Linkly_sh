import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/post_model.dart';

class PostService extends ChangeNotifier {
  FirebaseFirestore? _firestore;
  final String _collection = 'posts';
  bool _isFirebaseAvailable = false;
  
  List<PostModel> _posts = [];
  bool _isLoading = false;
  String? _error;

  PostService() {
    try {
      _firestore = FirebaseFirestore.instance;
      _isFirebaseAvailable = true;
      debugPrint('PostService initialized with Firebase');
    } catch (e) {
      debugPrint('PostService initialized without Firebase: $e');
      _isFirebaseAvailable = false;
      // Load mock posts immediately for demonstration
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMockPosts();
      });
    }
  }

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get all posts ordered by creation date (newest first)
  Future<void> getPosts({String? currentUserId}) async {
    if (!_isFirebaseAvailable) {
      _loadMockPosts();
      return;
    }
    
    try {
      _setLoading(true);
      _error = null;
      
      debugPrint('PostService: Fetching posts from Firestore');
      
      // First, get all public posts
      final QuerySnapshot publicSnapshot = await _firestore!
          .collection(_collection)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      List<PostModel> publicPosts = publicSnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // If user is logged in, also get private posts from their connections
      List<PostModel> privatePosts = [];
      if (currentUserId != null) {
        // Get user's connections
        final connectionsSnapshot = await _firestore!
            .collection('connections')
            .where('userId', isEqualTo: currentUserId)
            .get();
        
        List<String> connectionIds = connectionsSnapshot.docs
            .map((doc) => doc.data()['contactUserId'] as String)
            .toList();
        
        if (connectionIds.isNotEmpty) {
          // Get private posts from connections
          final QuerySnapshot privateSnapshot = await _firestore!
              .collection(_collection)
              .where('userId', whereIn: connectionIds)
              .where('isPublic', isEqualTo: false)
              .orderBy('createdAt', descending: true)
              .get();
          
          privatePosts = privateSnapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
        }
      }

      // Combine and sort all posts
      _posts = [...publicPosts, ...privatePosts];
      _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // If no posts found, show empty state
      if (_posts.isEmpty) {
        debugPrint('PostService: No posts found in database');
      }
      
      debugPrint('PostService: Fetched ${_posts.length} posts (${publicPosts.length} public, ${privatePosts.length} private)');
      notifyListeners();
    } catch (e) {
      debugPrint('PostService: Error fetching posts: $e');
      
      // Handle Firebase index errors gracefully
      if (e is FirebaseException && e.code == 'failed-precondition') {
        debugPrint('PostService: Firestore index error detected. Showing empty state.');
        _error = null; // Clear error to show empty state
        _posts = []; // Clear posts to show empty state
      } else {
        // For other errors, show a user-friendly message
        _error = 'Unable to load posts at the moment. Please try again later.';
        debugPrint('PostService: General error fetching posts: $e');
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _loadMockPosts() {
    _posts = [
      PostModel(
        id: '1',
        userId: 'user1',
        userName: 'Sarah Connor',
        userAvatar: 'S',
        content: 'Excited to announce my new project focusing on sustainable tech solutions! It\'s been a challenging but rewarding journey. #SustainableTech #Innovation',
        imageUrl: null,
        likes: ['user2', 'user3'],
        shares: ['user4'],
        commentsCount: 5,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      PostModel(
        id: '2',
        userId: 'user2',
        userName: 'Michael Chen',
        userAvatar: 'M',
        content: 'Reflecting on the latest trends in AI and machine learning. The pace of change is incredible, and I\'m looking forward to the next breakthroughs. #AI #MachineLearning',
        imageUrl: null,
        likes: ['user1', 'user3', 'user4'],
        shares: ['user5'],
        commentsCount: 8,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      PostModel(
        id: '3',
        userId: 'user3',
        userName: 'Emily White',
        userAvatar: 'E',
        content: 'Attended an insightful webinar on remote work strategies. The future of work is definitely flexible! Sharing some key takeaways in my blog soon. #RemoteWork #FutureOfWork',
        imageUrl: null,
        likes: ['user1', 'user2'],
        shares: [],
        commentsCount: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
    notifyListeners();
    debugPrint('PostService: Loaded ${_posts.length} mock posts');
  }

  // Stream posts for real-time updates
  Stream<List<PostModel>> getPostsStream() {
    if (!_isFirebaseAvailable) {
      return Stream.value(_posts);
    }
    
    return _firestore!
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    });
  }

  // Create a new post
  Future<String?> createPost({
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
    String? imageUrl,
  }) async {
    if (!_isFirebaseAvailable) {
      // Mock post creation for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(milliseconds: 500));
      
      final newPost = PostModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        content: content,
        imageUrl: imageUrl,
        likes: [],
        shares: [],
        commentsCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _posts.insert(0, newPost);
      _setLoading(false);
      notifyListeners();
      debugPrint('PostService: Mock post created');
      return newPost.id;
    }
    
    try {
      _setLoading(true);
      _error = null;
      
      debugPrint('PostService: Creating new post for user: $userName');
      
      final postData = {
        'userId': userId,
        'userName': userName,
        'userAvatar': userAvatar,
        'content': content,
        'imageUrl': imageUrl,
        'likes': <String>[],
        'shares': <String>[],
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore!.collection(_collection).add(postData);
      
      debugPrint('PostService: Post created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _error = e.toString();
      debugPrint('PostService: Error creating post: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Like/Unlike a post
  Future<void> toggleLike(String postId, String userId) async {
    if (!_isFirebaseAvailable) {
      // Mock like toggle
      final postIndex = _posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        final newLikes = List<String>.from(post.likes);
        
        if (newLikes.contains(userId)) {
          newLikes.remove(userId);
        } else {
          newLikes.add(userId);
        }
        
        _posts[postIndex] = post.copyWith(
          likes: newLikes,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        debugPrint('PostService: Mock like toggled for post: $postId');
      }
      return;
    }
    
    try {
      debugPrint('PostService: Toggling like for post: $postId, user: $userId');
      
      final postRef = _firestore!.collection(_collection).doc(postId);
      
      await _firestore!.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }
        
        final postData = postDoc.data()!;
        final List<String> likes = List<String>.from(postData['likes'] ?? []);
        
        if (likes.contains(userId)) {
          likes.remove(userId);
        } else {
          likes.add(userId);
        }
        
        transaction.update(postRef, {
          'likes': likes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      debugPrint('PostService: Like toggled successfully');
    } catch (e) {
      _error = e.toString();
      debugPrint('PostService: Error toggling like: $e');
      notifyListeners();
    }
  }

  // Share a post
  Future<void> sharePost(String postId, String userId) async {
    if (!_isFirebaseAvailable) {
      // Mock share for demonstration
      final postIndex = _posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        final newShares = List<String>.from(post.shares);
        
        if (!newShares.contains(userId)) {
          newShares.add(userId);
          
          _posts[postIndex] = post.copyWith(
            shares: newShares,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
          debugPrint('PostService: Mock post shared');
        }
      }
      return;
    }
    
    try {
      debugPrint('PostService: Sharing post: $postId, user: $userId');
      
      final postRef = _firestore!.collection(_collection).doc(postId);
      
      await _firestore!.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }
        
        final postData = postDoc.data()!;
        final List<String> shares = List<String>.from(postData['shares'] ?? []);
        
        if (!shares.contains(userId)) {
          shares.add(userId);
          
          transaction.update(postRef, {
            'shares': shares,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      
      debugPrint('PostService: Post shared successfully');
    } catch (e) {
      _error = e.toString();
      debugPrint('PostService: Error sharing post: $e');
      notifyListeners();
    }
  }

  // Delete a post
  Future<void> deletePost(String postId, String userId) async {
    if (!_isFirebaseAvailable) {
      // Mock delete for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(milliseconds: 500));
      
      final postIndex = _posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1 && _posts[postIndex].userId == userId) {
        _posts.removeAt(postIndex);
        notifyListeners();
        debugPrint('PostService: Mock post deleted');
      }
      
      _setLoading(false);
      return;
    }
    
    try {
      _setLoading(true);
      _error = null;
      
      debugPrint('PostService: Deleting post: $postId');
      
      // First check if the user owns the post
      final postDoc = await _firestore!.collection(_collection).doc(postId).get();
      
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }
      
      final postData = postDoc.data()!;
      if (postData['userId'] != userId) {
        throw Exception('You can only delete your own posts');
      }
      
      await _firestore!.collection(_collection).doc(postId).delete();
      
      // Remove from local list
      _posts.removeWhere((post) => post.id == postId);
      
      debugPrint('PostService: Post deleted successfully');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('PostService: Error deleting post: $e');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Get posts by a specific user
  Future<List<PostModel>> getUserPosts(String userId) async {
    if (!_isFirebaseAvailable) {
      // Mock user posts for demonstration
      final userPosts = _posts.where((post) => post.userId == userId).toList();
      debugPrint('PostService: Mock fetched ${userPosts.length} posts for user');
      return userPosts;
    }
    
    try {
      debugPrint('PostService: Fetching posts for user: $userId');
      
      final QuerySnapshot snapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final userPosts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
      
      debugPrint('PostService: Fetched ${userPosts.length} posts for user');
      return userPosts;
    } catch (e) {
      debugPrint('PostService: Error fetching user posts: $e');
      return [];
    }
  }

  // Search posts by content
  Future<List<PostModel>> searchPosts(String query) async {
    if (!_isFirebaseAvailable) {
      // Mock search for demonstration
      final searchResults = _posts.where((post) => 
        post.content.toLowerCase().contains(query.toLowerCase())
      ).toList();
      debugPrint('PostService: Mock found ${searchResults.length} posts matching query');
      return searchResults;
    }
    
    try {
      debugPrint('PostService: Searching posts with query: $query');
      
      final QuerySnapshot snapshot = await _firestore!
          .collection(_collection)
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThan: query + 'z')
          .orderBy('content')
          .orderBy('createdAt', descending: true)
          .get();

      final searchResults = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
      
      debugPrint('PostService: Found ${searchResults.length} posts matching query');
      return searchResults;
    } catch (e) {
      debugPrint('PostService: Error searching posts: $e');
      return [];
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Create a new post
  Future<String?> createNewPost({
    required String content,
    String? imagePath,
    required String userId,
    required String userName,
    String? userProfileImageUrl,
  }) async {
    try {
      _setLoading(true);
      _error = null;
      debugPrint('PostService: Creating new post for user: $userName');

      String? imageUrl;
      
      // Upload image if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        debugPrint('PostService: Uploading image...');
        imageUrl = await _uploadPostImage(imagePath, userId);
        if (imageUrl == null) {
          debugPrint('PostService: Image upload failed, continuing without image');
        }
      }

      final postId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final post = PostModel(
        id: postId,
        userId: userId,
        userName: userName,
        userAvatar: userProfileImageUrl ?? (userName.isNotEmpty ? userName[0].toUpperCase() : 'U'),
        content: content,
        imageUrl: imageUrl,
        likes: [],
        shares: [],
        commentsCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      if (_isFirebaseAvailable && _firestore != null) {
        // Save to Firestore
        debugPrint('PostService: Saving to Firestore...');
        await _firestore!.collection(_collection).doc(postId).set(post.toFirestore());
        debugPrint('PostService: Post saved to Firestore successfully');
      } else {
        // Add to mock posts
        debugPrint('PostService: Adding to mock posts...');
        _posts.insert(0, post);
        debugPrint('PostService: Post added to mock posts successfully');
      }

      notifyListeners();
      debugPrint('PostService: Post creation completed successfully');
      return postId;
    } catch (e) {
      debugPrint('PostService: Error creating post: $e');
      _error = 'Failed to create post: ${e.toString()}';
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Upload post image to Firebase Storage
  Future<String?> _uploadPostImage(String imagePath, String userId) async {
    if (!_isFirebaseAvailable) {
      // Return a mock URL for demonstration
      debugPrint('PostService: Mock image URL generated');
      return 'https://via.placeholder.com/400x300?text=Post+Image';
    }
    
    try {
      final file = File(imagePath);
      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child(userId)
          .child(fileName);

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      debugPrint('PostService: Image uploaded successfully');
      return downloadUrl;
    } catch (e) {
      debugPrint('PostService: Error uploading image: $e');
      // Return a mock URL as fallback
      return 'https://via.placeholder.com/400x300?text=Post+Image';
    }
  }

  // Delete a post
  Future<bool> removePost(String postId) async {
    try {
      _setLoading(true);
      debugPrint('PostService: Deleting post $postId');

      if (_isFirebaseAvailable && _firestore != null) {
        await _firestore!.collection(_collection).doc(postId).delete();
        debugPrint('PostService: Post deleted from Firestore');
      } else {
        _posts.removeWhere((post) => post.id == postId);
        debugPrint('PostService: Post removed from mock posts');
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('PostService: Error deleting post: $e');
      _error = 'Failed to delete post: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
