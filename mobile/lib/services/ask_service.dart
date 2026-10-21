import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/ask.dart';
import '../logic/logic.dart';
import 'config.dart';
import 'sync_service.dart';

class AskMessage extends AskTurn {
  final String id;
  const AskMessage(this.id, super.role, super.text);
  AskMessage withText(String t) => AskMessage(id, role, t);
}

class AskFailure implements Exception {
  final String message;
  const AskFailure(this.message);
  @override
  String toString() => message;
}

/// One streamed "Ask Kizuki" request. Reads the AI SDK UI-message stream (SSE) that the web
/// app's /api/public/ask returns — the same stream the web client consumes with useChat.
class AskRequest {
  final http.Client _client = http.Client();
  bool _closed = false;

  /// Streams answer text deltas; throws [AskFailure] with learner-friendly copy.
  Stream<String> send(AskContext ctx, List<AskMessage> history) async* {
    final token = await _accessToken();
    if (token == null) throw AskFailure(askErrorText(401));
    final req = http.Request('POST', Uri.parse('${AppConfig.apiOrigin}$askPath'))
      ..headers.addAll({'content-type': 'application/json', 'authorization': 'Bearer $token'})
      ..body = jsonEncode({
        'context': ctx.toJson(),
        'messages': [
          for (final m in askHistory(history))
            {'id': m.id, 'role': m.role, 'parts': [{'type': 'text', 'text': m.text}]},
        ],
      });
    http.StreamedResponse res;
    try {
      res = await _client.send(req);
    } catch (_) {
      if (_closed) return;
      throw AskFailure(askErrorText(null));
    }
    if (res.statusCode != 200) {
      String? msg;
      try {
        final body = jsonDecode(await res.stream.bytesToString());
        if (body is Map && body['error'] is String) msg = body['error'] as String;
      } catch (_) {}
      throw AskFailure(askErrorText(res.statusCode, msg));
    }
    try {
      await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;
        final Map<String, dynamic> j;
        try {
          j = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        switch (j['type']) {
          case 'text-delta':
            final d = j['delta'];
            if (d is String && d.isNotEmpty) yield d;
          case 'error':
            throw AskFailure(askErrorText(500, j['errorText'] as String?));
        }
      }
    } on AskFailure {
      rethrow;
    } catch (_) {
      if (_closed) return;
      throw AskFailure(askErrorText(null));
    }
  }

  /// Stop: closes the connection, which cancels the answer on the server too.
  void close() {
    _closed = true;
    _client.close();
  }

  static Future<String?> _accessToken() async {
    if (!await SyncService.I.ensureBackend()) return null;
    final auth = Supabase.instance.client.auth;
    var s = auth.currentSession;
    if (s == null) return null;
    if (s.isExpired) {
      try {
        s = (await auth.refreshSession()).session;
      } catch (_) {
        return null;
      }
    }
    return s?.accessToken;
  }
}
