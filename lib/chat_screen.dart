import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  final User user;

  const ChatScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('messages');

  // --- ACTIONS ---

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      _dbRef.push().set({
        'text': _messageController.text,
        'sender': widget.user.email,
        'username': widget.user.email!.split('@')[0],
        'timestamp': DateTime.now().toIso8601String(),
        'likes': 0,
      });
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _deleteMessage(String key) {
    _dbRef.child(key).remove();
  }

  void _likeMessage(String key, int currentLikes) {
    _dbRef.child(key).update({'likes': currentLikes + 1});
  }

  // --- HELPERS ---

  String _formatTime(String isoString) {
    try {
      final DateTime dt = DateTime.parse(isoString);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // THE DRAWER (Reads from Firestore)
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              accountName: Text(widget.user.email!.split('@')[0].toUpperCase()),
              accountEmail: Text(widget.user.email!),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  widget.user.email![0].toUpperCase(),
                  style: const TextStyle(fontSize: 40.0, color: Colors.deepPurple),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const ListTile(title: Text("Profile Loading..."));
                  }
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final joinedDate = data['created_at'] as Timestamp?;

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                        title: const Text("Member Since"),
                        subtitle: Text(_formatDate(joinedDate)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email, color: Colors.deepPurple),
                        title: const Text("Email Verified"),
                        subtitle: const Text("Yes"),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text("App Version"),
                        subtitle: const Text("1.0.0 (Final Project)"),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("Logout", style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              ),
            )
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("Class Chat"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      // CHAT BODY (Reads from Realtime DB)
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: StreamBuilder(
                stream: _dbRef.onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                    return const Center(child: Text("No messages yet. Say hi!", style: TextStyle(color: Colors.grey)));
                  }

                  final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  final List<Map<String, dynamic>> messages = [];
                  data.forEach((key, value) {
                    final msg = Map<String, dynamic>.from(value);
                    msg['key'] = key;
                    messages.add(msg);
                  });

                  messages.sort((a, b) => (a['timestamp'] ?? "").compareTo(b['timestamp'] ?? ""));

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final text = msg['text'] ?? '';
                      final senderEmail = msg['sender'] ?? '';

                      // THE FIX IS HERE:
                      // If 'username' is missing, split the email to get a name.
                      String username = msg['username'] ?? '';
                      if (username.isEmpty && senderEmail.contains('@')) {
                        username = senderEmail.split('@')[0];
                      } else if (username.isEmpty) {
                        username = 'User';
                      }

                      final likes = msg['likes'] ?? 0;
                      final key = msg['key'];
                      final time = _formatTime(msg['timestamp'] ?? '');
                      final isMe = senderEmail == widget.user.email;

                      return GestureDetector(
                        onDoubleTap: () => _likeMessage(key, likes),
                        onLongPress: () {
                          if (isMe) _deleteMessage(key);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.deepPurple[200],
                                  child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              if (!isMe) const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.deepPurple : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                                      bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                                    ),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe) Text(username, style: TextStyle(color: Colors.deepPurple[900], fontSize: 10, fontWeight: FontWeight.bold)),
                                      Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10)),
                                          if (likes > 0) ...[
                                            const SizedBox(width: 5),
                                            const Icon(Icons.favorite, size: 12, color: Colors.redAccent),
                                            const SizedBox(width: 2),
                                            Text("$likes", style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10)),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}