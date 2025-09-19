import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/community_support_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class SocialMediaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream controllers for real-time updates
  final StreamController<List<CommunityPostModel>> _postsController = 
      StreamController<List<CommunityPostModel>>.broadcast();
  final StreamController<List<CommunityCommentModel>> _commentsController = 
      StreamController<List<CommunityCommentModel>>.broadcast();
  final StreamController<List<DirectMessageModel>> _messagesController = 
      StreamController<List<DirectMessageModel>>.broadcast();
  final StreamController<List<ChatConversationModel>> _conversationsController = 
      StreamController<List<ChatConversationModel>>.broadcast();
  
  // Streams for real-time updates
  Stream<List<CommunityPostModel>> get postsStream => _postsController.stream;
  Stream<List<CommunityCommentModel>> get commentsStream => _commentsController.stream;
  Stream<List<DirectMessageModel>> get messagesStream => _messagesController.stream;
  Stream<List<ChatConversationModel>> get conversationsStream => _conversationsController.stream;

  // Post Management
  Future<void> createPost(CommunityPostModel post) async {
    try {
      debugPrint('🔄 Creating post in community_posts collection...');
      debugPrint('📝 Post data: ${post.toFirestore()}');
      
      final docRef = _firestore.collection('community_posts').doc();
      final postId = docRef.id;
      
      // Handle image: prefer base64 for web, fallback to storage for files
      String? imageUrl;
      String? imageBase64 = post.imageBase64;
      if ((imageBase64 == null || imageBase64.isEmpty) && post.imageUrl != null && post.imageUrl!.isNotEmpty) {
        final file = File(post.imageUrl!);
        if (await file.exists()) {
          imageUrl = await uploadImage(file, postId);
          debugPrint('📸 Image uploaded for post: $imageUrl');
        }
      }
      
      final updatedPost = CommunityPostModel(
        id: postId,
        userId: post.userId,
        userName: post.userName,
        userAvatar: post.userAvatar,
        userLocation: post.userLocation,
        content: post.content,
        imageUrl: imageUrl,
        imageBase64: imageBase64,
        category: post.category,
        timestamp: post.timestamp,
        tags: post.tags,
        likes: post.likes,
        comments: post.comments,
        shares: post.shares,
        likedBy: post.likedBy,
      );
      
      await docRef.set(updatedPost.toFirestore());
      
      debugPrint('✅ Post created with ID: $postId');
      
      // Update user's post count
      await _updateUserPostCount(post.userId, 1);
      
      debugPrint('📝 Post created: $postId');
    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      rethrow;
    }
  }

  Future<({List<CommunityPostModel> posts, DocumentSnapshot? lastDocument})> getPosts({
    String? category,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      debugPrint('🔄 Loading posts from community_posts collection...');
      debugPrint('📱 Category filter: $category');
      debugPrint('📱 Limit: $limit');
      
      Query query = _firestore.collection('community_posts')
          .orderBy('timestamp', descending: true);
      
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
        debugPrint('🔍 Filtering by category: $category');
      }
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
        debugPrint('📄 Using pagination with last document');
      }
      
      query = query.limit(limit);
      
      debugPrint('🔍 Executing Firestore query...');
      final snapshot = await query.get();
      debugPrint('📊 Query returned ${snapshot.docs.length} documents');
      
      final posts = snapshot.docs.map((doc) {
        debugPrint('📄 Processing document: ${doc.id}');
        return CommunityPostModel.fromFirestore(doc);
      }).toList();
      final DocumentSnapshot? newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      
      debugPrint('📱 Loaded ${posts.length} posts from community_posts');
      return (posts: posts, lastDocument: newLastDoc);
    } catch (e) {
      debugPrint('❌ Error loading posts: $e');
      return (posts: <CommunityPostModel>[], lastDocument: null);
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('community_posts').doc(postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) return;
      
      final post = CommunityPostModel.fromFirestore(postDoc);
      final likedBy = List<String>.from(post.likedBy);
      
      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
        await postRef.update({
          'likes': post.likes - 1,
          'likedBy': likedBy,
        });
        debugPrint('👎 Post unliked: $postId');
      } else {
        // Like
        likedBy.add(userId);
        await postRef.update({
          'likes': post.likes + 1,
          'likedBy': likedBy,
        });
        debugPrint('👍 Post liked: $postId');
      }
    } catch (e) {
      debugPrint('❌ Error liking post: $e');
    }
  }

  Future<void> sharePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('community_posts').doc(postId);
      await postRef.update({
        'shares': FieldValue.increment(1),
      });
      debugPrint('📤 Post shared: $postId');
    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
    }
  }

  Future<void> deletePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('community_posts').doc(postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) return;
      
      final post = CommunityPostModel.fromFirestore(postDoc);
      
      // Only allow deletion by post owner
      if (post.userId != userId) {
        debugPrint('❌ Unauthorized post deletion attempt');
        return;
      }
      
      await postRef.delete();
      
      // Update user's post count
      await _updateUserPostCount(userId, -1);
      
      debugPrint('🗑️ Post deleted: $postId');
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
    }
  }

  // Comment Management
  Future<void> createComment(CommunityCommentModel comment) async {
    try {
      final docRef = await _firestore.collection('community_comments').add(comment.toFirestore());
      await docRef.update({'id': docRef.id});
      
      // Update post's comment count
      await _updatePostCommentCount(comment.postId, 1);
      
      debugPrint('💬 Comment created: ${docRef.id}');
    } catch (e) {
      debugPrint('❌ Error creating comment: $e');
      rethrow;
    }
  }

  Future<List<CommunityCommentModel>> getComments(String postId, {
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore.collection('community_comments')
          .where('postId', isEqualTo: postId)
          .orderBy('timestamp', descending: false);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      query = query.limit(limit);
      
      final snapshot = await query.get();
      final comments = snapshot.docs.map((doc) => CommunityCommentModel.fromFirestore(doc)).toList();
      
      debugPrint('💬 Loaded ${comments.length} comments for post: $postId');
      return comments;
    } catch (e) {
      debugPrint('❌ Error loading comments: $e');
      return [];
    }
  }

  Future<void> likeComment(String commentId, String userId) async {
    try {
      final commentRef = _firestore.collection('community_comments').doc(commentId);
      final commentDoc = await commentRef.get();
      
      if (!commentDoc.exists) return;
      
      final comment = CommunityCommentModel.fromFirestore(commentDoc);
      final likedBy = List<String>.from(comment.likedBy);
      
      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
        await commentRef.update({
          'likes': comment.likes - 1,
          'likedBy': likedBy,
        });
        debugPrint('👎 Comment unliked: $commentId');
      } else {
        // Like
        likedBy.add(userId);
        await commentRef.update({
          'likes': comment.likes + 1,
          'likedBy': likedBy,
        });
        debugPrint('👍 Comment liked: $commentId');
      }
    } catch (e) {
      debugPrint('❌ Error liking comment: $e');
    }
  }

  Future<void> deleteComment(String commentId, String userId) async {
    try {
      final commentRef = _firestore.collection('community_comments').doc(commentId);
      final commentDoc = await commentRef.get();
      
      if (!commentDoc.exists) return;
      
      final comment = CommunityCommentModel.fromFirestore(commentDoc);
      
      // Only allow deletion by comment owner
      if (comment.userId != userId) {
        debugPrint('❌ Unauthorized comment deletion attempt');
        return;
      }
      
      await commentRef.delete();
      
      // Update post's comment count
      await _updatePostCommentCount(comment.postId, -1);
      
      debugPrint('🗑️ Comment deleted: $commentId');
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
    }
  }

  // Direct Messaging
  Future<void> sendMessage(DirectMessageModel message) async {
    try {
      final docRef = await _firestore.collection('direct_messages').add(message.toFirestore());
      await docRef.update({'id': docRef.id});
      
      // Update conversation
      await _updateConversation(message);
      
      debugPrint('💬 Message sent: ${docRef.id}');
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  Future<List<DirectMessageModel>> getMessages(String conversationId, {
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore.collection('direct_messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      query = query.limit(limit);
      
      final snapshot = await query.get();
      final messages = snapshot.docs.map((doc) => DirectMessageModel.fromFirestore(doc)).toList();
      
      debugPrint('💬 Loaded ${messages.length} messages for conversation: $conversationId');
      return messages;
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      return [];
    }
  }

  Future<List<ChatConversationModel>> getUserConversations(String userId) async {
    try {
      final snapshot = await _firestore.collection('chat_conversations')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();
      
      final conversations = snapshot.docs.map((doc) => ChatConversationModel.fromFirestore(doc)).toList();
      
      debugPrint('💬 Loaded ${conversations.length} conversations for user: $userId');
      return conversations;
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      return [];
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection('direct_messages').doc(messageId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Message marked as read: $messageId');
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  // User Profile Management
  Future<void> createUserProfile(UserProfileModel profile) async {
    try {
      await _firestore.collection('user_profiles').doc(profile.id).set(profile.toFirestore());
      debugPrint('👤 User profile created: ${profile.id}');
    } catch (e) {
      debugPrint('❌ Error creating user profile: $e');
      rethrow;
    }
  }

  Future<UserProfileModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('user_profiles').doc(userId).get();
      if (doc.exists) {
        return UserProfileModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('user_profiles').doc(userId).update(updates);
      debugPrint('👤 User profile updated: $userId');
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
    }
  }

  Future<void> followUser(String followerId, String followedId) async {
    try {
      final batch = _firestore.batch();
      
      // Add to follower's following list
      batch.update(_firestore.collection('user_profiles').doc(followerId), {
        'following': FieldValue.increment(1),
      });
      
      // Add to followed user's followers list
      batch.update(_firestore.collection('user_profiles').doc(followedId), {
        'followers': FieldValue.increment(1),
      });
      
      await batch.commit();
      debugPrint('👥 User followed: $followerId -> $followedId');
    } catch (e) {
      debugPrint('❌ Error following user: $e');
    }
  }

  Future<void> unfollowUser(String followerId, String followedId) async {
    try {
      final batch = _firestore.batch();
      
      // Remove from follower's following list
      batch.update(_firestore.collection('user_profiles').doc(followerId), {
        'following': FieldValue.increment(-1),
      });
      
      // Remove from followed user's followers list
      batch.update(_firestore.collection('user_profiles').doc(followedId), {
        'followers': FieldValue.increment(-1),
      });
      
      await batch.commit();
      debugPrint('👥 User unfollowed: $followerId -> $followedId');
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
    }
  }

  // Helper Methods
  Future<DocumentSnapshot?> getPostDocument(String postId) async {
    try {
      return await _firestore.collection('community_posts').doc(postId).get();
    } catch (e) {
      debugPrint('❌ Error getting post document: $e');
      return null;
    }
  }

  Future<void> _updateUserPostCount(String userId, int increment) async {
    try {
      await _firestore.collection('user_profiles').doc(userId).update({
        'posts': FieldValue.increment(increment),
      });
    } catch (e) {
      debugPrint('❌ Error updating user post count: $e');
    }
  }

  Future<void> _updatePostCommentCount(String postId, int increment) async {
    try {
      await _firestore.collection('community_posts').doc(postId).update({
        'comments': FieldValue.increment(increment),
      });
    } catch (e) {
      debugPrint('❌ Error updating post comment count: $e');
    }
  }

  Future<void> _updateConversation(DirectMessageModel message) async {
    try {
      final conversationId = _getConversationId(message.senderId, message.receiverId);
      final conversationRef = _firestore.collection('chat_conversations').doc(conversationId);
      
      final conversationDoc = await conversationRef.get();
      
      if (conversationDoc.exists) {
        // Update existing conversation
        await conversationRef.update({
          'lastMessage': message.content,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': message.senderId,
          'unreadCount': FieldValue.increment(1),
        });
      } else {
        // Create new conversation
        final conversation = ChatConversationModel(
          participants: [message.senderId, message.receiverId],
          participantNames: {
            message.senderId: message.senderName,
            message.receiverId: message.receiverName,
          },
          participantAvatars: {},
          lastMessageTime: message.timestamp,
          lastMessage: message.content,
          lastMessageSenderId: message.senderId,
          unreadCount: 1,
          createdAt: message.timestamp,
        );
        
        await conversationRef.set(conversation.toFirestore());
      }
    } catch (e) {
      debugPrint('❌ Error updating conversation: $e');
    }
  }

  String _getConversationId(String userId1, String userId2) {
    // Create a consistent conversation ID regardless of sender/receiver order
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<String?> uploadImage(File imageFile, String postId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('post_images/$postId/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('📸 Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      return null;
    }
  }

  // Cleanup
  void dispose() {
    _postsController.close();
    _commentsController.close();
    _messagesController.close();
    _conversationsController.close();
  }
} 