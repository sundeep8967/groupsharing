import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

String generateFriendCode(String uid) {
  if (uid.isEmpty) return 'ABCDEF';
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random(uid.hashCode);
  return String.fromCharCodes(
    List.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final db = FirebaseFirestore.instance;
  final users = await db.collection('users').get();
  
  print('Found ${users.docs.length} users to update');
  
  for (var doc in users.docs) {
    final uid = doc.id;
    final newCode = generateFriendCode(uid);
    
    print('Updating user $uid with code: $newCode');
    
    await doc.reference.update({
      'friendCode': newCode,
    });
  }
  
  print('All friend codes updated successfully!');
  exit(0);
}