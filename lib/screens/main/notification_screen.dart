import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<app_auth.AuthProvider>(context).user;
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final id = docs[i].id;
              final title = data['title'] ?? 'Notification';
              final body = data['body'] ?? '';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final seen = data['seen'] ?? false;
              return Card(
                color: seen ? Colors.grey[100] : Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  title: Text(title, style: TextStyle(fontWeight: seen ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(body),
                  trailing: timestamp != null
                      ? Text(_formatTimeAgo(timestamp), style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('notifications')
                        .doc(id)
                        .update({'seen': true});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
} 