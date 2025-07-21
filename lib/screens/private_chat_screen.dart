import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';

class PrivateChatScreen extends StatefulWidget {
  final String currentUserId;
  final String peerId;
  final String peerName;

  const PrivateChatScreen({
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    Key? key,
  }) : super(key: key);

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String get _chatId {
    // Deterministic chat id based on sorted user ids
    final ids = [widget.currentUserId, widget.peerId]..sort();
    return ids.join('_');
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();

    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages');

    await messagesRef.add({
      'senderId': widget.currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Optionally, store/update chat metadata (last message, etc.)
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'participants': [widget.currentUserId, widget.peerId],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Scroll to the newest message
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == widget.currentUserId;
                    final message = data['text'] ?? '';
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.primaryColor.withOpacity(0.8)
                              : Colors.grey.shade800.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.6)),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: AppTheme.primaryColor),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
} 