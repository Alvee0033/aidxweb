import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPostModel {
  final String? id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String userLocation;
  final String content;
  final String? imageUrl;
  final String? imageBase64;
  final String? videoUrl;
  final List<String> tags;
  final String category; // health_tip, medication_experience, exercise, diet, general, etc.
  final DateTime timestamp;
  final int likes;
  final int comments;
  final int shares;
  final bool isAnonymous;
  final bool isVerified;
  final bool isEdited;
  final DateTime? editedAt;
  final List<String> likedBy; // List of user IDs who liked
  final Map<String, dynamic>? metadata;
  final String privacy; // public, friends, private
  final List<String> mentionedUsers; // @mentions
  final String? location; // GPS location if shared

  CommunityPostModel({
    this.id,
    required this.userId,
    required this.userName,
    this.userAvatar = '',
    required this.userLocation,
    required this.content,
    this.imageUrl,
    this.imageBase64,
    this.videoUrl,
    this.tags = const [],
    required this.category,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isAnonymous = false,
    this.isVerified = false,
    this.isEdited = false,
    this.editedAt,
    this.likedBy = const [],
    this.metadata,
    this.privacy = 'public',
    this.mentionedUsers = const [],
    this.location,
  });

  factory CommunityPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityPostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: (data['userName'] as String?)?.trim().isNotEmpty == true
          ? data['userName']
          : 'User',
      userAvatar: data['userAvatar'] ?? '',
      userLocation: data['userLocation'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      imageBase64: data['imageBase64'],
      videoUrl: data['videoUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      category: data['category'] ?? '',
      timestamp: (() {
        final value = data['timestamp'];
        if (value == null) return DateTime.now();
        if (value is Timestamp) return value.toDate();
        if (value is String) {
          try { return DateTime.parse(value); } catch (_) { return DateTime.now(); }
        }
        return DateTime.now();
      })(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      isAnonymous: data['isAnonymous'] ?? false,
      isVerified: data['isVerified'] ?? false,
      isEdited: data['isEdited'] ?? false,
      editedAt: (() {
        final value = data['editedAt'];
        if (value == null) return null;
        if (value is Timestamp) return value.toDate();
        if (value is String) { try { return DateTime.parse(value); } catch (_) { return null; } }
        return null;
      })(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      metadata: data['metadata'],
      privacy: data['privacy'] ?? 'public',
      mentionedUsers: List<String>.from(data['mentionedUsers'] ?? []),
      location: data['location'],
    );
  }

  factory CommunityPostModel.fromMap(Map<String, dynamic> data) {
    return CommunityPostModel(
      id: data['id'],
      userId: data['userId'] ?? '',
      userName: (data['userName'] as String?)?.trim().isNotEmpty == true
          ? data['userName']
          : 'User',
      userAvatar: data['userAvatar'] ?? '',
      userLocation: data['userLocation'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      imageBase64: data['imageBase64'],
      videoUrl: data['videoUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      category: data['category'] ?? '',
      timestamp: (() {
        final value = data['timestamp'];
        if (value == null) return DateTime.now();
        if (value is Timestamp) return value.toDate();
        if (value is String) { try { return DateTime.parse(value); } catch (_) { return DateTime.now(); } }
        return DateTime.now();
      })(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      isAnonymous: data['isAnonymous'] ?? false,
      isVerified: data['isVerified'] ?? false,
      isEdited: data['isEdited'] ?? false,
      editedAt: (() {
        final value = data['editedAt'];
        if (value == null) return null;
        if (value is Timestamp) return value.toDate();
        if (value is String) { try { return DateTime.parse(value); } catch (_) { return null; } }
        return null;
      })(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      metadata: data['metadata'],
      privacy: data['privacy'] ?? 'public',
      mentionedUsers: List<String>.from(data['mentionedUsers'] ?? []),
      location: data['location'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userLocation': userLocation,
      'content': content,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'videoUrl': videoUrl,
      'tags': tags,
      'category': category,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'isAnonymous': isAnonymous,
      'isVerified': isVerified,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'likedBy': likedBy,
      'metadata': metadata,
      'privacy': privacy,
      'mentionedUsers': mentionedUsers,
      'location': location,
    };
  }

  CommunityPostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userLocation,
    String? content,
    String? imageUrl,
    String? imageBase64,
    String? videoUrl,
    List<String>? tags,
    String? category,
    DateTime? timestamp,
    int? likes,
    int? comments,
    int? shares,
    bool? isAnonymous,
    bool? isVerified,
    bool? isEdited,
    DateTime? editedAt,
    List<String>? likedBy,
    Map<String, dynamic>? metadata,
    String? privacy,
    List<String>? mentionedUsers,
    String? location,
  }) {
    return CommunityPostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userLocation: userLocation ?? this.userLocation,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      videoUrl: videoUrl ?? this.videoUrl,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isVerified: isVerified ?? this.isVerified,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      likedBy: likedBy ?? this.likedBy,
      metadata: metadata ?? this.metadata,
      privacy: privacy ?? this.privacy,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
      location: location ?? this.location,
    );
  }
}

class CommunityCommentModel {
  final String? id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final bool isEdited;
  final DateTime? editedAt;
  final String? parentCommentId; // For nested replies
  final List<String> replies; // Comment IDs of replies
  final Map<String, dynamic>? metadata;

  CommunityCommentModel({
    this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar = '',
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.isEdited = false,
    this.editedAt,
    this.parentCommentId,
    this.replies = const [],
    this.metadata,
  });

  factory CommunityCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityCommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null ? (data['editedAt'] as Timestamp).toDate() : null,
      parentCommentId: data['parentCommentId'],
      replies: List<String>.from(data['replies'] ?? []),
      metadata: data['metadata'],
    );
  }

  factory CommunityCommentModel.fromMap(Map<String, dynamic> data) {
    return CommunityCommentModel(
      id: data['id'],
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['timestamp']),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] is Timestamp 
              ? (data['editedAt'] as Timestamp).toDate()
              : DateTime.parse(data['editedAt']))
          : null,
      parentCommentId: data['parentCommentId'],
      replies: List<String>.from(data['replies'] ?? []),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'likedBy': likedBy,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'parentCommentId': parentCommentId,
      'replies': replies,
      'metadata': metadata,
    };
  }
}

