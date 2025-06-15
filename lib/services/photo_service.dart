import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class PhotoService {
  static Future<File?> compressImage(File imageFile) async {
    try {
      final dir = Directory.systemTemp;
      final fileName = path.basename(imageFile.path);
      final targetPath = '${dir.path}/compressed_$fileName';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 400,
        minHeight: 400,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfilePhoto(
    File? newPhoto,
    Function(String, {Color? backgroundColor}) showSnackBar,
    Function() refreshUI,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? photoUrl;
      if (newPhoto != null) {
        // Compress the image before uploading
        final compressedPhoto = await compressImage(newPhoto);
        if (compressedPhoto == null) {
          throw Exception('Failed to compress image');
        }
        
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user.uid}.jpg');

        final uploadTask = await ref.putFile(compressedPhoto);
        
        photoUrl = await uploadTask.ref.getDownloadURL();
        
        // Clean up temporary compressed file
        try {
          await compressedPhoto.delete();
        } catch (e) {
          // Failed to delete temporary file - not critical
        }
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': photoUrl, 'photoSkipped': photoUrl == null},
      );
      
      refreshUI();
      showSnackBar('Profile photo updated successfully');
    } catch (e) {
      showSnackBar('Failed to update profile photo: ${e.toString()}', backgroundColor: Colors.red);
    }
  }
}