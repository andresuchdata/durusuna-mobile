import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'lib/core/storage/storage_service.dart';
import 'lib/shared/database/chat_database.dart';

/// Quick script to reset local database and force fresh sync
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔄 Resetting local chat database...');

  try {
    // Initialize storage
    await Hive.initFlutter();
    await StorageService.init();

    // Initialize Isar database
    await ChatDatabase.initialize();

    // Clear all local chat data
    await ChatDatabase.clearAllData();

    print('✅ Local chat database cleared successfully!');
    print('📱 Restart your app now - it will sync fresh from backend');
  } catch (e) {
    print('❌ Error clearing database: $e');
  }
}
