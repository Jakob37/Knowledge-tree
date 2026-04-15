import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/knowledge_models.dart';

class KnowledgeLoadResult {
  const KnowledgeLoadResult._({
    required this.hadPersistedData,
    this.state,
    this.error,
    this.stackTrace,
  });

  const KnowledgeLoadResult.empty() : this._(hadPersistedData: false);

  const KnowledgeLoadResult.success(KnowledgeBoardState loadedState)
    : this._(hadPersistedData: true, state: loadedState);

  const KnowledgeLoadResult.failure({
    required Object loadError,
    required StackTrace loadStackTrace,
  }) : this._(
         hadPersistedData: true,
         error: loadError,
         stackTrace: loadStackTrace,
       );

  final bool hadPersistedData;
  final KnowledgeBoardState? state;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isSuccess => state != null;
  bool get isFailure => hadPersistedData && error != null;
}

class KnowledgeStorage {
  const KnowledgeStorage();

  static const String _stateKey = 'knowledge_board_state';
  static const int _currentSchemaVersion = 1;
  static Future<void> _saveQueue = Future<void>.value();

  Future<KnowledgeLoadResult> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_stateKey);
    if (rawJson == null) {
      return const KnowledgeLoadResult.empty();
    }

    try {
      return KnowledgeLoadResult.success(import(rawJson));
    } catch (error, stackTrace) {
      return KnowledgeLoadResult.failure(
        loadError: error,
        loadStackTrace: stackTrace,
      );
    }
  }

  Future<void> save(KnowledgeBoardState state) {
    final String payload = export(state);
    _saveQueue = _saveQueue
        .catchError((Object error, StackTrace stackTrace) {})
        .then((ignored) async {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(_stateKey, payload);
        });
    return _saveQueue;
  }

  String export(KnowledgeBoardState state) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'version': _currentSchemaVersion,
      'data': state.toJson(),
    });
  }

  KnowledgeBoardState import(String rawJson) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is! Map<dynamic, dynamic>) {
      throw const FormatException('Import JSON is not a map.');
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
    final Object? versionValue = map['version'];
    if (versionValue is! int) {
      throw const FormatException('Expected "version" to be an int.');
    }
    if (versionValue > _currentSchemaVersion) {
      throw StateError(
        'State version $versionValue is newer than supported '
        '$_currentSchemaVersion.',
      );
    }

    final Object? payload = map['data'];
    if (payload is! Map<dynamic, dynamic>) {
      throw const FormatException('Import JSON data payload is not a map.');
    }
    return KnowledgeBoardState.fromJson(Map<String, dynamic>.from(payload));
  }
}
