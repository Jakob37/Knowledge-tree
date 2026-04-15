import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initializeIfConfigured();
  runApp(const KnowledgeApp());
}
