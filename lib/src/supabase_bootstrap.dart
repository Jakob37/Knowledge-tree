import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured) {
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient? get client {
    if (!isConfigured) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
