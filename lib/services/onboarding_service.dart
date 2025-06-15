import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'photo_service.dart';

class OnboardingService {
  static Future<String?> uploadProfilePhoto(File? profilePhoto) async {
    if (profilePhoto == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Compress the image before uploading
      final compressedPhoto = await PhotoService.compressImage(profilePhoto);
      if (compressedPhoto == null) {
        return null;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      final uploadTask = await ref.putFile(compressedPhoto);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Clean up temporary compressed file
      try {
        await compressedPhoto.delete();
      } catch (e) {
        // Failed to delete temporary file - not critical
      }

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveLocalProgress({
    required String firstName,
    required String lastName,
    required String gender,
    required bool photoSkipped,
    required Set<String> selectedActivities,
    required String units,
    required String zipCode,
    required bool usingLocation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', firstName);
    await prefs.setString('lastName', lastName);
    await prefs.setString('gender', gender);
    await prefs.setBool('photoSkipped', photoSkipped);
    await prefs.setStringList('activities', selectedActivities.toList());
    await prefs.setString('units', units);
    await prefs.setString('zipCode', zipCode);
    await prefs.setBool('usingLocation', usingLocation);
    await prefs.setBool('onboarding_complete', true);
  }

  static Future<void> saveFirestoreProgressWithPhoto({
    required String firstName,
    required String lastName,
    required String gender,
    required bool photoSkipped,
    required Set<String> selectedActivities,
    required String units,
    required String zipCode,
    required bool usingLocation,
    String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final data = {
      'firstName': firstName,
      'lastName': lastName,
      'bio': '',
      'gender': gender,
      'photoSkipped': photoSkipped,
      'activities': selectedActivities.toList(),
      'units': units,
      'zipCode': zipCode,
      'usingLocation': usingLocation,
      'onboardingComplete': true,
      'phoneNumber': user.phoneNumber, // Preserve phone number from Firebase Auth
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }
}