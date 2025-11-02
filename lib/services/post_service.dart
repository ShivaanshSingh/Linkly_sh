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

  // Get posts from user and their connections only
  Future<void> getPosts({String? currentUserId}) async {
    if (!_isFirebaseAvailable) {
      _loadMockPosts();
      return;
    }
    
    try {
      _setLoading(true);
      _error = null;
      
      debugPrint('PostService: Fetching posts for user: $currentUserId');
      
      if (currentUserId == null) {
        debugPrint('PostService: No current user, loading empty feed');
        _posts = [];
        notifyListeners();
        return;
      }

      // Get user's connections
      final connectionsSnapshot = await _firestore!
          .collection('connections')
          .where('userId', isEqualTo: currentUserId)
          .get();

      List<String> connectionUserIds = connectionsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dynamic raw = data['contactUserId'];
            return raw is String && raw.isNotEmpty ? raw : null;
          })
          .whereType<String>()
          .toList();

      // Add current user to the list so they see their own posts
      connectionUserIds.add(currentUserId);

      debugPrint('PostService: Found ${connectionUserIds.length} users to fetch posts from');

      // Get posts from user and their connections (without orderBy to avoid index issues)
      List<PostModel> allPosts = [];
      
      // Get user's own posts
      final userPostsSnapshot = await _firestore!
          .collection(_collection)
          .where('userId', isEqualTo: currentUserId)
          .get();
      
      allPosts.addAll(userPostsSnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList());
      
      // Get posts from each connection individually to avoid whereIn + orderBy index issues
      for (String connectionId in connectionUserIds) {
        if (connectionId != currentUserId) {
          try {
            final connectionPostsSnapshot = await _firestore!
                .collection(_collection)
                .where('userId', isEqualTo: connectionId)
                .get();
            
            allPosts.addAll(connectionPostsSnapshot.docs
                .map((doc) => PostModel.fromFirestore(doc))
                .toList());
          } catch (e) {
            debugPrint('PostService: Error fetching posts for connection $connectionId: $e');
            // Continue with other connections even if one fails
          }
        }
      }
      
      // Sort posts by creation date (newest first) on the client side
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _posts = allPosts;

      debugPrint('PostService: Loaded ${_posts.length} posts from user and connections');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('PostService: Error fetching posts: $e');
      
      // Fallback: try to get user's own posts only
      if (currentUserId != null) {
        try {
          final userPostsSnapshot = await _firestore!
              .collection(_collection)
              .where('userId', isEqualTo: currentUserId)
              .orderBy('createdAt', descending: true)
              .get();

          _posts = userPostsSnapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
          
          debugPrint('PostService: Fallback loaded ${_posts.length} user posts');
        } catch (fallbackError) {
          debugPrint('PostService: Fallback also failed: $fallbackError');
          _posts = [];
        }
      } else {
        _posts = [];
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

  // Stream posts for real-time updates (user and connections only)
  Stream<List<PostModel>> getPostsStream({String? currentUserId}) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_posts);
    }
    
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    // Get user's connections
    return _firestore!
        .collection('connections')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((connectionsSnapshot) async {
      List<String> connectionUserIds = connectionsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dynamic raw = data['contactUserId'];
            return raw is String && raw.isNotEmpty ? raw : null;
          })
          .whereType<String>()
          .toList();
      
      // Add current user to the list
      connectionUserIds.add(currentUserId);
      
      if (connectionUserIds.isEmpty) {
        // No connections, only show user's own posts
        final userPostsSnapshot = await _firestore!
            .collection(_collection)
            .where('userId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .get();
        
        return userPostsSnapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList();
      } else {
        // Get posts from user and their connections
        final postsSnapshot = await _firestore!
            .collection(_collection)
            .where('userId', whereIn: connectionUserIds)
            .orderBy('createdAt', descending: true)
            .get();
        
        return postsSnapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList();
      }
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
  Future<bool> toggleLike(String postId, String userId) async {
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
      return true;
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
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('PostService: Error toggling like: $e');
      notifyListeners();
      return false;
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
