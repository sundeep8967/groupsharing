import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/firebase_service.dart';
import '../../services/deep_link_service.dart';
import '../../models/saved_place.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  File? _imageFile;

  String _generateFriendCode(String uid) {
    if (uid.isEmpty) return 'ABCDEF';
    // Generate a consistent 6-character alphanumeric code from user ID
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final hash = uid.hashCode.abs();
    final rand = Random(hash);
    return String.fromCharCodes(
      List.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Provider.of<app_auth.AuthProvider>(context).user;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, size: 24),
            onPressed: () async {
              try {
                await Provider.of<app_auth.AuthProvider>(context, listen: false).signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/welcome',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: ${e.toString()}')),
                  );
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  _buildProfileHeader(user, colorScheme),
                  const SizedBox(height: 24),
                  _buildSavedPlaces(theme),
                  const SizedBox(height: 24),
                  _buildDeleteAccountButton(context),
                  // Add extra space at the bottom
                  SizedBox(height: bottomPadding + 80), // Extra space for the button
                ],
              ),
            ),
          ),
          // Compact Friend Code Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Friend Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Code',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _generateFriendCode(user?.uid ?? ''),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // Share Button
                FilledButton.tonalIcon(
                  onPressed: _shareProfile,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildProfileHeader(firebase_auth.User? user, ColorScheme colorScheme) {
    final userId = user?.uid;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final fullName = data?['displayName'] ?? user?.displayName ?? 'User';
        final email = data?['email'] ?? user?.email ?? '';
        final photoUrl = data?['photoUrl'] ?? user?.photoURL;
        final friendCode = data?['friendCode'] ?? '';
        final TextEditingController nameController = TextEditingController(text: fullName);
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture with Edit Button
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.surfaceVariant,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (photoUrl != null
                                ? CachedNetworkImageProvider(photoUrl, cacheKey: 'profile_$userId')
                                : null) as ImageProvider?,
                        child: _isLoading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : (_imageFile == null && photoUrl == null
                                ? Icon(Icons.person, size: 36, color: colorScheme.onSurfaceVariant)
                                : null),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _showImagePickerOptions,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Name, Email, and Join Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name with Edit Button
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fullName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                // Show dialog to edit name
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Edit Name'),
                                    content: TextField(
                                      controller: nameController,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter your name',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          if (nameController.text.isNotEmpty) {
                                            try {
                                              await user?.updateDisplayName(nameController.text);
                                              await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                                'displayName': nameController.text,
                                              });
                                              await user?.reload();
                                              if (mounted) {
                                                setState(() {});
                                                Navigator.pop(context);
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to update name: $e')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Email
                        if (email.isNotEmpty) Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (friendCode.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Code: $friendCode',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: 'Copy code',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: friendCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Friend code copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedPlaces(ThemeData theme) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      return const Center(
        child: Text(
          'Please log in to see saved places.',
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saved Places',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add new place coming soon!')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.firestore
              .collection('users')
              .doc(userId)
              .collection('saved_places')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(fontSize: 14, color: Colors.red),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No saved places yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              );
            }

            final places = snapshot.data!.docs.map((doc) {
              try {
                return SavedPlace.fromFirestore(doc);
              } catch (e) {
                debugPrint('Error parsing saved place doc ${doc.id}: $e');
                return null;
              }
            }).whereType<SavedPlace>().toList();

            if (places.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No saved places yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: places.length,
              itemBuilder: (context, index) => _buildSavedPlaceTile(places[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSavedPlaceTile(SavedPlace place) {
    final iconData = _getIconForPlace(place.icon);
    final iconBgColor = Colors.grey.shade200;
    final iconColor = Colors.grey.shade800;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          place.address,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Editing for ${place.name} coming soon!')),
          );
        },
      ),
    );
  }

  IconData _getIconForPlace(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline;
      default:
        return Icons.location_on_outlined;
    }
  }

  Future<void> _shareProfile() async {
    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final friendCode = userDoc.data()?['friendCode'] ?? '';
    final profileLink = DeepLinkService.generateProfileLink(user.uid);
    final message = 'Check out my profile on GroupSharing!\nFriend code: $friendCode\n$profileLink';
    await Share.share(message);
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isLoading = true;
        });
        await _uploadAndUpdateProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
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

  Future<void> _uploadAndUpdateProfile() async {
    if (_imageFile == null) return;

    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user!.uid;
    final ref = FirebaseStorage.instance.ref().child('user_photos').child('$userId.jpg');

    try {
      final uploadTask = ref.putFile(_imageFile!);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await authProvider.user!.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'photoUrl': downloadUrl,
      });
      await authProvider.user!.reload();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      }
    }
  }

  // _getJoinedDate method removed as it's no longer used

  Widget _buildDeleteAccountButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.delete_forever),
      label: const Text('Delete Account'),
      onPressed: _isLoading ? null : () => _showDeleteConfirmationDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50), // Make button wider
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext mainScreenContext) {
    // Use a StatefulWidget for the dialog to manage its own loading state if needed,
    // but for now, we'll rely on the screen's _isLoading state.
    showDialog(
      context: mainScreenContext,
      barrierDismissible: !_isLoading, // Prevent dismissing while loading
      builder: (BuildContext dialogContext) {
        // Access AuthProvider using mainScreenContext if dialogContext can't find it
        final authProvider = Provider.of<app_auth.AuthProvider>(mainScreenContext, listen: false);

        return AlertDialog(
          title: const Text('Delete Account?'),
          content: _isLoading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Deleting account...'),
                  ],
                )
              : const Text('Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: _isLoading ? null : () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: _isLoading ? Colors.grey : Colors.red)),
              onPressed: _isLoading ? null : () async {
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                });

                try {
                  await authProvider.deleteUserAccount();

                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                    Navigator.of(dialogContext).pop(); // Close the dialog

                    ScaffoldMessenger.of(mainScreenContext).showSnackBar(
                      const SnackBar(content: Text('Account deleted successfully.')),
                    );
                    Navigator.of(mainScreenContext).pushNamedAndRemoveUntil(
                      '/welcome',
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                    Navigator.of(dialogContext).pop(); // Close the dialog

                    String errorMessage = 'Failed to delete account. Please try again.';
                    if (e.toString().contains('requires-recent-login')) {
                      errorMessage = 'This action requires recent login. Please sign out and sign in again, then retry.';
                    } else {
                      errorMessage = e.toString().replaceFirst('Exception: ', '');
                    }
                    ScaffoldMessenger.of(mainScreenContext).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
