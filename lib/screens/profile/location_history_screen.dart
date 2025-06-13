import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/location_model.dart';
import '../../services/firebase_service.dart';
import 'package:timeline_tile/timeline_tile.dart';

class LocationHistoryScreen extends StatelessWidget {
  const LocationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user!.uid;

    Future<void> _showDeleteConfirmation() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete History'),
          content: const Text(
            'Are you sure you want to delete your entire location history? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        try {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final batch = FirebaseService.firestore.batch();
          final snapshots = await FirebaseService.firestore
              .collection('locations')
              .doc(userId)
              .collection('history')
              .get();

          for (var doc in snapshots.docs) {
            batch.delete(doc.reference);
          }

          await batch.commit();
          
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Location history deleted successfully')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete history: ${e.toString()}')),
            );
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showDeleteConfirmation,
            tooltip: 'Clear history',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseService.firestore
            .collection('locations')
            .doc(userId)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final locations = snapshot.data!.docs
              .map((doc) => LocationModel.fromMap(doc.data(), doc.id))
              .toList();

          if (locations.isEmpty) {
            return const Center(
              child: Text('No location history available'),
            );
          }

          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              final isFirst = index == 0;
              final isLast = index == locations.length - 1;

              return TimelineTile(
                isFirst: isFirst,
                isLast: isLast,
                indicatorStyle: IndicatorStyle(
                  width: 20,
                  height: 20,
                  indicator: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                beforeLineStyle: LineStyle(
                  color: Theme.of(context).primaryColor.withOpacity(0.4),
                ),
                endChild: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy - HH:mm')
                            .format(location.timestamp),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${location.position.latitude.toStringAsFixed(6)}\n'
                        'Long: ${location.position.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                      if (location.address != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          location.address!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