class DirectMessageModel {
  final String? id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String receiverName;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;
  final String messageType; // text, image, video, audio, file
  final Map<String, dynamic>? metadata;
  final String conversationId;

  DirectMessageModel({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.receiverName,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
    this.messageType = 'text',
    this.metadata,
    required this.conversationId,
  });

  factory DirectMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverName: data['receiverName'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
      messageType: data['messageType'] ?? 'text',
      metadata: data['metadata'],
      conversationId: data['conversationId'] ?? '',
    );
  }

  factory DirectMessageModel.fromMap(Map<String, dynamic> data) {
    return DirectMessageModel(
      id: data['id'],
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverName: data['receiverName'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['timestamp']),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null 
          ? (data['readAt'] is Timestamp 
              ? (data['readAt'] as Timestamp).toDate()
              : DateTime.parse(data['readAt']))
          : null,
      messageType: data['messageType'] ?? 'text',
      metadata: data['metadata'],
      conversationId: data['conversationId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'receiverName': receiverName,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'messageType': messageType,
      'metadata': metadata,
      'conversationId': conversationId,
    };
  }
}

class ChatConversationModel {
  final String? id;
  final List<String> participants; // User IDs
  final Map<String, String> participantNames; // User ID -> Name mapping
  final Map<String, String> participantAvatars; // User ID -> Avatar mapping
  final DateTime lastMessageTime;
  final String lastMessage;
  final String lastMessageSenderId;
  final int unreadCount;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ChatConversationModel({
    this.id,
    required this.participants,
    required this.participantNames,
    this.participantAvatars = const {},
    required this.lastMessageTime,
    required this.lastMessage,
    required this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isActive = true,
    required this.createdAt,
    this.metadata,
  });

  factory ChatConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatConversationModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantAvatars: Map<String, String>.from(data['participantAvatars'] ?? {}),
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: data['unreadCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  factory ChatConversationModel.fromMap(Map<String, dynamic> data) {
    return ChatConversationModel(
      id: data['id'],
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantAvatars: Map<String, String>.from(data['participantAvatars'] ?? {}),
      lastMessageTime: data['lastMessageTime'] is Timestamp 
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : DateTime.parse(data['lastMessageTime']),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: data['unreadCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt']),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }
}

class UserProfileModel {
  final String? id;
  final String userName;
  final String? userAvatar;
  final String userLocation;
  final String? bio;
  final List<String> interests;
  final int followers;
  final int following;
  final int posts;
  final bool isVerified;
  final bool isPrivate;
  final DateTime joinedAt;
  final DateTime lastActive;
  final Map<String, dynamic>? metadata;

  UserProfileModel({
    this.id,
    required this.userName,
    this.userAvatar,
    required this.userLocation,
    this.bio,
    this.interests = const [],
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.isVerified = false,
    this.isPrivate = false,
    required this.joinedAt,
    required this.lastActive,
    this.metadata,
  });

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfileModel(
      id: doc.id,
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      userLocation: data['userLocation'] ?? '',
      bio: data['bio'],
      interests: List<String>.from(data['interests'] ?? []),
      followers: data['followers'] ?? 0,
      following: data['following'] ?? 0,
      posts: data['posts'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isPrivate: data['isPrivate'] ?? false,
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> data) {
    return UserProfileModel(
      id: data['id'],
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      userLocation: data['userLocation'] ?? '',
      bio: data['bio'],
      interests: List<String>.from(data['interests'] ?? []),
      followers: data['followers'] ?? 0,
      following: data['following'] ?? 0,
      posts: data['posts'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isPrivate: data['isPrivate'] ?? false,
      joinedAt: data['joinedAt'] is Timestamp 
          ? (data['joinedAt'] as Timestamp).toDate()
          : DateTime.parse(data['joinedAt']),
      lastActive: data['lastActive'] is Timestamp 
          ? (data['lastActive'] as Timestamp).toDate()
          : DateTime.parse(data['lastActive']),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'userAvatar': userAvatar,
      'userLocation': userLocation,
      'bio': bio,
      'interests': interests,
      'followers': followers,
      'following': following,
      'posts': posts,
      'isVerified': isVerified,
      'isPrivate': isPrivate,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'metadata': metadata,
    };
  }
} 